import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/locale_provider.dart';

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LocaleProvider>(context, listen: false);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.language),
      onSelected: (code) {
        switch (code) {
          case 'ar':
            provider.setLocale(const Locale('ar'));
          case 'fr':
            provider.setLocale(const Locale('fr'));
          case 'en':
            provider.setLocale(const Locale('en'));
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(value: 'ar', child: Text('العربية')),
        PopupMenuItem<String>(value: 'fr', child: Text('Français')),
        PopupMenuItem<String>(value: 'en', child: Text('English')),
      ],
    );
  }
}
