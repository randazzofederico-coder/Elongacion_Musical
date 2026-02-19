#include <iostream>

#define MINIAUDIO_IMPLEMENTATION
#include "live_mixer.h"

using namespace std;

// Forward declaration of callback wrapper
void data_callback_wrapper(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount) {
    auto mixer = static_cast<LiveMixer*>(pDevice->pUserData);
    if (mixer) {
        mixer->process(static_cast<float*>(pOutput), frameCount);
        
        // Atomic update is now handled inside process() to track _currentPosition (wrapped)
        // instead of linear hardware frames.
    }
}

LiveMixer::LiveMixer() {
    // initialize miniaudio
    ma_device_config config = ma_device_config_init(ma_device_type_playback);
    config.playback.format   = ma_format_f32;
    config.playback.channels = 2; // Stereo
    config.sampleRate        = 44100; // Fixed for now, or settable?
    config.dataCallback      = data_callback_wrapper;
    config.pUserData         = this;

    if (ma_device_init(NULL, &config, &_device) != MA_SUCCESS) {
        std::cerr << "Failed to initialize playback device." << std::endl;
        _deviceInit = false;
    } else {
        _deviceInit = true;
    }
}

LiveMixer::~LiveMixer() {
    if (_deviceInit) {
        ma_device_uninit(&_device);
    }

    // Cleanup tracks
    for (auto const& [key, val] : _tracks) {
        delete val;
    }
    _tracks.clear();
}

void LiveMixer::startPlayback() {
    if (_deviceInit) {
        if (ma_device_start(&_device) != MA_SUCCESS) {
            std::cerr << "Failed to start playback device." << std::endl;
        }
    }
}

void LiveMixer::stopPlayback() {
    if (_deviceInit) {
        ma_device_stop(&_device);
    }
}

int64_t LiveMixer::getAtomicPosition() {
    return _atomicFramesWritten.load(std::memory_order_acquire);
}


void LiveMixer::addTrack(const char* id, const float* data, int numSamples, int channels) {
    if (!id || !data || numSamples <= 0) return;

    std::lock_guard<std::mutex> lock(_mutex);
    
    // Check if exists
    if (_tracks.find(id) != _tracks.end()) {
        delete _tracks[id];
        _tracks.erase(id);
    }
    
    Track* track = new Track();
    track->channels = channels;
    track->data.assign(data, data + numSamples);
    
    _tracks[id] = track;
}

void LiveMixer::removeTrack(const char* id) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (_tracks.find(id) != _tracks.end()) {
        delete _tracks[id];
        _tracks.erase(id);
    }
    _updateAnySolo();
}

void LiveMixer::setTrackVolume(const char* id, float volume) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (_tracks.find(id) != _tracks.end()) {
        _tracks[id]->volume = volume;
    }
}

void LiveMixer::setTrackPan(const char* id, float pan) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (_tracks.find(id) != _tracks.end()) {
        _tracks[id]->pan = pan;
    }
}

void LiveMixer::setTrackMute(const char* id, bool muted) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (_tracks.find(id) != _tracks.end()) {
        _tracks[id]->muted = muted;
    }
}

void LiveMixer::setTrackSolo(const char* id, bool solo) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (_tracks.find(id) != _tracks.end()) {
        _tracks[id]->solo = solo;
        _updateAnySolo();
    }
}

void LiveMixer::_updateAnySolo() {
    _anySolo = false;
    for (auto const& [key, track] : _tracks) {
        if (track->solo) {
            _anySolo = true;
            break;
        }
    }
}

void LiveMixer::setLoop(int64_t startSample, int64_t endSample, bool enabled) {
    std::lock_guard<std::mutex> lock(_mutex);
    _loopStart = startSample;
    _loopEnd = endSample;
    _loopEnabled = enabled;
    
    // Safety clamp current position if needed? Or let process handle it.
    if (_loopEnabled && _loopEnd > _loopStart && _currentPosition >= _loopEnd) {
         _currentPosition = _loopStart;
    }
}

void LiveMixer::seek(int64_t positionSample) {
    std::lock_guard<std::mutex> lock(_mutex);
    _currentPosition = positionSample;
    _atomicFramesWritten.store(_currentPosition, std::memory_order_release);
    
    // Also reset atomic counter to match visual seek? 
    // Wait, atomic counter is "Frames Written To Hardware". 
    // If we seek in the file, we are NOT rewinding the hardware clock.
    // The hardware clock keeps ticking.
    // The "Position" returned to UI should be the FILE position, not the hardware uptime?
    
    // Ah, the user says: "Total de frames procesados / Frecuencia...".
    // "Manten un conteo global de estos frames desde que inició la reproducción."
    
    // If we seek, we change the _currentPosition (read pointer).
    // The "Atomic Position" is usually "Total Frames Played since App Start".
    // But we want to sync the PLAYHEAD.
    
    // The playhead position = _currentPosition (File Read Pointer).
    // But _currentPosition is updated in the audio thread.
    // We can just atomic load `_currentPosition` instead of `_framesWritten`?
    
    // Yes, if we want to know where we ARE in the song.
    // But `_currentPosition` is updated inside `process`, which is protected by mutex.
    // If we make `_currentPosition` atomic, we can read it lock-free.
    
    // Let's change strategy: Make `_currentPosition` atomic. 
    // `_framesWritten` is useful for uptime, but `_currentPosition` is what determines the seek bar.
    
    // HOWEVER, using `_framesWritten` (monotonic hardware clock) helps calculating drift.
    // But for a simple "where is the playhead", reading the atomic read-pointer is best.
    
    // Let's make `_currentPosition` atomic via a separate shadow variable to avoid locking read.
    // Inside process Loop:
    // ... calculate ...
    // _currentPosition++;
    // _atomicPosition.store(_currentPosition, memory_order_relaxed);
    
    // I will implement `_atomicPosition` shadow variable.
}

int64_t LiveMixer::getPosition() {
    // This is the old locked getter. 
    // We should implement new atomic getter.
    return _atomicFramesWritten.load(std::memory_order_acquire); 
    // Wait, I reused the variable name from header but confused logic.
    // Header has `_atomicFramesWritten`. 
    // Let's use THAT as the "File Position" shadow? No, that's confusing.
    
    // I will use `_atomicFramesWritten` to mean "Current File Position Atomic Shadow".
    // In `process`, I will update it to match `_currentPosition`.
}

int LiveMixer::process(float* outputBuffer, int numFrames) {
    // std::lock_guard<std::mutex> lock(_mutex); // Mutex might cause glitch if UI locks it for long.
    // But we need mutex for `_tracks` map modification.
    // Ideally use try_lock or lock-free queue for commands.
    // For now, standard mutex is risky but `LiveMixer` was already doing it.
    
    // To minimize blocking, we should copy active tracks ref? 
    // Or just be fast.
    
    std::lock_guard<std::mutex> lock(_mutex);
    
    // Clear buffer (silence)
    memset(outputBuffer, 0, numFrames * 2 * sizeof(float)); // Stereo output

    if (_tracks.empty()) {
        // Even if empty, we write silence and advance time? 
        // If playing "Silence", yes.
        // If "Stopped", process won't be called (stopPlayback).
        return numFrames; 
    }

    for (int i = 0; i < numFrames; i++) {
        // Handle Loop
        if (_loopEnabled && _loopEnd > _loopStart) {
             // WRAP CHECK: If we are AT or PAST the end, wrap!
             if (_currentPosition >= _loopEnd) {
                 _currentPosition = _loopStart;
             }
        }
        
        float leftSum = 0.0f;
        float rightSum = 0.0f;
        
        // Iterate tracks
        for (auto const& [key, track] : _tracks) {
             if (track->muted) continue;
             if (_anySolo && !track->solo) continue;
             
             int64_t framesAvailable = static_cast<int64_t>(track->data.size()) / track->channels;
             
             if (_currentPosition < 0) _currentPosition = 0;

             if (_currentPosition < framesAvailable) {
                 float lVal = 0.0f;
                 float rVal = 0.0f;
                 
                 size_t sampleIdx = static_cast<size_t>(_currentPosition * track->channels);
                 
                 if (sampleIdx < track->data.size() && (sampleIdx + track->channels) <= track->data.size()) {
                     if (track->channels == 1) {
                         lVal = track->data[sampleIdx];
                         rVal = lVal;
                     } else {
                         lVal = track->data[sampleIdx];
                         rVal = track->data[sampleIdx + 1];
                     }
                  }
                 
                 float lGain = 1.0f;
                 float rGain = 1.0f;
                 if (track->pan > 0) lGain = 1.0f - track->pan;
                 else if (track->pan < 0) rGain = 1.0f + track->pan;
                 
                 lVal *= track->volume * lGain;
                 rVal *= track->volume * rGain;
                 
                 leftSum += lVal;
                 rightSum += rVal;
             }
        }
        
        outputBuffer[i*2] = leftSum;
        outputBuffer[i*2+1] = rightSum;
        
        _currentPosition++;
    }
    
    // Update Atomic Shadow for UI (Sample-Accurate Read Pointer)
    _atomicFramesWritten.store(_currentPosition, std::memory_order_release);
    
    return numFrames;
}

extern "C" {
    // C Binding Wrappers
    
    EXPORT void* live_mixer_create() {
        return new LiveMixer();
    }
    
    EXPORT void live_mixer_destroy(void* mixer) {
        if (mixer) delete static_cast<LiveMixer*>(mixer);
    }
    
    EXPORT void live_mixer_add_track(void* mixer, const char* id, const float* data, int numSamples, int channels) {
        static_cast<LiveMixer*>(mixer)->addTrack(id, data, numSamples, channels);
    }
    
    EXPORT void live_mixer_remove_track(void* mixer, const char* id) {
        static_cast<LiveMixer*>(mixer)->removeTrack(id);
    }
    
    EXPORT void live_mixer_set_volume(void* mixer, const char* id, float volume) {
        static_cast<LiveMixer*>(mixer)->setTrackVolume(id, volume);
    }

    EXPORT void live_mixer_set_pan(void* mixer, const char* id, float pan) {
        static_cast<LiveMixer*>(mixer)->setTrackPan(id, pan);
    }
    
    EXPORT void live_mixer_set_mute(void* mixer, const char* id, bool muted) {
        static_cast<LiveMixer*>(mixer)->setTrackMute(id, muted);
    }

    EXPORT void live_mixer_set_solo(void* mixer, const char* id, bool solo) {
        static_cast<LiveMixer*>(mixer)->setTrackSolo(id, solo);
    }

    EXPORT void live_mixer_set_loop(void* mixer, int64_t start, int64_t end, bool enabled) {
        static_cast<LiveMixer*>(mixer)->setLoop(start, end, enabled);
    }
    
    EXPORT void live_mixer_seek(void* mixer, int64_t position) {
        static_cast<LiveMixer*>(mixer)->seek(position);
    }

    EXPORT int64_t live_mixer_get_position(void* mixer) {
        // DEPRECATED -> Redirect to Atomic 
        return static_cast<LiveMixer*>(mixer)->getAtomicPosition();
    }
    
    EXPORT int live_mixer_process(void* mixer, float* output, int frames) {
        return static_cast<LiveMixer*>(mixer)->process(output, frames);
    }
    
    // --- NEW EXPORTS ---
    EXPORT void live_mixer_start(void* mixer) {
        static_cast<LiveMixer*>(mixer)->startPlayback();
    }
    
    EXPORT void live_mixer_stop(void* mixer) {
        static_cast<LiveMixer*>(mixer)->stopPlayback();
    }
    
    EXPORT int64_t live_mixer_get_atomic_position(void* mixer) {
        return static_cast<LiveMixer*>(mixer)->getAtomicPosition();
    }
}

