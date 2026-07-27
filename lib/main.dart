import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/l10n/app_localizations.dart';
import 'package:international_transport_app/l10n/locale_provider.dart';
import 'package:international_transport_app/providers/theme_provider.dart';
import 'package:international_transport_app/screens/login_screen.dart';
import 'package:international_transport_app/services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await SyncService.instance.init();
  final dotenv = DotEnv();
  await dotenv.load();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..initialize(null)),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final cairoTextTheme = GoogleFonts.cairoTextTheme();
          return MaterialApp(
            title: 'النقل الدولي',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.light(useMaterial3: true).copyWith(
              textTheme: cairoTextTheme,
            ),
            darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
              textTheme: cairoTextTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
            ),
            themeMode: themeProvider.themeMode,
            locale: const Locale('ar', 'MA'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LoginScreen(),
          );
        },
      ),
    );
  }
}