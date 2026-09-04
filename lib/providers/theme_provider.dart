// Theme mode — follows the OS by default, remembers a manual override.
//
// The stored value is one of 'system' | 'light' | 'dark'. Reading it is async,
// so the app starts on ThemeMode.system and settles onto the saved choice a
// frame or two later; that avoids blocking first paint on disk I/O.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'themeMode';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved == null) return;
      state = _decode(saved);
    } catch (e) {
      // A failed read just means we stay on the system setting.
      debugPrint('ThemeModeNotifier: could not read saved theme — $e');
    }
  }

  Future<void> set(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _encode(mode));
    } catch (e) {
      debugPrint('ThemeModeNotifier: could not save theme — $e');
    }
  }

  /// Cycles light → dark → follow system → light.
  Future<void> cycle() => set(switch (state) {
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
        ThemeMode.system => ThemeMode.light,
      });

  /// Flips to the opposite of what is currently *shown*. Used by the simple
  /// two-state toggle; pass the brightness the widget is actually rendering.
  Future<void> toggle({required bool currentlyDark}) =>
      set(currentlyDark ? ThemeMode.light : ThemeMode.dark);

  static ThemeMode _decode(String s) => switch (s) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _encode(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
