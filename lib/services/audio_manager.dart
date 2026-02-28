import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';
import 'package:wav/wav.dart';
import 'dart:io';
import 'package:elongacion_musical/models/track_model.dart';
import 'package:elongacion_musical/services/mixer_stream_source.dart';
import 'package:elongacion_musical/services/settings_service.dart';
import 'package:elongacion_musical/utils/wav_parser.dart';
import 'dart:math';


class AudioManager {

  // --- CONSTANTS ---
  // Buffer Settings
  static const Duration kMobileBuffer = Duration(milliseconds: 400);
  static const Duration kMobileRebuffer = Duration(milliseconds: 800);
  static const Duration kDesktopBuffer = Duration(milliseconds: 500); // Standard
  
  // Hardware Latency Estimation (Output delay)
  static const Duration kHardwareLatencyEst = Duration(milliseconds: 100);

  // final SettingsService _settingsService;
  final AudioPlayer _player = AudioPlayer(
    audioLoadConfiguration: () {
      if (kIsWeb) return const AudioLoadConfiguration();
      if (Platform.isAndroid || Platform.isIOS) {
         return const AudioLoadConfiguration(
            androidLoadControl: AndroidLoadControl(
              // Reduce start threshold for "Instant Playback" feeling
              bufferForPlaybackDuration: kMobileBuffer,
              bufferForPlaybackAfterRebufferDuration: kMobileRebuffer,
              minBufferDuration: Duration(seconds: 2),
              maxBufferDuration: Duration(seconds: 10),
            ),
            darwinLoadControl: DarwinLoadControl(
              automaticallyWaitsToMinimizeStalling: false,
              preferredForwardBufferDuration: Duration(seconds: 2),
            ),
         );
      }
      // Desktop / Default
      return const AudioLoadConfiguration();
    }(),
  );
  
  List<TrackModel> _tracks = [];
  List<TrackModel> get tracks => _tracks;

  MixerStreamSource? _source;
  
  // Stream Controllers
  final _dirtyController = StreamController<bool>.broadcast();
  Stream<bool> get dirtyStream => _dirtyController.stream;
  bool _isDirty = false;
  bool get isDirty => _isDirty;

  // Constructor
  AudioManager(SettingsService settingsService);

  // -- Playback State --
  // We override positionStream to emit our manual polling updates
  final _positionController = StreamController<Duration>.broadcast();
  Stream<Duration> get positionStream => _positionController.stream;
  
  // Custom Duration Stream (since we disconnected player)
  final _durationController = StreamController<Duration?>.broadcast();
  Stream<Duration?> get durationStream => _durationController.stream;
  
  // Custom Player State Stream (to replace just_audio player state for play/pause sync)
  final _playerStateController = StreamController<PlayerState>.broadcast();
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;
  
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream; // Meaningless now?
  
  // Return cached duration or source duration
  Duration? get duration => _source?.sourceDuration; // _player.duration;
  
  Timer? _positionTimer;
  
  // -- Mode --
  AudioEngineMode get mode => AudioEngineMode.realtime; // Fixed for now

  // -- Master --
  double _masterVolume = 1.0;
  double get masterVolume => _masterVolume;

  // -- Metronome --
  double _metronomeVol34 = 0.0;
  double _metronomeVol68 = 0.0;
  int? _currentBpm;

  double get metronomeVol34 => _metronomeVol34;
  double get metronomeVol68 => _metronomeVol68;

  // -- Solo --
  // (Handling moved entirely to Tracks, backend manages `anySolo`)

  // -- Loading --
  Future<void> loadTracks(List<Map<String, String>> trackConfigs) async {
    try {
      await stop();
      _tracks.clear();
      
      // Load WAVs in parallel/sequence
      // We need to read the files to get PCM data for TrackModel
      
      List<TrackModel> loadedTracks = [];
      
      for (var config in trackConfigs) {
        final id = config['id']!;
        final path = config['path']!; // Absolute path to file
        final name = config['name'] ?? 'Track';
        
        // Read WAV
        // Note: For large files, this should be in an isolate. 
        final WavData wavData;
        if (path.startsWith('assets/')) {
          final data = await rootBundle.load(path);
          wavData = await compute(parseWavBytes, data.buffer.asUint8List());
        } else {
           // For local files, read bytes then parse in isolate
           final fileData = await File(path).readAsBytes();
           wavData = await compute(parseWavBytes, fileData);
        }

        final track = TrackModel(
          id: id,
          name: name,
          assetPath: path,
        );
        track.samples = wavData.samples;
        track.waveformData = wavData.waveform;
        track.sampleRate = wavData.sampleRate;
        
        loadedTracks.add(track);
      }
      
      _tracks = loadedTracks;
      
      
      // RE-DO optimized loading:
      // We need a helper that returns (TrackModel, sampleRate, totalSamples).
      
      await _initializeMixer();
      
    } catch (e) {
      debugPrint("AudioManager: Error loading tracks: $e");
      throw e;
    }
  }
  
  // Better load implementation
  Future<void> _initializeMixer() async {
      if (_tracks.isEmpty) return;
      
      // Scan for max duration and sample rate
      int maxSamples = 0;
      int sampleRate = 44100;
      
      // Use the highest sample rate found to avoid downsampling quality loss?
      // Or use the first one?
      // Ideally all tracks should match. If not, the current simple mixer might drift or pitch-shift mismatched tracks.
      // But at least we should match the PLAYER to the CONTENT.
      for (var t in _tracks) {
          if (t.sampleRate != null && t.sampleRate! > sampleRate) {
              sampleRate = t.sampleRate!;
          }
      }
      
      // We actually need the wav info. 
      // Since we already loaded samples into TrackModel, we might have lost sampleRate.
      // But usually all tracks in a session match.
      // Let's assume 44100 if we can't find it, or peek the first file again?
      // Optimization: The user is likely passing file paths.
      
      // Ideally TrackModel should hold format info.
      // For this immediate fix, let's just peek one file if possible, or use standard.
      // Or just rely on what we have.
      
      // Let's update `loadTracks` to be better in a moment.
      // For now, let's assume `initializeMixerTracks` handles the data.
      
      // Create Source
      // We need `totalSamples` for the stream.
      for (var t in _tracks) {
          if (t.samples != null && t.samples!.isNotEmpty) {
              int len = t.samples![0].length;
              if (len > maxSamples) maxSamples = len;
          }
      }
      
      // Calculate Latency Hint
      // Current Configured Buffer + Hardware Est
      Duration latency = const Duration(milliseconds: 200); // Default/Desktop
      if (Platform.isAndroid || Platform.isIOS) {
         latency = kMobileBuffer + kHardwareLatencyEst;
      }
      
      _source = MixerStreamSource(
         _tracks, 
         maxSamples, 
         sampleRate,
         getMasterVolume: () => _masterVolume,
         getPosition: () => Duration.zero, // No longer used for sync
         isBuffering: () => false,
         latencyHint: latency, 
      );
      
      // Init Metronome Sounds (0: High, 1: Low, 2: Mid)
      _source!.setMetronomeSound(0, _generateClickSound(1000.0));
      _source!.setMetronomeSound(1, _generateClickSound(600.0));
      _source!.setMetronomeSound(2, _generateClickSound(800.0));
      _source!.setMetronomeVolume(_metronomeVol34, _metronomeVol68);
      if (_currentBpm != null) {
          _source!.setMetronomeConfig(_currentBpm!);
      }
      
      // DISCONNECT JUST_AUDIO FROM MIXER
      // await _player.setAudioSource(_source!); 
      // Instead, we just use the source directly.
      
      // Update Duration Stream Manually
      _durationController.add(_source!.sourceDuration);
  }
  
  
  // -- Controls --
  Future<void> play() async {
    _source?.playNative();
    _startPositionTimer();
    _playerStateController.add(PlayerState(true, ProcessingState.ready));
  }
  
  Future<void> pause() async {
    _source?.stopNative();
    _stopPositionTimer();
    _playerStateController.add(PlayerState(false, ProcessingState.ready));
  }
  
  Future<void> stop() async {
    _source?.stopNative();
    _stopPositionTimer();
    
    // We need to implement native seek to zero if we want reset
    _source?.seek(Duration.zero); 
    _positionController.add(Duration.zero); 
    _playerStateController.add(PlayerState(false, ProcessingState.completed));
  }
  
  // Internal Timer for Polling Native Position
  void _startPositionTimer() {
    _positionTimer?.cancel();
    // Poll faster for smoother updates (e.g. 16ms = ~60fps)
    _positionTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
       if (_source != null) {
          final frames = _source!.getAtomicPositionFrames();
          final sr = _source!.sampleRate;
          if (sr > 0) {
             final micros = (frames * 1000000 / sr).round();
             final pos = Duration(microseconds: micros);
             _positionController.add(pos);

             // Auto-stop at end of file, unless in preview mode or looping
             if (!_isLooping && !_metronomePreviewMode) {
                 if (pos >= _source!.sourceDuration && pos > Duration.zero) {
                     stop();
                 }
             }
          }
       }
    });
  }
  
  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  
  Future<void> seek(Duration position) async {
    _source?.seek(position);
    _positionController.add(position);
  }
  
  // FIX: Do NOT set player speed. We handle time-stretching manually in the processor.
  Future<void> setSpeed(double speed) async {
      _source?.setTempo(speed);
      // _player.setSpeed(speed); // REMOVE THIS
  }

  void updateSoundTouchTuning(int seq, int seek, int overlap) {
      _source?.tuneSoundTouch(
        sequenceMs: seq,
        seekWindowMs: seek,
        overlapMs: overlap,
      );
  }
  
  void setMasterVolume(double vol) {
    _masterVolume = vol;
    _source?.setMasterVolume(vol);
  }
  
  void setMasterMute(bool muted) {
    _source?.setMasterMute(muted);
  }

  void setMasterSolo(bool solo) {
    _source?.setMasterSolo(solo);
  }
  
  void setMetronomeVolume(double vol34, double vol68) {
      _metronomeVol34 = vol34;
      _metronomeVol68 = vol68;
      _source?.setMetronomeVolume(vol34, vol68);
  }

  void setMetronomeMute(bool mute34, bool mute68) {
      _source?.setMetronomeMute(mute34, mute68);
  }

  void setMetronomeSolo(bool solo34, bool solo68) {
      _source?.setMetronomeSolo(solo34, solo68);
  }

  void setMetronomeConfig(int bpm) {
      _currentBpm = bpm;
      _source?.setMetronomeConfig(bpm);
  }

  void setMetronomePattern(List<int> pattern34, List<int> pattern68) {
      _source?.setMetronomePattern(pattern34, pattern68);
  }

  bool _metronomePreviewMode = false;
  
  void setMetronomePreviewMode(bool enabled) {
      _metronomePreviewMode = enabled;
      _source?.setMetronomePreviewMode(enabled);
  }

  Float32List _generateClickSound(double freq) {
      final int sampleRate = 44100;
      final double durationFreq = 0.05; // 50ms click
      final int samples = (sampleRate * durationFreq).toInt();
      final Float32List buffer = Float32List(samples);
      
      for (int i = 0; i < samples; i++) {
          final double t = i / sampleRate;
          // Exponential decay
          final double envelope = exp(-i / (samples * 0.2)); 
          buffer[i] = (sin(2 * pi * freq * t) * envelope * 0.5); 
      }
      return buffer;
  }
  
  void setTrackVolume(String id, double vol) {
     final track = _tracks.firstWhere((t) => t.id == id, orElse: () => throw Exception("Track not found"));
     track.volume = vol;
     _source?.setVolume(id, vol);
     _notifyDirty();
  }
  
  // -- High Precision Polling Getter --
  Duration get currentPosition {
      if (_source != null) {
          final frames = _source!.getAtomicPositionFrames();
          // Hardware Latency Compensation would go here
          // e.g. final latencyFrames = ...
          final sr = _source!.sampleRate;
          if (sr > 0) {
              return Duration(microseconds: (frames * 1000000 / sr).round());
          }
      }
      return Duration.zero;
  }

  void setTrackPan(String id, double pan) {
     final track = _tracks.firstWhere((t) => t.id == id, orElse: () => throw Exception("Track not found"));
     track.pan = pan;
     _source?.setPan(id, pan);
     _notifyDirty();
  }
  
  void toggleTrackMute(String id) {
     final track = _tracks.firstWhere((t) => t.id == id, orElse: () => throw Exception("Track not found"));
     track.isMuted = !track.isMuted;
     _source?.setMute(id, track.isMuted);
     _notifyDirty();
  }
  
  void toggleSolo(String id) {
     final track = _tracks.firstWhere((t) => t.id == id, orElse: () => throw Exception("Track not found"));
     
     track.isSolo = !track.isSolo;
     _source?.setSolo(id, track.isSolo);
     
     _notifyDirty();
  }
  
  void reorderTracks(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _tracks.removeAt(oldIndex);
    _tracks.insert(newIndex, item);
    _notifyDirty();
  }
  
  // -- Looping --
  bool _isLooping = false;

  void setLoopEnabled(bool enabled) {
    _isLooping = enabled;
    // Disable JustAudio looping (handled by Native Mixer)
    _player.setLoopMode(LoopMode.off);
    
    // Notify source
    _source?.setLoopEnabled(enabled); 
  }
  
  void setLoopRange(Duration start, Duration end) {
      // Update range but respect current enabled state
      _source?.setLoop(start, end, _isLooping); 
  }
  
  Future<void> commitLoopRange() async {
     // If we need to finalize something
  }
  
  Future<void> refreshPlayback() async {
    // If we need to force buffer flush or similar.
    // Usually setting parameters on _source is enough.
  }

  void _notifyDirty() {
    _isDirty = true;
    _dirtyController.add(true);
  }
  
  void dispose() {
     _player.dispose();
     _source?.dispose();
     _dirtyController.close();
  }
}
