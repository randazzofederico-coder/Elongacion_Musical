#include <iostream>

#define MINIAUDIO_IMPLEMENTATION
#include "live_mixer.h"
#include "soundtouch_wrapper.h"

using namespace std;

// Forward declaration of callback wrapper
void data_callback_wrapper(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount) {
    auto mixer = static_cast<LiveMixer*>(pDevice->pUserData);
    if (mixer) {
        mixer->process(static_cast<float*>(pOutput), frameCount);
    }
}

LiveMixer::LiveMixer() {
    // Initialize SoundTouch
    _soundTouch = soundtouch_create();
    soundtouch_setSampleRate(_soundTouch, 44100);
    soundtouch_setChannels(_soundTouch, 2);
    soundtouch_setTempo(_soundTouch, 1.0f);
    
    _mixBuffer.resize(1024 * 2); // default capacity

    // initialize miniaudio
    ma_device_config config = ma_device_config_init(ma_device_type_playback);
    config.playback.format   = ma_format_f32;
    config.playback.channels = 2; // Stereo
    config.sampleRate        = 44100; // Fixed for now, or settable?
    
    // NATIVE BUFFER TUNING FOR ANDROID UNDERRUNS
    config.periodSizeInMilliseconds = 20; // 20ms period to give SoundTouch breathing room
    config.periods = 3; // triple buffering for safety
    
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
    
    if (_soundTouch) {
        soundtouch_destroy(_soundTouch);
        _soundTouch = nullptr;
    }

    // Cleanup tracks
    for (auto const& [key, val] : _tracks) {
        delete val;
    }
    _tracks.clear();
}


void LiveMixer::startPlayback() {
    std::lock_guard<std::mutex> lock(_mutex);
    _masterEnvelope = 0.0f;
    _targetEnvelope = 1.0f;
    _isPlaying = true;
    
    if (_deviceInit) {
        if (ma_device_start(&_device) != MA_SUCCESS) {
            std::cerr << "Failed to start playback device." << std::endl;
        }
    }
}

void LiveMixer::stopPlayback() {
    std::lock_guard<std::mutex> lock(_mutex);
    _isPlaying = false;
    
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
    _updateMaxTrackSamples();
}

void LiveMixer::removeTrack(const char* id) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (_tracks.find(id) != _tracks.end()) {
        delete _tracks[id];
        _tracks.erase(id);
    }
    _updateAnySolo();
    _updateMaxTrackSamples();
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

void LiveMixer::setMasterMute(bool muted) {
    std::lock_guard<std::mutex> lock(_mutex);
    _masterMuted = muted;
}

void LiveMixer::setMasterSolo(bool solo) {
    std::lock_guard<std::mutex> lock(_mutex);
    _masterSolo = solo;
    _updateGlobalSolo();
}

void LiveMixer::setMasterVolume(float volume) {
    std::lock_guard<std::mutex> lock(_mutex);
    _masterVolume = volume;
}

void LiveMixer::_updateAnySolo() {
    _anySolo = false;
    for (auto const& [key, track] : _tracks) {
        if (track->solo) {
            _anySolo = true;
            break;
        }
    }
    _updateGlobalSolo();
}

void LiveMixer::_updateGlobalSolo() {
    _globalAnySolo = _anySolo || _masterSolo || _metronome34Solo || _metronome68Solo;
}

void LiveMixer::_updateMaxTrackSamples() {
    _maxTrackSamples = 0;
    for (auto const& [key, track] : _tracks) {
        int64_t trackFrames = track->data.size() / track->channels;
        if (trackFrames > _maxTrackSamples) {
            _maxTrackSamples = trackFrames;
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
    
    if (_soundTouch) {
        soundtouch_clear(_soundTouch);
    }
    
    // Clear any temporary buffers
    _mixBuffer.assign(_mixBuffer.size(), 0.0f);
    
    // Reset envelope to 0 for a quick 20ms fade-in of the new audio 
    // to prevent any pops from non-zero crossings
    _masterEnvelope = 0.0f;
    
    // Update UI shadow
    _atomicFramesWritten.store(_currentPosition, std::memory_order_release);
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

void LiveMixer::setSpeed(float speed) {
    std::lock_guard<std::mutex> lock(_mutex);
    _speed = speed;
    if (_soundTouch) {
        soundtouch_setTempo(_soundTouch, speed);
    }
}

void LiveMixer::setSoundTouchSetting(int settingId, int value) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (_soundTouch) {
        soundtouch_setSetting(_soundTouch, settingId, value);
    }
}

// --- METRONOME ---
void LiveMixer::setMetronomeConfig(int bpm) {
    std::lock_guard<std::mutex> lock(_mutex);
    _bpm = bpm;
    _lastEighth = -1; // reset trigger
}

void LiveMixer::setMetronomeSound(int type, const float* data, int numSamples) {
    if (!data || numSamples <= 0) return;
    std::lock_guard<std::mutex> lock(_mutex);
    if (type == 0) { // High
        _clickHigh.data.assign(data, data + numSamples);
    } else if (type == 1) { // Low
        _clickLow.data.assign(data, data + numSamples);
    } else { // Noise (2)
        _clickNoise.data.assign(data, data + numSamples);
    }
}

void LiveMixer::setMetronomeVolume(float vol34, float vol68) {
    std::lock_guard<std::mutex> lock(_mutex);
    _vol34 = vol34;
    _vol68 = vol68;
}

void LiveMixer::setMetronomeMute(bool mute34, bool mute68) {
    std::lock_guard<std::mutex> lock(_mutex);
    _metronome34Muted = mute34;
    _metronome68Muted = mute68;
}

void LiveMixer::setMetronomeSolo(bool solo34, bool solo68) {
    std::lock_guard<std::mutex> lock(_mutex);
    _metronome34Solo = solo34;
    _metronome68Solo = solo68;
    _updateGlobalSolo();
}

void LiveMixer::setMetronomePattern(const int* pattern34, const int* pattern68) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (pattern34) {
        for (int i = 0; i < 6; i++) _pattern34[i] = pattern34[i];
    }
    if (pattern68) {
        for (int i = 0; i < 6; i++) _pattern68[i] = pattern68[i];
    }
}

void LiveMixer::setMetronomePreviewMode(bool enabled) {
    std::lock_guard<std::mutex> lock(_mutex);
    _metronomePreviewMode = enabled;
}

// Internal mixing logic (Raw audio from tracks)
void LiveMixer::_mixInternal(float* outputBuffer, int numFrames) {
    // Assumes mutex is ALREADY LOCKED by caller (process)
    
    // Auto-stop if we reached the end of the longest track, unless we are looping
    if (!_loopEnabled && _maxTrackSamples > 0 && _currentPosition >= _maxTrackSamples) {
        if (!_metronomePreviewMode) {
            _isPlaying = false;
            memset(outputBuffer, 0, numFrames * 2 * sizeof(float));
            return;
        }
    }
    
    memset(outputBuffer, 0, numFrames * 2 * sizeof(float)); // Stereo output

    // We no longer return early if _tracks is empty, so the Metronome can always play.
    
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
        
        bool playTracks = true;
        
        if (_metronomePreviewMode) {
            playTracks = false;
        } else {
            // Master Mute / Solo logic applied to ALL tracks bus
            if (_globalAnySolo) {
                if (!_masterSolo && !_anySolo) playTracks = false; 
            } else {
                if (_masterMuted) playTracks = false;
            }
        }
        
        if (playTracks) {
            // Iterate tracks
            for (auto const& [key, track] : _tracks) {
             // Solo-in-place logic: 
             // If ANY track or metronome is soloed globally, ONLY soloed ones play
             // But if Master is soloed, ALL unmuted tracks play because Master represents the whole bus.
             if (_globalAnySolo) {
                 if (!track->solo && !_masterSolo) continue; 
             } else {
                 if (track->muted) continue;
             }
             
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
        } // close if (!_metronomePreviewMode)
        
        // --- APPLY MASTER ENVELOPE AND VOLUME TO TRACKS ---
        float envelopeStep = 1.0f / (44100.0f * 0.02f); 
        if (_masterEnvelope < _targetEnvelope) {
            _masterEnvelope += envelopeStep;
            if (_masterEnvelope > _targetEnvelope) _masterEnvelope = _targetEnvelope;
        } else if (_masterEnvelope > _targetEnvelope) {
            _masterEnvelope -= envelopeStep;
            if (_masterEnvelope < _targetEnvelope) _masterEnvelope = _targetEnvelope;
        }
        
        leftSum *= _masterEnvelope * _masterVolume;
        rightSum *= _masterEnvelope * _masterVolume;
        
        // Handle Metronome Trigger
        if (_bpm > 0 && (_vol34 > 0.0f || _vol68 > 0.0f)) {
            double framesPerEighth = (44100.0 * 60.0) / (_bpm * 2.0);
            int currentEighth = (int)((double)_currentPosition / framesPerEighth);
            
            if (_lastEighth == -1 || currentEighth < _lastEighth) {
                _lastEighth = currentEighth - 1; 
            }
            
            if (currentEighth > _lastEighth) {
                _lastEighth = currentEighth;
                int measurePos = (currentEighth % 6 + 6) % 6;
                
                // Read patterns (0: off, 1: High, 2: Low, 3: Noise)
                int type34 = _pattern34[measurePos];
                int type68 = _pattern68[measurePos];
                
                float volHigh = 0.0f;
                float volLow = 0.0f;
                float volNoise = 0.0f;
                
                // 3/4 Metronome Logic
                bool play34 = true;
                if (_globalAnySolo && !_metronome34Solo) play34 = false;
                if (!_globalAnySolo && _metronome34Muted) play34 = false;
                
                if (play34 && _vol34 > 0.0f && type34 > 0) {
                    if (type34 == 1) volHigh = std::max(volHigh, _vol34);
                    else if (type34 == 2) volLow = std::max(volLow, _vol34);
                    else if (type34 == 3) volNoise = std::max(volNoise, _vol34);
                }
                
                // 6/8 Metronome Logic
                bool play68 = true;
                if (_globalAnySolo && !_metronome68Solo) play68 = false;
                if (!_globalAnySolo && _metronome68Muted) play68 = false;
                
                if (play68 && _vol68 > 0.0f && type68 > 0) {
                    if (type68 == 1) volHigh = std::max(volHigh, _vol68);
                    else if (type68 == 2) volLow = std::max(volLow, _vol68);
                    else if (type68 == 3) volNoise = std::max(volNoise, _vol68);
                }
                
                if (volHigh > 0.0f && !_clickHigh.data.empty()) {
                    _clickHigh.currentPointer = 0;
                    _clickHigh.currentVolume = volHigh;
                }
                if (volLow > 0.0f && !_clickLow.data.empty()) {
                    _clickLow.currentPointer = 0;
                    _clickLow.currentVolume = volLow;
                }
                if (volNoise > 0.0f && !_clickNoise.data.empty()) {
                    _clickNoise.currentPointer = 0;
                    _clickNoise.currentVolume = volNoise;
                }
            }
            
            float clickL = 0.0f;
            float clickR = 0.0f;
            
            if (_clickHigh.currentPointer >= 0 && _clickHigh.currentPointer < _clickHigh.data.size()) {
                float sample = _clickHigh.data[_clickHigh.currentPointer] * _clickHigh.currentVolume;
                clickL += sample;
                clickR += sample;
                _clickHigh.currentPointer++;
            }
            if (_clickLow.currentPointer >= 0 && _clickLow.currentPointer < _clickLow.data.size()) {
                float sample = _clickLow.data[_clickLow.currentPointer] * _clickLow.currentVolume;
                clickL += sample;
                clickR += sample;
                _clickLow.currentPointer++;
            }
            if (_clickNoise.currentPointer >= 0 && _clickNoise.currentPointer < _clickNoise.data.size()) {
                float sample = _clickNoise.data[_clickNoise.currentPointer] * _clickNoise.currentVolume;
                clickL += sample;
                clickR += sample;
                _clickNoise.currentPointer++;
            }
            
            leftSum += clickL;
            rightSum += clickR;
        }
        
        outputBuffer[i*2] = leftSum;
        outputBuffer[i*2+1] = rightSum;
        _currentPosition++;
    }
}

int LiveMixer::process(float* outputBuffer, int numFrames) {
    std::lock_guard<std::mutex> lock(_mutex);
    
    if (!_isPlaying) {
        memset(outputBuffer, 0, numFrames * 2 * sizeof(float));
        // Reset envelope so it fades in again when starting
        _masterEnvelope = 0.0f;
        return numFrames;
    }
    
    // --- 1.0x SOUNDTOUCH BYPASS OVERRIDE ---
    // If speed is practically 1.0, bypass SoundTouch and its WSOLA artifacts entirely.
    bool bypassSoundTouch = std::abs(_speed - 1.0f) < 0.001f;
    
    if (bypassSoundTouch) {
        // Direct Mixing to Output Buffer
        _mixInternal(outputBuffer, numFrames);
        
        if (_soundTouch) {
            soundtouch_clear(_soundTouch);
        }
    } else {
        if (!_soundTouch) return 0;
        
        int samplesReceived = 0;
        int maxIt = 100; // Safety break
        
        // Option 4 Micro-Processing chunk logic applies perfectly to Vocoder as well
        const int MAX_CHUNK_FRAMES = 512; 
        
        while (samplesReceived < numFrames && maxIt-- > 0) {
            int neededFrames = numFrames - samplesReceived;
            
            // Try receive what's available from SoundTouch
            int got = soundtouch_receiveSamples(_soundTouch, outputBuffer + (samplesReceived * 2), neededFrames);
            samplesReceived += got;
            
            if (samplesReceived >= numFrames) break;
            
            // Ingest more data
            int chunkFrames = MAX_CHUNK_FRAMES; 
            if (_speed > 1.0f) {
                chunkFrames = (int)(MAX_CHUNK_FRAMES * _speed);
                if (chunkFrames > 1024) chunkFrames = 1024;
            }
            
            if (_mixBuffer.size() < chunkFrames * 2) {
                _mixBuffer.resize(chunkFrames * 2);
            }
            
            _mixInternal(_mixBuffer.data(), chunkFrames);
            
            // Feed to SoundTouch
            soundtouch_putSamples(_soundTouch, _mixBuffer.data(), chunkFrames);
        }
        
        // Fill remaining with silence if we somehow failed to generate enough (e.g. max iterations reached)
        if (samplesReceived < numFrames) {
             memset(outputBuffer + (samplesReceived * 2), 0, (numFrames - samplesReceived) * 2 * sizeof(float));
        }
    }
    
    // (Master envelope and volume are now applied inside _mixInternal before the metronome)
    
    // Update Atomic Shadow for UI
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

    EXPORT void live_mixer_set_master_volume(void* mixer, float volume) {
        static_cast<LiveMixer*>(mixer)->setMasterVolume(volume);
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

    EXPORT void live_mixer_set_speed(void* mixer, float speed) {
        static_cast<LiveMixer*>(mixer)->setSpeed(speed);
    }

    EXPORT void live_mixer_set_soundtouch_setting(void* mixer, int settingId, int value) {
        static_cast<LiveMixer*>(mixer)->setSoundTouchSetting(settingId, value);
    }
    
    EXPORT void live_mixer_set_metronome_config(void* mixer, int bpm) {
        static_cast<LiveMixer*>(mixer)->setMetronomeConfig(bpm);
    }

    EXPORT void live_mixer_set_metronome_sound(void* mixer, int type, const float* data, int numSamples) {
        static_cast<LiveMixer*>(mixer)->setMetronomeSound(type, data, numSamples);
    }

EXPORT void live_mixer_set_metronome_volume(void* mixer, float vol34, float vol68) {
    if (mixer) {
        static_cast<LiveMixer*>(mixer)->setMetronomeVolume(vol34, vol68);
    }
}

EXPORT void live_mixer_set_metronome_mute(void* mixer, bool mute34, bool mute68) {
    if (mixer) {
        static_cast<LiveMixer*>(mixer)->setMetronomeMute(mute34, mute68);
    }
}

EXPORT void live_mixer_set_metronome_solo(void* mixer, bool solo34, bool solo68) {
    if (mixer) {
        static_cast<LiveMixer*>(mixer)->setMetronomeSolo(solo34, solo68);
    }
}

EXPORT void live_mixer_set_master_mute(void* mixer, bool muted) {
    if (mixer) {
        static_cast<LiveMixer*>(mixer)->setMasterMute(muted);
    }
}

EXPORT void live_mixer_set_master_solo(void* mixer, bool solo) {
    if (mixer) {
        static_cast<LiveMixer*>(mixer)->setMasterSolo(solo);
    }
}

EXPORT void live_mixer_set_metronome_pattern(void* mixer, const int* pattern34, const int* pattern68) {
    if (mixer) {
        static_cast<LiveMixer*>(mixer)->setMetronomePattern(pattern34, pattern68);
    }
}

EXPORT void live_mixer_set_metronome_preview_mode(void* mixer, bool enabled) {
    if (mixer) {
        static_cast<LiveMixer*>(mixer)->setMetronomePreviewMode(enabled);
    }
}
}
