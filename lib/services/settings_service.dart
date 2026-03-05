import 'package:shared_preferences/shared_preferences.dart';

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

  bool get showWaveforms => _prefs.getBool(_showWaveformsKey) ?? true;

  Future<void> setShowWaveforms(bool value) async {
    await _prefs.setBool(_showWaveformsKey, value);
  }

  bool get lockPortrait => _prefs.getBool(_lockPortraitKey) ?? false;

  Future<void> setLockPortrait(bool value) async {
    await _prefs.setBool(_lockPortraitKey, value);
  }

  bool get isDarkMode => _prefs.getBool('is_dark_mode') ?? false;

  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool('is_dark_mode', value);
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

  // --- Metronome Settings ---
  List<int> get metronomePattern34 {
     final saved = _prefs.getStringList('met_pat_34');
     if (saved == null || saved.length != 6) return [1, 0, 2, 0, 2, 0]; // default: 1 on 1st, 2 on 3rd & 5th eighth
     return saved.map((e) => int.tryParse(e) ?? 0).toList();
  }
  Future<void> setMetronomePattern34(List<int> pattern) async {
     await _prefs.setStringList('met_pat_34', pattern.map((e) => e.toString()).toList());
  }

  List<int> get metronomePattern68 {
     final saved = _prefs.getStringList('met_pat_68');
     if (saved == null || saved.length != 6) return [1, 0, 0, 2, 0, 0]; // default: 1 on 1st, 2 on 4th eighth
     return saved.map((e) => int.tryParse(e) ?? 0).toList();
  }
  Future<void> setMetronomePattern68(List<int> pattern) async {
     await _prefs.setStringList('met_pat_68', pattern.map((e) => e.toString()).toList());
  }

  // --- Exercise Preferences ---
  
  String _exKey(String exerciseId, String key) => '${exerciseId}_$key';

  // Speed
  double getGlobalSpeed(String exerciseId) => _prefs.getDouble(_exKey(exerciseId, 'speed')) ?? 1.0;
  Future<void> setGlobalSpeed(String exerciseId, double speed) async {
    await _prefs.setDouble(_exKey(exerciseId, 'speed'), speed);
  }

  // Loop State
  bool getLoopEnabled(String exerciseId) => _prefs.getBool(_exKey(exerciseId, 'loop_enabled')) ?? false;
  Future<void> setLoopEnabled(String exerciseId, bool enabled) async {
    await _prefs.setBool(_exKey(exerciseId, 'loop_enabled'), enabled);
  }

  int getLoopStart(String exerciseId) => _prefs.getInt(_exKey(exerciseId, 'loop_start')) ?? 0;
  Future<void> setLoopStart(String exerciseId, int microseconds) async {
    await _prefs.setInt(_exKey(exerciseId, 'loop_start'), microseconds);
  }

  int getLoopEnd(String exerciseId) => _prefs.getInt(_exKey(exerciseId, 'loop_end')) ?? 0;
  Future<void> setLoopEnd(String exerciseId, int microseconds) async {
    await _prefs.setInt(_exKey(exerciseId, 'loop_end'), microseconds);
  }

  // Master Volume
  double getMasterVolume(String exerciseId) => _prefs.getDouble(_exKey(exerciseId, 'master_volume')) ?? 1.0;
  Future<void> setMasterVolume(String exerciseId, double volume) async {
    await _prefs.setDouble(_exKey(exerciseId, 'master_volume'), volume);
  }

  // Track Mix State (Track-level)
  String _trKey(String exerciseId, String trackId, String key) => '${exerciseId}_${trackId}_$key';

  double getTrackVolume(String exerciseId, String trackId) => _prefs.getDouble(_trKey(exerciseId, trackId, 'volume')) ?? 1.0;
  Future<void> setTrackVolume(String exerciseId, String trackId, double volume) async {
    await _prefs.setDouble(_trKey(exerciseId, trackId, 'volume'), volume);
  }

  double getTrackPan(String exerciseId, String trackId) => _prefs.getDouble(_trKey(exerciseId, trackId, 'pan')) ?? 0.0;
  Future<void> setTrackPan(String exerciseId, String trackId, double pan) async {
    await _prefs.setDouble(_trKey(exerciseId, trackId, 'pan'), pan);
  }

  bool getTrackMute(String exerciseId, String trackId) => _prefs.getBool(_trKey(exerciseId, trackId, 'mute')) ?? false;
  Future<void> setTrackMute(String exerciseId, String trackId, bool mute) async {
    await _prefs.setBool(_trKey(exerciseId, trackId, 'mute'), mute);
  }

  bool getTrackSolo(String exerciseId, String trackId) => _prefs.getBool(_trKey(exerciseId, trackId, 'solo')) ?? false;
  Future<void> setTrackSolo(String exerciseId, String trackId, bool solo) async {
    await _prefs.setBool(_trKey(exerciseId, trackId, 'solo'), solo);
  }
}
