import 'package:flutter/foundation.dart';
import 'package:elongacion_musical/services/audio_manager.dart';
import 'package:elongacion_musical/services/settings_service.dart';
import 'package:elongacion_musical/models/track_model.dart';
import 'package:elongacion_musical/models/catalog_model.dart';
import 'package:elongacion_musical/providers/playback_provider.dart';
import 'package:elongacion_musical/providers/track_list_provider.dart';
import 'package:elongacion_musical/providers/mixer_settings_provider.dart';

class MixerProvider with ChangeNotifier {
  final SettingsService _settingsService;
  late final AudioManager _audioManager;
  
  late final PlaybackProvider playback;
  late final TrackListProvider trackList;
  late final MixerSettingsProvider mixerSettings;

  Exercise? _currentExercise;

  MixerProvider(this._settingsService) {
     _audioManager = AudioManager(_settingsService);
     
     // Initialize Sub-Providers
     playback = PlaybackProvider(_audioManager, _settingsService, _applyStTuning);
     trackList = TrackListProvider(_audioManager, _settingsService);
     mixerSettings = MixerSettingsProvider(_settingsService, _applyStTuning);
     
     // Forward notifications from sub-providers to keep existing UI binding simple
     playback.addListener(notifyListeners);
     trackList.addListener(notifyListeners);
     mixerSettings.addListener(notifyListeners);
  }

  @override
  void dispose() {
    playback.removeListener(notifyListeners);
    trackList.removeListener(notifyListeners);
    mixerSettings.removeListener(notifyListeners);
    playback.dispose();
    trackList.dispose();
    mixerSettings.dispose();
    _audioManager.dispose();
    super.dispose();
  }

  // --- FACADE METHODS (For Backward Compatibility) ---
  
  Exercise? get currentExercise => _currentExercise;
  SettingsService get settingsService => _settingsService;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool get isDirty => _audioManager.isDirty;
  Stream<bool> get dirtyStream => _audioManager.dirtyStream;

  // Audio Manager State
  Stream<Duration> get positionStream => playback.positionStream;
  Stream<Duration?> get durationStream => playback.durationStream;
  Stream<Duration> get bufferedPositionStream => playback.bufferedPositionStream;
  Duration? get duration => playback.duration;
  Duration get currentPosition => playback.currentPosition;
  bool get isOfflineMode => _audioManager.mode == AudioEngineMode.offline;

  // Playback Passthrough
  bool get isPlaying => playback.isPlaying;
  double get globalSpeed => playback.globalSpeed;
  bool get isLooping => playback.isLooping;
  Duration get loopStart => playback.loopStart;
  Duration get loopEnd => playback.loopEnd;
  
  Future<void> togglePlay() => playback.togglePlay();
  Future<void> stop() => playback.stop();
  Future<void> seek(Duration pos) => playback.seek(pos);
  Future<void> setGlobalSpeed(double speed) => playback.setGlobalSpeed(speed);
  void toggleLoop() => playback.toggleLoop();
  Future<void> commitLoopRange() => playback.commitLoopRange();
  void setLoopRange(Duration start, Duration end) => playback.setLoopRange(start, end);

  // TrackList Passthrough
  List<TrackModel> get tracks => trackList.tracks;
  List<List<double>> get masterWaveformData => trackList.masterWaveformData;
  double get masterVolume => trackList.masterVolume;
  
  double get metronomeVol34 => trackList.metronomeVol34;
  double get metronomeVol68 => trackList.metronomeVol68;
  void setMetronomeVolume(double vol34, double vol68) => trackList.setMetronomeVolume(vol34, vol68);
  void reloadMetronomePatterns() => trackList.reloadMetronomePatterns();
  
  bool _metronomePreviewMode = false;
  bool get metronomePreviewMode => _metronomePreviewMode;
  
  void toggleMetronomePreviewMode() {
      _metronomePreviewMode = !_metronomePreviewMode;
      _audioManager.setMetronomePreviewMode(_metronomePreviewMode);
      
      if (_metronomePreviewMode && !isPlaying) {
          togglePlay();
      }
      
      notifyListeners();
  }
  
  Future<void> setMasterVolume(double vol) => trackList.setMasterVolume(vol);
  Future<void> setTrackVolume(String id, double vol) => trackList.setTrackVolume(id, vol);
  Future<void> commitTrackVolume() => trackList.commitTrackVolume();
  Future<void> toggleTrackMute(String id) => trackList.toggleTrackMute(id);
  Future<void> toggleSolo(String id) => trackList.toggleSolo(id);
  Future<void> setTrackPan(String id, double pan) => trackList.setTrackPan(id, pan);
  void reorderTracks(int oldIndex, int newIndex) => trackList.reorderTracks(oldIndex, newIndex);

  // Master & Metronome Mute / Solo
  bool get isMasterMuted => trackList.isMasterMuted;
  bool get isMasterSolo => trackList.isMasterSolo;
  void toggleMasterMute() => trackList.toggleMasterMute();
  void toggleMasterSolo() => trackList.toggleMasterSolo();

  bool get isMetronome34Muted => trackList.isMetronome34Muted;
  bool get isMetronome34Solo => trackList.isMetronome34Solo;
  void toggleMetronome34Mute() => trackList.toggleMetronome34Mute();
  void toggleMetronome34Solo() => trackList.toggleMetronome34Solo();

  bool get isMetronome68Muted => trackList.isMetronome68Muted;
  bool get isMetronome68Solo => trackList.isMetronome68Solo;
  void toggleMetronome68Mute() => trackList.toggleMetronome68Mute();
  void toggleMetronome68Solo() => trackList.toggleMetronome68Solo();

  // Settings Passthrough
  bool get showWaveforms => mixerSettings.showWaveforms;
  bool get lockPortrait => mixerSettings.lockPortrait;
  Future<void> toggleShowWaveforms() => mixerSettings.toggleShowWaveforms();
  Future<void> toggleLockPortrait() => mixerSettings.toggleLockPortrait();
  Future<void> setAudioMode(AudioEngineMode mode) => mixerSettings.setAudioMode(mode);

  int get stSequenceMs => mixerSettings.stSequenceMs;
  int get stSeekWindowMs => mixerSettings.stSeekWindowMs;
  int get stOverlapMs => mixerSettings.stOverlapMs;
  void applyRhythmicProfile() => mixerSettings.applyRhythmicProfile();
  void applyMelodicProfile() => mixerSettings.applyMelodicProfile();
  Future<void> setStSequenceMs(int val) => mixerSettings.setStSequenceMs(val);
  Future<void> setStSeekWindowMs(int val) => mixerSettings.setStSeekWindowMs(val);
  Future<void> setStOverlapMs(int val) => mixerSettings.setStOverlapMs(val);

  void _applyStTuning() {
    _audioManager.updateSoundTouchTuning(
      stSequenceMs,
      stSeekWindowMs,
      stOverlapMs,
    );
  }

  // --- CORE EXERCISE LOADING ---
  Future<void> loadExercise(Exercise exercise) async {
    _isLoading = true;
    _currentExercise = exercise;
    playback.setCurrentExercise(exercise);
    trackList.setCurrentExercise(exercise);
    notifyListeners();
    
    try {
      await _audioManager.stop();
      
      final mappedTracks = exercise.tracks.map((t) => {
        'id': t.id,
        'name': t.name,
        'path': t.assetPath,
      }).toList();

      await _audioManager.loadTracks(mappedTracks);
      
      _audioManager.setMetronomeConfig(exercise.bpm ?? 0);

      playback.restoreStateFromSettings(exercise.id);
      trackList.restoreStateFromSettings(exercise.id);

    } catch (e) {
      debugPrint("Error loading exercise in provider: $e");
    } finally {
      _isLoading = false;
      trackList.invalidateCache();
      notifyListeners();
    }
  }

  Future<void> resetAll() async {
      await playback.resetAll();
      await trackList.resetAll();
      notifyListeners();
  }
}
