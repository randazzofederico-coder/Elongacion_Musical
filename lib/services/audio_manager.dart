import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';
import 'package:wav/wav.dart';
import 'dart:io' show Platform, File;
import 'package:path_provider/path_provider.dart';
import 'package:native_audio_engine/live_mixer.dart';
import 'package:native_audio_engine/audio_track_info.dart';
import 'package:elongacion_musical/models/track_model.dart';
import 'package:elongacion_musical/services/mixer_stream_source.dart';
import 'package:elongacion_musical/services/settings_service.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:rxdart/rxdart.dart';
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
  final _dirtyController = BehaviorSubject<bool>.seeded(false);
  Stream<bool> get dirtyStream => _dirtyController.stream;
  bool _isDirty = false;
  bool get isDirty => _isDirty;

  // Constructor
  AudioManager(SettingsService settingsService);

  // -- Playback State --
  // Use BehaviorSubject to always provide the latest state to new listeners
  final _positionController = BehaviorSubject<Duration>.seeded(Duration.zero);
  Stream<Duration> get positionStream => _positionController.stream;
  
  // Custom Duration Stream
  final _durationController = BehaviorSubject<Duration?>.seeded(null);
  Stream<Duration?> get durationStream => _durationController.stream;
  
  // Custom Player State Stream
  final _playerStateController = BehaviorSubject<PlayerState>.seeded(PlayerState(false, ProcessingState.ready));
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;
  
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream; // Meaningless now?
  // Return cached duration or source duration
  Duration? get duration => _source?.sourceDuration; // _player.duration;
  
  Timer? _positionTimer;
  
  // -- Mode --

  // -- Master --
  double _masterVolume = 1.0;
  double get masterVolume => _masterVolume;

  // -- Metronome --
  double _metronomeVol34 = 0.0;
  double _metronomeVol68 = 0.0;
  int? _currentBpm;

  // Add a getter that defaults to 120 if _currentBpm is null
  int get currentBpm => _currentBpm ?? 120;

  double get metronomeVol34 => _metronomeVol34;
  double get metronomeVol68 => _metronomeVol68;

  // -- Solo --
  // (Handling moved entirely to Tracks, backend manages `anySolo`)

  // -- Loading --
  Future<void> loadTracks(List<Map<String, String>> trackConfigs) async {
    try {
      await stop();
      _source?.dispose();
      _source = null;
      _tracks.clear();
      
      final liveMixer = LiveMixer();
      if (kIsWeb) {
          // Dynamic invocation of the Future initialization just on Web
          // This avoids the type checker throwing an error on Native where init() doesn't exist.
          try {
             await (liveMixer as dynamic).init();
          } catch (e) {
             print("Web Initialization Error: $e");
          }
      }
      
      List<TrackModel> loadedTracks = [];
      
      int maxSamples = 0;
      int globalSampleRate = 44100;
      
      for (var config in trackConfigs) {
        final id = config['id']!;
        final path = config['path']!; // Absolute path to file
        final name = config['name'] ?? 'Track';
        
        String physicalPath = path;
        File? tempFile;
        File? ffmpegOutputFile;
        
        // Extract asset to temp file if necessary (Native only)
        if (!kIsWeb && path.startsWith('assets/')) {
             try {
                 final data = await rootBundle.load(path);
                 final tempDir = await getTemporaryDirectory();
                 final ext = path.split('.').last;
                 tempFile = File('${tempDir.path}/temp_${id}_${DateTime.now().millisecondsSinceEpoch}.$ext');
                 await tempFile.writeAsBytes(data.buffer.asUint8List());
                 physicalPath = tempFile.absolute.path;
                 print("NativeAudioEngine: Wrote asset to temporary file: $physicalPath");
             } catch (e) {
                 print("NativeAudioEngine warning: Failed to load asset $path. Skipping track. Error: $e");
                 continue;
             }
        }
        
        // Check file exists (Native only)
        if (!kIsWeb && !File(physicalPath).existsSync()) {
           print("Native decoder error: File does not exist at $physicalPath");
           if (tempFile != null) await tempFile.delete();
           continue;
        }
        
        bool useFfmpeg = !kIsWeb && (Platform.isAndroid || Platform.isLinux);
        if (useFfmpeg && !physicalPath.toLowerCase().endsWith('.wav')) {
             final tempDir = await getTemporaryDirectory();
             ffmpegOutputFile = File('${tempDir.path}/decoded_${id}_${DateTime.now().millisecondsSinceEpoch}.wav');
             
             final command = "-i \"$physicalPath\" -c:a pcm_s16le -ar 44100 \"${ffmpegOutputFile.path}\"";
             final session = await FFmpegKit.execute(command);
             final returnCode = await session.getReturnCode();
             
             if (ReturnCode.isSuccess(returnCode)) {
                physicalPath = ffmpegOutputFile.path;
                print("FFMPEG: Decoded natively to $physicalPath");
             } else {
                print("FFMPEG: Failed to decode $physicalPath. Attempting to pass to miniaudio anyway.");
             }
        }
        
        AudioTrackInfo? decoded;
        
        if (kIsWeb) {
             try {
                // Fetch bytes via HTTP or root bundle in a web-compatible way. 
                // Currently path from assets:
                final data = await rootBundle.load(path);
                final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
                // Use dynamic to support async on Web while maintaining synchronous signature on Native
                decoded = await (liveMixer as dynamic).addTrackMemory(id, bytes);
             } catch (e) {
                 print("NativeAudioEngine web load error: $e");
             }
        } else {
            // Call C++ Loader natively
            decoded = liveMixer.addTrack(id, physicalPath);
        }
        
        if (decoded == null || decoded.error != 0) {
           int errorCode = decoded?.error ?? -999;
           if (tempFile != null) await tempFile.delete();
           if (ffmpegOutputFile != null) await ffmpegOutputFile.delete();
           throw Exception("Miniaudio ERROR CODE: $errorCode when trying to decode $path.");
        }
        
        final sampleCount = decoded.totalFrames * decoded.channels;
        final channels = decoded.channels;
        final sr = decoded.sampleRate;
        final totalFrames = decoded.totalFrames;
        
        // Extract low-res visual Waveform generated instantly by C++
        List<List<double>> waveform = [];
        int pointsPerChannel = decoded.peakDataLength ~/ channels;
        
        for (int c = 0; c < channels; c++) {
            List<double> channelPeaks = [];
            for (int p = 0; p < pointsPerChannel; p++) {
                channelPeaks.add(decoded.peakData[c * pointsPerChannel + p]);
            }
            waveform.add(channelPeaks);
        }
        
        // Cargar audios completos y mantener RAM es INNECESARIO. Eliminamos el caché del disco.
        if (!kIsWeb) {
            if (tempFile != null) await tempFile.delete();
            if (ffmpegOutputFile != null) await ffmpegOutputFile.delete();
        }

        final track = TrackModel(
          id: id,
          name: name,
          assetPath: path,
        );
        track.waveformData = waveform;
        track.sampleRate = sr;
        track.totalFrames = totalFrames;
        
        loadedTracks.add(track);
        
        if (totalFrames > maxSamples) maxSamples = totalFrames;
        if (sr > globalSampleRate) globalSampleRate = sr;
      }
      
      _tracks = loadedTracks;
      
      // Calculate Latency Hint
      Duration latency = const Duration(milliseconds: 200); 
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
         latency = kMobileBuffer + kHardwareLatencyEst;
      }
      
      // Initialize Source wrapping the pre-loaded C++ Mixer
      _source = MixerStreamSource(
         liveMixer,
         _tracks, 
         maxSamples, 
         globalSampleRate,
         getMasterVolume: () => _masterVolume,
         getPosition: () => Duration.zero,
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
      
      // Update custom streams
      _durationController.add(_source!.sourceDuration);
      
      // Set initial volume/pan restoring config
      for (var track in _tracks) {
          liveMixer.setVolume(track.id, track.volume);
          liveMixer.setPan(track.id, track.pan);
          liveMixer.setMute(track.id, track.isMuted);
          liveMixer.setSolo(track.id, track.isSolo);
      }
      
    } catch (e) {
      debugPrint("AudioManager: Error loading tracks: $e");
      throw e;
    }
  }
  
  
  // Wait for _source native play inside a try block
  Future<void> play() async {
    try {
      if (kIsWeb) {
          // Trigger resume on the native source to satisfy browser requirements
          _source?.playNative();
      } else {
          _source?.playNative();
      }
      _startPositionTimer();
      _playerStateController.add(PlayerState(true, ProcessingState.ready));
    } catch (e) {
      debugPrint("Play error: $e");
    }
  }
  
  Future<void> pause() async {
    _source?.stopNative();
    _stopPositionTimer();
    _playerStateController.add(PlayerState(false, ProcessingState.ready));
  }
  
  Future<void> stop() async {
    _source?.stopNative();
    _stopPositionTimer();
    
    _source?.seek(Duration.zero); 
    _positionController.add(Duration.zero); 
    _playerStateController.add(PlayerState(false, ProcessingState.completed));
  }
  
  // Internal Timer for Polling Native Position
  void _startPositionTimer() {
    _positionTimer?.cancel();
    // Use an aggressive poll for 60fps UI sync
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

  /// Direct-to-native: only sends to audio engine, does NOT update TrackModel.
  /// Use during continuous drag to avoid notifyListeners cascade.
  void setTrackVolumeDirect(String id, double vol) {
     _source?.setVolume(id, vol);
  }
  
  // -- High Precision Polling Getter --
  Duration get currentPosition {
      if (_source != null) {
          final frames = _source!.getAtomicPositionFrames();
          final sr = _source!.sampleRate;
          if (sr > 0) {
              return Duration(microseconds: (frames * 1000000 / sr).round());
          }
      }
      return _positionController.value;
  }

  void setTrackPan(String id, double pan) {
     final track = _tracks.firstWhere((t) => t.id == id, orElse: () => throw Exception("Track not found"));
     track.pan = pan;
     _source?.setPan(id, pan);
     _notifyDirty();
  }

  /// Direct-to-native: only sends to audio engine, does NOT update TrackModel.
  void setTrackPanDirect(String id, double pan) {
     _source?.setPan(id, pan);
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
