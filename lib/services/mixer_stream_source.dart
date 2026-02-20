import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'package:elongacion_musical/models/track_model.dart';
import 'package:elongacion_musical/models/track_model.dart';
// import 'package:elongacion_musical/services/audio_processor.dart'; // Removed
import 'package:native_audio_engine/live_mixer.dart';
import 'package:elongacion_musical/utils/wav_header_utils.dart';
import 'package:elongacion_musical/utils/mixer_utils.dart';

/// A custom [StreamAudioSource] that mixes multiple audio tracks in real-time.
///
/// It handles buffering, pacing for different platforms, and applies 
/// volume, pan, mute, and solo controls dynamically via C++ Native Engine.
class MixerStreamSource extends StreamAudioSource {
  final List<TrackModel> tracks;
  final int totalSamples; // Source samples (at 1.0x)
  final int sampleRate;
  final double Function() getMasterVolume;
  final Duration Function() getPosition;
  final bool Function() isBuffering;

  final int _numChannels = 2;
  final int _bytesPerSample = 2; 
  
  // Latency Control
  final double _targetBufferSeconds = 0.2; 
  final Duration latencyHint; // NEW: Explicit latency compensation
  
  double _currentTempo = 1.0;
  
  // Native Mixer
  final LiveMixer _liveMixer = LiveMixer();
  
  // Control update flags
  bool _needsTrackUpdate = false; 
  
  // Persistent Audio Processor
  // Removed AudioProcessor - Native side handles it now directly in liveMixer.process
  // late final AudioProcessor _processor;

  MixerStreamSource(this.tracks, this.totalSamples, this.sampleRate, {
    required this.getMasterVolume,
    required this.getPosition,
    required this.isBuffering,
    this.latencyHint = const Duration(milliseconds: 200), // Default safe value
  }) {
      initializeMixerTracks(_liveMixer, tracks);
      
      // Initialize Native Speed
      _liveMixer.setSpeed(_currentTempo);
  }
  
  void setTempo(double tempo) {
    _currentTempo = tempo;
    _liveMixer.setSpeed(tempo);
  }

  // SoundTouch Settings IDs (Mapped directly from SoundTouch.h)
  static const int SETTING_USE_AA_FILTER       = 0;
  static const int SETTING_AA_FILTER_LENGTH    = 1;
  static const int SETTING_USE_QUICKSEEK       = 2;
  static const int SETTING_SEQUENCE_MS         = 3;
  static const int SETTING_SEEKWINDOW_MS       = 4;
  static const int SETTING_OVERLAP_MS          = 5;

  void tuneSoundTouch({int? sequenceMs, int? seekWindowMs, int? overlapMs}) {
      if (sequenceMs != null) _liveMixer.setSoundTouchSetting(SETTING_SEQUENCE_MS, sequenceMs);
      if (seekWindowMs != null) _liveMixer.setSoundTouchSetting(SETTING_SEEKWINDOW_MS, seekWindowMs);
      
      // We repurpose overlapMs to set the AA Filter Length instead since Overlap isn't as easily tunable
      if (overlapMs != null) _liveMixer.setSoundTouchSetting(SETTING_AA_FILTER_LENGTH, overlapMs);
      
      debugPrint("SoundTouch Tuned: Seq=$sequenceMs, Seek=$seekWindowMs, AAFilterTap=$overlapMs");
  }

  // Helper Profiles
  void applyRhythmicProfile() {
      tuneSoundTouch(sequenceMs: 40, seekWindowMs: 15, overlapMs: 8);
  }

  void applyMelodicProfile() {
      tuneSoundTouch(sequenceMs: 100, seekWindowMs: 30, overlapMs: 16);
  }
  
  // -- Control Pass-throughs --
  void setVolume(String id, double vol) => _liveMixer.setVolume(id, vol);
  void setPan(String id, double pan) => _liveMixer.setPan(id, pan);
  void setMute(String id, bool muted) => _liveMixer.setMute(id, muted);
  void setSolo(String id, bool solo) => _liveMixer.setSolo(id, solo);
  
  // Loop Control
  // Loop Control State
  Duration _loopStart = Duration.zero;
  Duration _loopEnd = Duration.zero;
  bool _loopEnabled = false;

  void setLoop(Duration start, Duration end, bool enabled) {
     _loopStart = start;
     _loopEnd = end;
     _loopEnabled = enabled;
     
     int startSample = (start.inMilliseconds * sampleRate / 1000).round();
     int endSample = (end.inMilliseconds * sampleRate / 1000).round();
     _liveMixer.setLoop(startSample, endSample, enabled);
  }
  
  void setLoopEnabled(bool enabled) {
     _loopEnabled = enabled;
      int startSample = (_loopStart.inMilliseconds * sampleRate / 1000).round();
      int endSample = (_loopEnd.inMilliseconds * sampleRate / 1000).round();
      _liveMixer.setLoop(startSample, endSample, enabled);
  }
  
  void dispose() {
    _liveMixer.dispose();
  }
  
  // --- NATIVE PLAYBACK CONTROL ---
  void playNative() {
     _liveMixer.startPlayback();
  }
  
  void stopNative() {
     _liveMixer.stopPlayback();
  }
  
  int getAtomicPositionFrames() {
     return _liveMixer.getAtomicPosition();
  }
  
  void seek(Duration position) {
      if (sampleRate <= 0) return;
      int frame = (position.inMicroseconds * sampleRate / 1000000).round();
      _liveMixer.seek(frame);
  }

  Duration get currentPosition {
    final int samples = _liveMixer.getAtomicPosition(); // Use atomic for consistency
    if (sampleRate == 0) return Duration.zero;
    return Duration(microseconds: (samples * 1000000 / sampleRate).round());
  }

  Duration get sourceDuration {
    if (sampleRate == 0) return Duration.zero;
    return Duration(microseconds: (totalSamples * 1000000 / sampleRate).round());
  }

  // Sync Map: Maps AudioPlayer's Linear Frame -> Mixer's Internal Wrapped Frame
  final Map<int, int> _syncProbe = {};

  // --- SYNC LOOKUP ---
  Duration getHeardPosition(Duration playerPosition) {
      if (sampleRate == 0) return Duration.zero;
      
      // 1. Convert Player Time (Linear) to Linear Frames
      int linearFrames = (playerPosition.inMicroseconds * sampleRate / 1000000).round();
      
      // 2. Find closest probe key <= linearFrames
      int? bestKey;
      // Iterate keys (scan recent history)
      for (var k in _syncProbe.keys) {
         if (k <= linearFrames) {
            if (bestKey == null || k > bestKey) {
               bestKey = k;
            }
         }
      }
      
      if (bestKey == null) {
         // Fallback: If we have no history (start), or underrun, return RAW mixer pos or RAW player pos?
         // Try current raw position
         if (_syncProbe.isNotEmpty) return currentPosition;
         return playerPosition; 
      }
      
      // 3. Calculate Offset
      int offset = linearFrames - bestKey;
      
      // 4. Result = ProbeValue + Offset
      int mixerBase = _syncProbe[bestKey]!;
      int actualMixerFrame = mixerBase + offset;
      
      final result = Duration(microseconds: (actualMixerFrame * 1000000 / sampleRate).round());
      
      // LATENCY COMPENSATION
      // We use the configured latency hint (Buffer + Hardware offset)
      // This maps "What was just mixed" to "What is being heard".
      return result + latencyHint; 
  }

  // Track total bytes yielded to detect continuations
  int _acceptedGeneratedBytes = 0;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;

    
    // Smart Seek Logic
    // If request is contiguous with where we left off, DO NOT seek (preserve mixer state like loops).
    // Tolerance of 100 bytes just in case.
    bool suggestSeek = true;
    if ((start - _acceptedGeneratedBytes).abs() < 512) {
       suggestSeek = false;

    } else {

    }
    
    // Update Expected Byte Count to 'start' immediately in case we start generating from here
    // Actually better to reset it if we seek.
    if (suggestSeek) {
       _acceptedGeneratedBytes = start;
    }
    
    // Sync Map Reset logic
    // If continuous, we keep the map!
    // If seek, we reset.
    int startFrame = 0;
    if (start > 44) {
       startFrame = (start - 44) ~/ (_numChannels * _bytesPerSample); 
    }
    
    if (suggestSeek) {
      _syncProbe.clear(); 
    }
    
    final int sourceFileSize = 44 + (totalSamples * _numChannels * _bytesPerSample); 

    if (end == null || end > sourceFileSize) {
       end = sourceFileSize;
    }

    final int contentLength = (end - start);

    final stream = _generateParams(start, end, suggestSeek, startFrame);

    return StreamAudioResponse(
      sourceLength: sourceFileSize,
      contentLength: contentLength,
      offset: start,
      stream: stream,
      contentType: 'audio/wav',
    );
  }

  Stream<List<int>> _generateParams(int startByte, int? endByte, bool doSeek, int startFrame) async* {
     int offset = startByte;
     int localTotalFrames = startFrame;

     // 1. Header
     if (offset < 44) {
        final header = buildWavHeader(totalSamples, sampleRate, _numChannels);
        int headerEnd = header.length;
        if (endByte != null) headerEnd = min(header.length, endByte);

        int headerLen = headerEnd - offset;
        yield header.sublist(offset, headerEnd);
        offset += headerLen;
     }

     // Seek Logic for Mixer
     // Only seek if requested (not continuation)
     if (doSeek) {
       int dataStartByte = offset - 44;
       if (dataStartByte < 0) dataStartByte = 0;

       int currentFrame = dataStartByte ~/ (_numChannels * _bytesPerSample);
       _liveMixer.seek(currentFrame);
     }

     try {
       final int bytesPerSecond = sampleRate * _numChannels * _bytesPerSample;

       // Loop generation
       while (endByte == null || offset < endByte) {

          // --- SYNC PROBE ---
          // Record: At linear frame X, Mixer is at frame Y
          int mixerPos = _liveMixer.getPosition();
          _syncProbe[localTotalFrames] = mixerPos;

          // We can remove keys much smaller than current PLAYER position (not generation position)
          // Since generation is now fast (unpaced), localTotalFrames runs ahead instantly.
          // We must only remove keys that the user has already heard/passed.
          
          if (_syncProbe.length > 1000) { // Check every 1k frames to save CPU
             Duration playerPos = getPosition();
             int playerLinearFrames = (playerPos.inMicroseconds * sampleRate / 1000000).round();
             
             // Keep 10 seconds of history BEFORE the current playback pointer
             int threshold = playerLinearFrames - (sampleRate * 10);
             
             // Only prune if we have something to prune
             if (threshold > 0) {
                 _syncProbe.removeWhere((k, v) => k < threshold);
             }
          }


          // --- NATIVE GENERATION ---
          int inputFramesNeeded = 1024; // Smaller chunks for responsiveness

          // Call Native Mixer (returns interleaved stereo)
          List<double> mixedChunk = _liveMixer.process(inputFramesNeeded);

          // Update Linear Counter after processing (SoundTouch changes frame count)
          localTotalFrames += mixedChunk.length ~/ _numChannels; // Should be inputFramesNeeded

          if (mixedChunk.isNotEmpty) {
             Uint8List outputBytes = floatToBytes(mixedChunk);

             // Check Bounds if endByte is set
             if (endByte != null) {
                int remaining = endByte - offset;
                if (outputBytes.length > remaining) {
                   final sub = outputBytes.sublist(0, remaining);
                   yield sub;
                   offset += remaining;
                   _acceptedGeneratedBytes = offset; // Update Tracking
                   break;
                }
             }

             yield outputBytes;
             offset += outputBytes.length;
             _acceptedGeneratedBytes = offset; // Update Tracking
          } else {
             // processor empty?
          }
       }
     } catch (e) {
        debugPrint("Generate error: $e");
     }
  }
}
