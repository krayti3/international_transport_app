import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _boxName = 'settings';
  static const String _key = 'locale';

  Locale _locale;

  LocaleProvider({Locale? initialLocale})
       : _locale = initialLocale ?? const Locale('ar', 'MA') {
    _loadFromStorage();
  }

  Locale get locale => _locale;

  Future<void> _loadFromStorage() async {
    try {
      final box = await Hive.openBox(_boxName);
      final saved = box.get(_key);
      if (saved is String) {
        final parts = saved.split('_');
        if (parts.length >= 2) {
          _locale = Locale(parts[0], parts[1]);
        } else {
          _locale = Locale(saved);
        }
      }
    } catch (_) {
      _locale = const Locale('ar', 'MA');
    }
    Intl.defaultLocale = _locale.toString();
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    Intl.defaultLocale = locale.toString();
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_key, locale.toString());
    } catch (_) {
      // ignore
    }
    notifyListeners();
  }
}
