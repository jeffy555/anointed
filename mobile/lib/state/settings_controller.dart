import 'package:flutter/material.dart';

import '../core/local_store.dart';
import '../core/tokens.dart';

/// M-27 display and reminder preferences.
///
/// Text size and appearance are stored on-device only: they are per-device
/// ergonomics, not account data, so they never need to follow the user across
/// installs (matching the backend's `SettingsUpdateRequest`, which accepts only
/// the notification opt-in).
class SettingsController extends ChangeNotifier {
  SettingsController(this._store);

  final LocalStore _store;

  ThemeMode get themeMode {
    switch (_store.themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        // design-spec §12: follow the OS preference until the user overrides it.
        return ThemeMode.system;
    }
  }

  bool get largeText => _store.largeText;

  /// Multiplier applied on top of the OS text scale, so the "Large text" option
  /// and the system accessibility setting compose instead of double-scaling
  /// (design-spec §8).
  double get textScaleMultiplier =>
      largeText ? AppTypeScale.largeTextMultiplier : 1.0;

  Future<void> setThemeMode(ThemeMode mode) async {
    final String value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _store.setThemeMode(value);
    notifyListeners();
  }

  Future<void> setLargeText(bool value) async {
    await _store.setLargeText(value);
    notifyListeners();
  }
}
