#ifndef LIVE_MIXER_H
#define LIVE_MIXER_H

#include <vector>
#include <map>
#include <mutex>
#include <algorithm>
#include <cstring>
#include <cmath>
#include <atomic>

#include "miniaudio.h"

#if defined(_WIN32)
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

class LiveMixer {
public:
    LiveMixer();
    ~LiveMixer();

    // Track Management
    void addTrack(const char* id, const float* data, int numSamples, int channels);
    void removeTrack(const char* id);
    void setTrackVolume(const char* id, float volume);
    void setTrackPan(const char* id, float pan);
    void setTrackMute(const char* id, bool muted);
    void setTrackSolo(const char* id, bool solo);

    // Global Settings
    void setLoop(int64_t startSample, int64_t endSample, bool enabled);
    void seek(int64_t positionSample);
    int64_t getPosition(); 
    void setMasterVolume(float volume);
    void setMasterMute(bool muted);
    void setMasterSolo(bool solo);
    
    // --- NATIVE OUTPUT CONTROL ---
    void startPlayback();
    void stopPlayback();
    int64_t getAtomicPosition(); // Returns frames played (hardware compensated)
    
    void setSpeed(float speed);
    void setSoundTouchSetting(int settingId, int value);

    // --- METRONOME ---
    void setMetronomeConfig(int bpm);
    void setMetronomeSound(int type, const float* data, int numSamples);
    void setMetronomeVolume(float vol34, float vol68);
    void setMetronomeMute(bool mute34, bool mute68);
    void setMetronomeSolo(bool solo34, bool solo68);
    void setMetronomePattern(const int* pattern34, const int* pattern68);
    void setMetronomePreviewMode(bool enabled);
    // Audio Processing
    // mix into outputBuffer (interleaved stereo)
    // returns number of frames filled (should match numFrames unless EOS and not looping)
    int process(float* outputBuffer, int numFrames);

private:
   struct Track {
       std::vector<float> data;
       int channels;
       float volume = 1.0f;
       float pan = 0.0f;
       bool muted = false;
       bool solo = false;
       float envelope = 1.0f;
   };

   std::map<std::string, Track*> _tracks;
   std::mutex _mutex;

   int64_t _currentPosition = 0;
   bool _isPlaying = false;
   
   // Loop
   bool _loopEnabled = false;
   int64_t _loopStart = 0;
   int64_t _loopEnd = 0;

   // Envelopes for click-prevention
   float _masterEnvelope = 1.0f;
   float _targetEnvelope = 1.0f;
   float _masterStemEnv = 1.0f;
   
   // Master Volume
   float _masterVolume = 1.0f;
   
   // Internal mixing logic (raw, no speed)
   void _mixInternal(float* outputBuffer, int numFrames);

   // Metronome state
   int _bpm = 0;
   float _vol34 = 0.0f;
   float _vol68 = 0.0f;
   int _lastEighth = -1;
   bool _metronomePreviewMode = false;

   // 6-step sequencer (0 = off, 1 = High, 2 = Low, 3 = Noise)
   int _pattern34[6] = {1, 0, 0, 0, 0, 0}; 
   int _pattern68[6] = {1, 0, 0, 2, 0, 0};

   struct MetronomeVoice {
       std::vector<float> data;
       int currentPointer = -1;
       float currentVolume = 0.0f;
   };
   MetronomeVoice _clickHigh; // type 0
   MetronomeVoice _clickLow;  // type 1
   MetronomeVoice _clickNoise;// type 2

   // Solo logic helper
   bool _anyTrackSolo = false; // Renamed from _anySolo
   bool _masterMuted = false;
   bool _masterSolo = false;
   
   // STEM Solo tracking
   bool _anyStemSolo = false; // Added
   bool _metronome34Muted = false;
   bool _metronome34Solo = false;
   bool _metronome68Muted = false;
   bool _metronome68Solo = false;
   // _globalAnySolo removed

   void _updateAnySolo();
   void _updateGlobalSolo();
   
   // Track length logic
   int64_t _maxTrackSamples = 0;
   void _updateMaxTrackSamples();
   
   // --- MINIAUDIO ---
   ma_device _device;
   bool _deviceInit = false;
   std::atomic<int64_t> _atomicFramesWritten{0};
   
   // --- SOUNDTOUCH ---
   void* _soundTouch = nullptr; // Void* to avoid forcing C++ dependency in header if not needed, but here we can include it.
   // Actually, since this is a private member of a C++ class not exported in DLL interface directly (only via C wrappers), 
   // we can use forward declaration or void* to keep compilation cleaner/faster, or just include it.
   // Wrapper used "soundtouch/include/SoundTouch.h".
   // Let's use void* and cast in cpp to minimize header mess, or include if we want unique_ptr.
   // Simpler: void* _soundTouch; 
   
   float _speed = 1.0f;
   std::vector<float> _mixBuffer; // Intermediate buffer for mixing before SoundTouch

   static void data_callback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount);
};

extern "C" {
    EXPORT void live_mixer_set_soundtouch_setting(void* mixer, int settingId, int value);
    
    EXPORT void live_mixer_set_master_mute(void* mixer, bool muted);
    EXPORT void live_mixer_set_master_solo(void* mixer, bool solo);

    EXPORT void live_mixer_set_metronome_config(void* mixer, int bpm);
    EXPORT void live_mixer_set_metronome_sound(void* mixer, int type, const float* data, int numSamples);
    EXPORT void live_mixer_set_metronome_volume(void* mixer, float vol34, float vol68);
    EXPORT void live_mixer_set_metronome_mute(void* mixer, bool mute34, bool mute68);
    EXPORT void live_mixer_set_metronome_solo(void* mixer, bool solo34, bool solo68);
    EXPORT void live_mixer_set_metronome_pattern(void* mixer, const int* pattern34, const int* pattern68);
    EXPORT void live_mixer_set_metronome_preview_mode(void* mixer, bool enabled);
}

#endif // LIVE_MIXER_H
