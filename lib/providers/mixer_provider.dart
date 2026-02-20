import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:elongacion_musical/services/audio_manager.dart';
import 'package:elongacion_musical/services/settings_service.dart';
import 'package:elongacion_musical/models/track_model.dart';
import 'package:elongacion_musical/utils/waveform_utils.dart';
import 'package:elongacion_musical/models/catalog_model.dart';

class MixerProvider with ChangeNotifier {
  final SettingsService _settingsService;
  late final AudioManager _audioManager;
  Exercise? _currentExercise;

  MixerProvider(this._settingsService) {
     _audioManager = AudioManager(_settingsService);
  }
  
  bool _isPlaying = false;
  double _globalSpeed = 1.0;
  
  bool get isPlaying => _isPlaying;
  double get globalSpeed => _globalSpeed;

  // Loop State
  bool _isLooping = false;
  Duration _loopStart = Duration.zero;
  Duration _loopEnd = Duration.zero;

  bool get isLooping => _isLooping;
  Duration get loopStart => _loopStart;
  Duration get loopEnd => _loopEnd;

  SettingsService get settingsService => _settingsService;
  Exercise? get currentExercise => _currentExercise;
  
  List<TrackModel> _cachedTracks = [];
  List<List<double>>? _cachedMasterWaveform;

  List<TrackModel> get tracks {
    // Basic cache invalidation check - if length differs or it's empty but manager has tracks
    if (_cachedTracks.length != _audioManager.tracks.length) {
       _cachedTracks = List.from(_audioManager.tracks);
    }
    return _cachedTracks;
  }

  void _invalidateTracksCache() {
     _cachedTracks = List.from(_audioManager.tracks);
     _cachedMasterWaveform = null; // Invalidate waveform too
  }
  
  double get masterVolume => _audioManager.masterVolume;

  Future<void> setMasterVolume(double vol) async {
    _audioManager.setMasterVolume(vol);
    notifyListeners();
  }
  
  // Streams for Seekbar
  Stream<Duration> get positionStream => _audioManager.positionStream;
  Stream<Duration?> get durationStream => _audioManager.durationStream;
  Stream<Duration> get bufferedPositionStream => _audioManager.bufferedPositionStream;
  Duration? get duration => _audioManager.duration;
  
  Duration get currentPosition => _audioManager.currentPosition; // Polling getter

  bool _isLoading = false;

  bool get isLoading => _isLoading;
  
  bool get isDirty => _audioManager.isDirty;
  Stream<bool> get dirtyStream => _audioManager.dirtyStream;

  // Audio Mode helper
  bool get isOfflineMode => _audioManager.mode == AudioEngineMode.offline;

  Future<void> setAudioMode(AudioEngineMode mode) async {
     await _settingsService.setAudioMode(mode);
     notifyListeners();
  }

  // UI Settings
  bool get showWaveforms => _settingsService.showWaveforms;

  Future<void> toggleShowWaveforms() async {
    await _settingsService.setShowWaveforms(!showWaveforms);
    notifyListeners();
  }

  bool get lockPortrait => _settingsService.lockPortrait;

  Future<void> toggleLockPortrait() async {
    final newValue = !lockPortrait;
    await _settingsService.setLockPortrait(newValue);
    
    if (newValue) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    notifyListeners();
  }

  // --- SoundTouch Tuning ---
  int get stSequenceMs => _settingsService.stSequenceMs;
  int get stSeekWindowMs => _settingsService.stSeekWindowMs;
  int get stOverlapMs => _settingsService.stOverlapMs;

  Future<void> setStSequenceMs(int val) async {
    await _settingsService.setStSequenceMs(val);
    _applyStTuning();
    notifyListeners();
  }

  Future<void> setStSeekWindowMs(int val) async {
    await _settingsService.setStSeekWindowMs(val);
    _applyStTuning();
    notifyListeners();
  }

  Future<void> setStOverlapMs(int val) async {
    await _settingsService.setStOverlapMs(val);
    _applyStTuning();
    notifyListeners();
  }

  void _applyStTuning() {
    _audioManager.updateSoundTouchTuning(
      stSequenceMs,
      stSeekWindowMs,
      stOverlapMs,
    );
  }

  void applyRhythmicProfile() {
      setStSequenceMs(40);
      setStSeekWindowMs(15);
      setStOverlapMs(8);
  }

  void applyMelodicProfile() {
      setStSequenceMs(100);
      setStSeekWindowMs(30);
      setStOverlapMs(16);
  }

  Future<void> loadExercise(Exercise exercise) async {
    _isLoading = true;
    _currentExercise = exercise;
    // Notify to show loading state
    notifyListeners();
    
    try {
      // Clear existing first
      await _audioManager.stop();
      // We might want a method in audioManager to specifically unload/clear if loadTracks doesn't do it fully,
      // but loadTracks typically resets.
      
      final mappedTracks = exercise.tracks.map((t) => {
        'id': t.id,
        'name': t.name,
        'path': t.assetPath,
      }).toList();

      await _audioManager.loadTracks(mappedTracks);
    } catch (e) {
      debugPrint("Error loading exercise in provider: $e");
    } finally {
      _isLoading = false;
      _invalidateTracksCache();
      notifyListeners();
    }
  }


  Future<void> togglePlay() async {
    _isPlaying = !_isPlaying;
    notifyListeners();
    
    try {
      if (!_isPlaying) {
        // Apply initial tuning before playing in case it was changed while stopped
        _applyStTuning();
        await _audioManager.pause();
      } else {
        await _audioManager.play();
      }
    } catch (e) {
      // Revert if failed
      _isPlaying = !_isPlaying;
      notifyListeners();
      debugPrint("Error toggling play: $e");
    }
  }

  Future<void> stop() async {
    _isPlaying = false;
    await _audioManager.stop();
    notifyListeners();
  }

  Future<void> setGlobalSpeed(double speed) async {
    _globalSpeed = speed;
    await _audioManager.setSpeed(speed);
    notifyListeners();
  }

  Future<void> setTrackVolume(String trackId, double volume) async {
    _audioManager.setTrackVolume(trackId, volume);
    // No notifyListeners() - TrackModel handles it
  }

  // Called when slider dragging ends
  Future<void> commitTrackVolume() async {
    _cachedMasterWaveform = null; // Invalidate
    notifyListeners();
    await _audioManager.refreshPlayback();
  }

  Future<void> toggleTrackMute(String trackId) async {
    _audioManager.toggleTrackMute(trackId);
    _cachedMasterWaveform = null;
    notifyListeners();
  }

  Future<void> toggleSolo(String trackId) async {
    _audioManager.toggleSolo(trackId);
    _cachedMasterWaveform = null;
    notifyListeners();
  }

  Future<void> setTrackPan(String trackId, double pan) async {
    _audioManager.setTrackPan(trackId, pan);
    _cachedMasterWaveform = null;
    // Don't notify listeners on pan drag to avoid full rebuild, wait for end? 
    // Or just let it be stale until commit if we had a commitPan. 
    // For now, let's notify on pan to verify visual update if desired, 
    // but pan usually doesn't change waveform shape significantly (just amplitude).
    // Actually, pan CHANGES the master L/R mix. 
    notifyListeners(); 
  }

  List<List<double>> get masterWaveformData {
    if (_cachedMasterWaveform != null) return _cachedMasterWaveform!;
    
    if (_audioManager.tracks.isEmpty) {
       _cachedMasterWaveform = [];
       return [];
    }
    
    _cachedMasterWaveform = generateMasterWaveform(_audioManager.tracks);
    return _cachedMasterWaveform!;
  }

  void reorderTracks(int oldIndex, int newIndex) {
    _audioManager.reorderTracks(oldIndex, newIndex);
    _invalidateTracksCache();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _audioManager.seek(position);
  }

  // Loop Methods
  void toggleLoop() {
    _isLooping = !_isLooping;
    
    // Auto-initialize loop end if needed
    if (_isLooping && _loopEnd == Duration.zero) {
       final total = _audioManager.duration ?? Duration.zero;
       if (total > Duration.zero) {
          _loopEnd = total;
       }
    }
    
    _audioManager.setLoopEnabled(_isLooping);
    // Also push the range in case AudioManager doesn't have it (though AudioManager has its own logic, correct singular source is better)
    _audioManager.setLoopRange(_loopStart, _loopEnd);
    
    notifyListeners();
  }

  Future<void> commitLoopRange() async {
     await _audioManager.commitLoopRange();
  }

  void setLoopRange(Duration start, Duration end) {
    if (start >= end) return;
    _loopStart = start;
    _loopEnd = end;
    _audioManager.setLoopRange(start, end);
    notifyListeners();
  }
}
