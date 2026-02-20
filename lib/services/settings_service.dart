import 'package:shared_preferences/shared_preferences.dart';

enum AudioEngineMode {
  realtime,
  offline
}

class SettingsService {
  static const String _audioModeKey = 'audio_mode';
  static const String _showWaveformsKey = 'show_waveforms';
  static const String _lockPortraitKey = 'lock_portrait';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  static Future<SettingsService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService(prefs);
  }

  AudioEngineMode get audioMode {
    final index = _prefs.getInt(_audioModeKey);
    if (index == null) return AudioEngineMode.realtime; 
    return AudioEngineMode.values[index];
  }

  Future<void> setAudioMode(AudioEngineMode mode) async {
    await _prefs.setInt(_audioModeKey, mode.index);
  }

  bool get showWaveforms => _prefs.getBool(_showWaveformsKey) ?? true;

  Future<void> setShowWaveforms(bool value) async {
    await _prefs.setBool(_showWaveformsKey, value);
  }

  bool get lockPortrait => _prefs.getBool(_lockPortraitKey) ?? false;

  Future<void> setLockPortrait(bool value) async {
    await _prefs.setBool(_lockPortraitKey, value);
  }

  // --- SoundTouch Tuning ---
  int get stSequenceMs => _prefs.getInt('st_seq') ?? 82; // Default SoundTouch Sequence
  Future<void> setStSequenceMs(int value) async {
    await _prefs.setInt('st_seq', value);
  }

  int get stSeekWindowMs => _prefs.getInt('st_seek') ?? 28; // Default SoundTouch SeekWindow
  Future<void> setStSeekWindowMs(int value) async {
    await _prefs.setInt('st_seek', value);
  }

  int get stOverlapMs => _prefs.getInt('st_overlap') ?? 8; // Default SoundTouch Overlap
  Future<void> setStOverlapMs(int value) async {
    await _prefs.setInt('st_overlap', value);
  }
}
