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
    
    // --- NATIVE OUTPUT CONTROL ---
    void startPlayback();
    void stopPlayback();
    int64_t getAtomicPosition(); // Returns frames played (hardware compensated)

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
   };

   std::map<std::string, Track*> _tracks;
   std::mutex _mutex;

   int64_t _currentPosition = 0;
   
   // Loop
   bool _loopEnabled = false;
   int64_t _loopStart = 0;
   int64_t _loopEnd = 0;

   // Solo logic helper
   bool _anySolo = false;
   void _updateAnySolo();
   
   // --- MINIAUDIO ---
   ma_device _device;
   bool _deviceInit = false;
   std::atomic<int64_t> _atomicFramesWritten{0};
   
   static void data_callback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount);
};

#endif // LIVE_MIXER_H
