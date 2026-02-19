import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/preferences_service.dart';

// Theme Mode
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    try {
      return ref.watch(preferencesServiceProvider).getTheme();
    } catch (_) {
      return ThemeMode.dark;
    }
  }
  
  void set(ThemeMode mode) {
    state = mode;
    ref.read(preferencesServiceProvider).setTheme(mode);
  }
}
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// Font Size
class FontSizeNotifier extends Notifier<double> {
  @override
  double build() {
    try {
      return ref.watch(preferencesServiceProvider).getFontSize();
    } catch (_) {
      return 1.0;
    }
  }
  
  void set(double size) {
    state = size;
    ref.read(preferencesServiceProvider).setFontSize(size);
  }
}
final fontSizeProvider = NotifierProvider<FontSizeNotifier, double>(FontSizeNotifier.new);

// Developer Mode
class DeveloperModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    try {
      return ref.watch(preferencesServiceProvider).getDevMode();
    } catch (_) {
      return false;
    }
  }
  
  void toggle() {
    state = !state;
    ref.read(preferencesServiceProvider).setDevMode(state);
  }
  
  void set(bool val) {
    state = val;
    ref.read(preferencesServiceProvider).setDevMode(val);
  }
}
final developerModeProvider = NotifierProvider<DeveloperModeNotifier, bool>(DeveloperModeNotifier.new);

// Performance Overlay
class PerformanceOverlayNotifier extends Notifier<bool> {
  @override
  bool build() {
    try {
      return ref.watch(preferencesServiceProvider).getPerfOverlay();
    } catch (_) {
      return false;
    }
  }
  
  void set(bool val) {
    state = val;
    ref.read(preferencesServiceProvider).setPerfOverlay(val);
  }
}
final showPerformanceOverlayProvider = NotifierProvider<PerformanceOverlayNotifier, bool>(PerformanceOverlayNotifier.new);
