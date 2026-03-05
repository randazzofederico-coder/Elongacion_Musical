import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:elongacion_musical/services/settings_service.dart';

class MixerSettingsProvider extends ChangeNotifier {
  final SettingsService _settingsService;
  final VoidCallback _onTuningChanged;

  MixerSettingsProvider(this._settingsService, this._onTuningChanged);

  bool get showWaveforms => _settingsService.showWaveforms;
  bool get lockPortrait => _settingsService.lockPortrait;
  
  int get stSequenceMs => _settingsService.stSequenceMs;
  int get stSeekWindowMs => _settingsService.stSeekWindowMs;
  int get stOverlapMs => _settingsService.stOverlapMs;

  Future<void> toggleShowWaveforms() async {
    await _settingsService.setShowWaveforms(!showWaveforms);
    notifyListeners();
  }

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

  Future<void> setStSequenceMs(int val) async {
    await _settingsService.setStSequenceMs(val);
    _onTuningChanged();
    notifyListeners();
  }

  Future<void> setStSeekWindowMs(int val) async {
    await _settingsService.setStSeekWindowMs(val);
    _onTuningChanged();
    notifyListeners();
  }

  Future<void> setStOverlapMs(int val) async {
    await _settingsService.setStOverlapMs(val);
    _onTuningChanged();
    notifyListeners();
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
}
