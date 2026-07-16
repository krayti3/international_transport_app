import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _boxName = 'settings';
  static const String _key = 'themeMode';

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadFromStorage(null);
  }

  Future<void> _loadFromStorage(String? userId) async {
    try {
      final box = await Hive.openBox(_boxName);
      final saved = box.get(_resolveKey(userId));
      if (saved is String) {
        switch (saved) {
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'system':
            _themeMode = ThemeMode.system;
            break;
        }
      }
    } catch (_) {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  Future<void> loadForUser(String? userId) async {
    await _loadFromStorage(userId);
  }

  String _resolveKey(String? userId) {
    if (userId != null && userId.isNotEmpty) {
      return '${_key}_$userId';
    }
    return _key;
  }

  Future<void> setThemeMode(ThemeMode mode, {String? userId}) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    try {
      final box = await Hive.openBox(_boxName);
      String value;
      switch (mode) {
        case ThemeMode.dark:
          value = 'dark';
          break;
        case ThemeMode.light:
          value = 'light';
          break;
        case ThemeMode.system:
          value = 'system';
          break;
      }
      await box.put(_resolveKey(userId), value);
    } catch (_) {
      // ignore
    }
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    final next = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(next);
  }

  Future<void> toggleThemeForCurrentUser(String? userId) async {
    final next = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(next, userId: userId);
  }
}
