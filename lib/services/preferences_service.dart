import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Key for SharedPreferences provider (must be overridden)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

class PreferencesService {
  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static const _keyTheme = 'theme_mode';
  static const _keyFontSize = 'font_size';
  static const _keyDevMode = 'dev_mode';
  static const _keyPerfOverlay = 'perf_overlay';

  ThemeMode getTheme() {
    final val = _prefs.getString(_keyTheme);
    if (val == 'light') return ThemeMode.light;
    if (val == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  Future<void> setTheme(ThemeMode mode) async {
    final val = mode == ThemeMode.light ? 'light' : (mode == ThemeMode.dark ? 'dark' : 'system');
    await _prefs.setString(_keyTheme, val);
  }

  double getFontSize() => _prefs.getDouble(_keyFontSize) ?? 1.0;
  Future<void> setFontSize(double size) => _prefs.setDouble(_keyFontSize, size);

  bool getDevMode() => _prefs.getBool(_keyDevMode) ?? false;
  Future<void> setDevMode(bool val) => _prefs.setBool(_keyDevMode, val);

  bool getPerfOverlay() => _prefs.getBool(_keyPerfOverlay) ?? false;
  Future<void> setPerfOverlay(bool val) => _prefs.setBool(_keyPerfOverlay, val);
}

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesService(prefs);
});
