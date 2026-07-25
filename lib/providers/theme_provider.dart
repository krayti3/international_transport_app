import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/supabase_service.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _boxName = 'settings';
  static const String _key = 'themeMode';

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  final SupabaseService _supabaseService = SupabaseService();
  ThemeProvider();

  Future<void> initialize(String? userId) async {
    await _loadFromStorage(null);
    if (userId != null && userId.isNotEmpty) {
      await _loadFromStorage(userId);
    }
  }

  Future<void> reloadForUser(String? userId) async {
    if (userId != null && userId.isNotEmpty) {
      await _loadFromStorage(userId);
      try {
        final row = await _supabaseService.supabase
            .from('users')
            .select('theme_mode')
            .eq('id', userId)
            .maybeSingle();
        final modeStr = row?['theme_mode']?.toString() ?? 'system';
        ThemeMode mode;
        switch (modeStr) {
          case 'dark':
            mode = ThemeMode.dark;
            break;
          case 'light':
            mode = ThemeMode.light;
            break;
          default:
            mode = ThemeMode.system;
        }
        await setThemeMode(mode, userId: userId);
      } catch (e) {
        debugPrint('ThemeProvider.reloadForUser error: $e');
      }
    }
  }

  Future<void> _loadFromStorage(String? userId) async {
    debugPrint('ThemeProvider._loadFromStorage: userId=$userId, key=${_resolveKey(userId)}');
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

  String _resolveKey(String? userId) {
    if (userId != null && userId.isNotEmpty) {
      return '${_key}_$userId';
    }
    return _key;
  }

  Future<void> setThemeMode(ThemeMode mode, {String? userId}) async {
    debugPrint('ThemeProvider.setThemeMode: mode=$mode, userId=$userId, key=${_resolveKey(userId)}');
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
      if (userId != null && userId.isNotEmpty) {
        await _supabaseService.updateUserThemeMode(userId, value);
      }
    } catch (e) {
      debugPrint('ThemeProvider.setThemeMode error: $e');
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
