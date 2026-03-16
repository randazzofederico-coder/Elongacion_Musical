import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:elongacion_musical/services/audio_manager.dart';
import 'package:elongacion_musical/services/settings_service.dart';
import 'package:elongacion_musical/models/track_model.dart';
import 'package:elongacion_musical/utils/waveform_utils.dart';
import 'package:elongacion_musical/models/catalog_model.dart';

class TrackListProvider extends ChangeNotifier {
  final AudioManager _audioManager;
  final SettingsService _settingsService;
  
  List<TrackModel> _cachedTracks = [];
  List<List<double>>? _cachedMasterWaveform;
  Exercise? _currentExercise;

  TrackListProvider(this._audioManager, this._settingsService);

  void setCurrentExercise(Exercise? ex) {
      _currentExercise = ex;
  }
  
  void invalidateCache() {
     _cachedTracks = List.from(_audioManager.tracks);
     _cachedMasterWaveform = null;
     notifyListeners();
  }

  List<TrackModel> get tracks {
    if (_cachedTracks.length != _audioManager.tracks.length) {
       _cachedTracks = List.from(_audioManager.tracks);
    }
    return _cachedTracks;
  }

  double get masterVolume => _audioManager.masterVolume;

  /// Live master waveform notifier — updated during fader drag for real-time visual
  final ValueNotifier<List<List<double>>> liveMasterWaveformNotifier = ValueNotifier([]);
  
  /// Track of live volume overrides during drag (trackId → liveVolume)
  final Map<String, double> _liveVolumeOverrides = {};

  List<List<double>> get masterWaveformData {
    if (_cachedMasterWaveform != null) return _cachedMasterWaveform!;
    if (_audioManager.tracks.isEmpty) {
       _cachedMasterWaveform = [];
       return [];
    }
    _cachedMasterWaveform = generateMasterWaveform(
       _audioManager.tracks,
       bpm: _currentExercise?.bpm,
       metronomeVol34: metronomeVol34,
       metronomeVol68: metronomeVol68,
       pattern34: _settingsService.metronomePattern34,
       pattern68: _settingsService.metronomePattern68,
    );
    return _cachedMasterWaveform!;
  }

  void restoreStateFromSettings(String exerciseId) {
      final mb = _settingsService.getMasterVolume(exerciseId);
      _audioManager.setMasterVolume(mb);

      for (var t in _audioManager.tracks) {
         t.volume = _settingsService.getTrackVolume(exerciseId, t.id);
         t.pan = _settingsService.getTrackPan(exerciseId, t.id);
         t.isMuted = _settingsService.getTrackMute(exerciseId, t.id);
         t.isSolo = _settingsService.getTrackSolo(exerciseId, t.id);
         _audioManager.setTrackVolume(t.id, t.volume);
         _audioManager.setTrackPan(t.id, t.pan);
         if (t.isMuted) _audioManager.toggleTrackMute(t.id); 
      }
      
      _audioManager.setMetronomePattern(
         _settingsService.metronomePattern34, 
         _settingsService.metronomePattern68
      );
      
      notifyListeners();
  }

  double _masterVol = 1.0;
  
  Future<void> setMasterVolume(double vol) async {
    _masterVol = vol;
    _audioManager.setMasterVolume(vol);
    notifyListeners();
  }

  /// Direct-to-native: no notifyListeners, for use during master fader drag
  void setMasterVolumeDirect(double vol) {
    _masterVol = vol;
    _audioManager.setMasterVolume(vol);
  }

  Future<void> commitMasterVolume() async {
    if (_currentExercise != null) {
      await _settingsService.setMasterVolume(_currentExercise!.id, _masterVol);
    }
  }

  // Metronome Controls
  double _metronomeVol34 = 0.0;
  double _metronomeVol68 = 0.0;
  
  double get metronomeVol34 => _metronomeVol34;
  double get metronomeVol68 => _metronomeVol68;

  void setMetronomeVolume(double vol34, double vol68) {
      _metronomeVol34 = vol34;
      _metronomeVol68 = vol68;
      _audioManager.setMetronomeVolume(vol34, vol68);
      _cachedMasterWaveform = null;
      notifyListeners();
  }
  
  // Mute / Solo states
  bool isMasterMuted = false;
  bool isMasterSolo = false;
  
  bool isMetronome34Muted = false;
  bool isMetronome34Solo = false;
  
  bool isMetronome68Muted = false;
  bool isMetronome68Solo = false;

  void toggleMasterMute() {
     isMasterMuted = !isMasterMuted;
     _audioManager.setMasterMute(isMasterMuted);
     notifyListeners();
  }

  void toggleMasterSolo() {
     isMasterSolo = !isMasterSolo;
     _audioManager.setMasterSolo(isMasterSolo);
     notifyListeners();
  }

  void toggleMetronome34Mute() {
     isMetronome34Muted = !isMetronome34Muted;
     _audioManager.setMetronomeMute(isMetronome34Muted, isMetronome68Muted);
     notifyListeners();
  }

  void toggleMetronome34Solo() {
     isMetronome34Solo = !isMetronome34Solo;
     _audioManager.setMetronomeSolo(isMetronome34Solo, isMetronome68Solo);
     notifyListeners();
  }

  void toggleMetronome68Mute() {
     isMetronome68Muted = !isMetronome68Muted;
     _audioManager.setMetronomeMute(isMetronome34Muted, isMetronome68Muted);
     notifyListeners();
  }

  void toggleMetronome68Solo() {
     isMetronome68Solo = !isMetronome68Solo;
     _audioManager.setMetronomeSolo(isMetronome34Solo, isMetronome68Solo);
     notifyListeners();
  }
  
  void reloadMetronomePatterns() {
      _audioManager.setMetronomePattern(
         _settingsService.metronomePattern34, 
         _settingsService.metronomePattern68
      );
      _cachedMasterWaveform = null;
      notifyListeners();
  }

  Future<void> setTrackVolume(String trackId, double volume) async {
    _audioManager.setTrackVolume(trackId, volume);
  }

  /// Direct-to-native: no TrackModel notification, for use during drag
  void setTrackVolumeDirect(String trackId, double volume) {
    _audioManager.setTrackVolumeDirect(trackId, volume);
  }

  /// Recompute the master waveform with a live volume override.
  /// Called during fader drag for real-time master waveform update.
  void recomputeLiveMasterWaveform(String trackId, double liveVolume) {
    _liveVolumeOverrides[trackId] = liveVolume;
    liveMasterWaveformNotifier.value = _generateLiveMasterWaveform();
  }
  
  /// Clear live overrides and sync notifier with cached master
  void syncLiveMasterWaveform() {
    _liveVolumeOverrides.clear();
    _cachedMasterWaveform = null; // Force recompute on next access  
    liveMasterWaveformNotifier.value = masterWaveformData;
  }

  List<List<double>> _generateLiveMasterWaveform() {
    final tracks = _audioManager.tracks;
    if (tracks.isEmpty) return [];
    
    int points = 0;
    for (var t in tracks) {
      if (t.waveformData.isNotEmpty) {
        points = max(points, t.waveformData[0].length);
      }
    }
    if (points == 0) return [];
    
    List<double> masterL = List.filled(points, 0.0);
    List<double> masterR = List.filled(points, 0.0);
    bool anySolo = tracks.any((t) => t.isSolo);
    
    for (var track in tracks) {
      if (anySolo) {
        if (!track.isSolo) continue;
      } else {
        if (track.isMuted) continue;
      }
      if (track.waveformData.isEmpty) continue;
      
      // Use live override if available, otherwise model value
      double vol = _liveVolumeOverrides[track.id] ?? track.volume;
      double pan = track.pan;
      double lGain = pan > 0 ? 1.0 - pan : 1.0;
      double rGain = pan < 0 ? 1.0 + pan : 1.0;
      bool isStereo = track.waveformData.length > 1;
      int trackPoints = track.waveformData[0].length;
      
      for (int i = 0; i < points && i < trackPoints; i++) {
        if (isStereo) {
          masterL[i] += track.waveformData[0][i] * vol * lGain;
          masterR[i] += track.waveformData[1][i] * vol * rGain;
        } else {
          double val = track.waveformData[0][i];
          masterL[i] += val * vol * lGain;
          masterR[i] += val * vol * rGain;
        }
      }
    }
    
    for (int i = 0; i < points; i++) {
      if (masterL[i] > 1.0) masterL[i] = 1.0;
      if (masterR[i] > 1.0) masterR[i] = 1.0;
    }
    
    return [masterL, masterR];
  }

  Future<void> commitTrackVolume() async {
    _cachedMasterWaveform = null;
    if (_currentExercise != null) {
      for (var t in _audioManager.tracks) {
        await _settingsService.setTrackVolume(_currentExercise!.id, t.id, t.volume);
      }
    }
    notifyListeners();
    await _audioManager.refreshPlayback();
  }

  Future<void> toggleTrackMute(String trackId) async {
    _audioManager.toggleTrackMute(trackId);
    _cachedMasterWaveform = null;
    if (_currentExercise != null) {
      final t = _audioManager.tracks.firstWhere((element) => element.id == trackId);
      await _settingsService.setTrackMute(_currentExercise!.id, trackId, t.isMuted);
    }
    notifyListeners();
  }

  Future<void> toggleSolo(String trackId) async {
    _audioManager.toggleSolo(trackId);
    _cachedMasterWaveform = null;
    if (_currentExercise != null) {
      final t = _audioManager.tracks.firstWhere((element) => element.id == trackId);
      await _settingsService.setTrackSolo(_currentExercise!.id, trackId, t.isSolo);
    }
    notifyListeners();
  }

  Future<void> setTrackPan(String trackId, double pan) async {
    _audioManager.setTrackPan(trackId, pan);
  }

  /// Direct-to-native: no TrackModel notification, for use during drag
  void setTrackPanDirect(String trackId, double pan) {
    _audioManager.setTrackPanDirect(trackId, pan);
  }

  Future<void> commitTrackPan(String trackId) async {
    _cachedMasterWaveform = null;
    if (_currentExercise != null) {
      final t = _audioManager.tracks.firstWhere((element) => element.id == trackId);
      await _settingsService.setTrackPan(_currentExercise!.id, trackId, t.pan);
    }
    notifyListeners();
  }

  void reorderTracks(int oldIndex, int newIndex) {
    _audioManager.reorderTracks(oldIndex, newIndex);
    invalidateCache();
  }

  Future<void> resetAll() async {
      await setMasterVolume(1.0);
      for (var t in _audioManager.tracks) {
         if (t.isMuted) toggleTrackMute(t.id);
         if (t.isSolo) toggleSolo(t.id);
         if (t.volume != 1.0) await setTrackVolume(t.id, 1.0);
         if (t.pan != 0.0) await setTrackPan(t.id, 0.0);
      }
      _cachedMasterWaveform = null;
      notifyListeners();
      await _audioManager.refreshPlayback();
  }
}
