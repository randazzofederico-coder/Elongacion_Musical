import 'package:flutter/material.dart';
import 'package:elongacion_musical/services/settings_service.dart';

class ThemeProvider extends ChangeNotifier {
  final SettingsService _settingsService;
  late ThemeMode _themeMode;

  ThemeProvider(this._settingsService) {
    _themeMode = _settingsService.isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    await _settingsService.setDarkMode(isDark);
    notifyListeners();
  }
}
