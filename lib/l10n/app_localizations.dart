import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const _fr = <String, String>{};

  static const _en = <String, String>{};

  String _fallback(String key) =>
      locale.languageCode == 'fr' ? (_fr[key] ?? _en[key] ?? key) : (_en[key] ?? key);

  String tr(String key, [List<Object>? args]) {
    final text = locale.languageCode == 'ar'
        ? key
        : _fallback(key);
    if (args == null || args.isEmpty) return text;
    var result = text;
    for (var i = 0; i < args.length; i++) {
      result = result.replaceAll('{$i}', '$args[$i]');
    }
    return result;
  }

  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const supportedLocales = <Locale>[
    Locale('ar'),
    Locale('fr'),
    Locale('en'),
  ];

  static const delegate = AppLocalizationsDelegate();
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'ar' ||
      locale.languageCode == 'fr' ||
      locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

extension LocaleTr on BuildContext {
  String tr(String key, [List<Object>? args]) =>
      AppLocalizations.of(this).tr(key, args);
}
