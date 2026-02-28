import 'package:flutter/foundation.dart';
import 'package:elongacion_musical/services/audio_manager.dart';
import 'package:elongacion_musical/services/settings_service.dart';
import 'package:elongacion_musical/models/catalog_model.dart';
// Note: We need a callback to trigger StTuning in the facade
typedef TuningCallback = void Function();

class PlaybackProvider extends ChangeNotifier {
  final AudioManager _audioManager;
  final SettingsService _settingsService;
  final TuningCallback _applyStTuning;
  
  Exercise? _currentExercise;
  bool _isPlaying = false;
  double _globalSpeed = 1.0;
  
  // Loop State
  bool _isLooping = false;
  Duration _loopStart = Duration.zero;
  Duration _loopEnd = Duration.zero;

  PlaybackProvider(this._audioManager, this._settingsService, this._applyStTuning);

  bool get isPlaying => _isPlaying;
  double get globalSpeed => _globalSpeed;
  bool get isLooping => _isLooping;
  Duration get loopStart => _loopStart;
  Duration get loopEnd => _loopEnd;
  Exercise? get currentExercise => _currentExercise;

  // Streams for Seekbar
  Stream<Duration> get positionStream => _audioManager.positionStream;
  Stream<Duration?> get durationStream => _audioManager.durationStream;
  Stream<Duration> get bufferedPositionStream => _audioManager.bufferedPositionStream;
  Duration? get duration => _audioManager.duration;
  Duration get currentPosition => _audioManager.currentPosition;

  void setCurrentExercise(Exercise? ex) {
      _currentExercise = ex;
      notifyListeners();
  }

  void restoreStateFromSettings(String exerciseId) {
      _isLooping = _settingsService.getLoopEnabled(exerciseId);
      final lStart = _settingsService.getLoopStart(exerciseId);
      final lEnd = _settingsService.getLoopEnd(exerciseId);
      _loopStart = Duration(microseconds: lStart);
      _loopEnd = Duration(microseconds: lEnd);
      
      _audioManager.setLoopEnabled(_isLooping);
      if (lStart > 0 || lEnd > 0) {
         _audioManager.setLoopRange(_loopStart, _loopEnd);
      }

      _globalSpeed = _settingsService.getGlobalSpeed(exerciseId);
      _audioManager.setSpeed(_globalSpeed);
      notifyListeners();
  }

  Future<void> togglePlay() async {
    _isPlaying = !_isPlaying;
    notifyListeners();
    
    try {
      if (!_isPlaying) {
        _applyStTuning();
        await _audioManager.pause();
      } else {
        await _audioManager.play();
      }
    } catch (e) {
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

  Future<void> seek(Duration position) async {
    await _audioManager.seek(position);
  }

  Future<void> setGlobalSpeed(double speed) async {
    _globalSpeed = speed;
    await _audioManager.setSpeed(speed);
    if (_currentExercise != null) {
      await _settingsService.setGlobalSpeed(_currentExercise!.id, speed);
    }
    notifyListeners();
  }

  void toggleLoop() {
    _isLooping = !_isLooping;
    
    if (_isLooping && _loopEnd == Duration.zero) {
       final total = _audioManager.duration ?? Duration.zero;
       if (total > Duration.zero) {
          _loopEnd = total;
       }
    }
    
    _audioManager.setLoopEnabled(_isLooping);
    _audioManager.setLoopRange(_loopStart, _loopEnd);
    
    if (_currentExercise != null) {
       _settingsService.setLoopEnabled(_currentExercise!.id, _isLooping);
       _settingsService.setLoopStart(_currentExercise!.id, _loopStart.inMicroseconds);
       _settingsService.setLoopEnd(_currentExercise!.id, _loopEnd.inMicroseconds);
    }

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

    if (_currentExercise != null) {
       _settingsService.setLoopStart(_currentExercise!.id, start.inMicroseconds);
       _settingsService.setLoopEnd(_currentExercise!.id, end.inMicroseconds);
    }

    notifyListeners();
  }

  Future<void> resetAll() async {
      await setGlobalSpeed(1.0);
      _isLooping = false;
      _loopStart = Duration.zero;
      _loopEnd = Duration.zero;
      _audioManager.setLoopEnabled(false);
      
      if (_currentExercise != null) {
         final exId = _currentExercise!.id;
         await _settingsService.setLoopEnabled(exId, false);
         await _settingsService.setLoopStart(exId, 0);
         await _settingsService.setLoopEnd(exId, 0);
      }
      notifyListeners();
  }
}
