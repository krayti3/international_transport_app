import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'dart:io';

import 'l10n/locale_provider.dart';
import 'l10n/app_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/sync_service.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'providers/theme_provider.dart';
import 'providers/invoice_provider.dart';
import 'widgets/realtime_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await SyncService.instance.init();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  await initializeDateFormatting('ar');
  await initializeDateFormatting('fr');
  await initializeDateFormatting('en');
  // 🛡️ تهيئة الإشعارات المحلية للهواتف فقط ومنع تشغيلها على الويندوز
  if (!kIsWeb && !Platform.isWindows) {
    try {
      await NotificationService().initialize();
    } catch (e) {
      debugPrint("خطأ في تهيئة إشعارات الهاتف: $e");
    }
  }
  final supabaseService = SupabaseService();
  SyncService.instance.startConnectivityListener(() => supabaseService.syncOfflineQueue());
  final hasConnection = await InternetConnectionChecker.createInstance().hasConnection;
  if (hasConnection) {
    supabaseService.syncOfflineQueue();
  }
  final themeProvider = ThemeProvider();
  final invoiceProvider = InvoiceProvider();
  final currentUser = Supabase.instance.client.auth.currentUser;
  if (currentUser != null) {
    themeProvider.loadForUser(currentUser.id);
  }
  runApp(
    ChangeNotifierProvider.value(
      value: themeProvider,
      child: ChangeNotifierProvider.value(
        value: invoiceProvider,
        child: MyApp(themeProvider: themeProvider),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.authStateStream, required this.themeProvider});
  final Stream<AuthState>? authStateStream;
  final ThemeProvider themeProvider;

  @override
  Widget build(BuildContext context) {
    final themeProvider = this.themeProvider;

    return ChangeNotifierProvider<LocaleProvider>(
      create: (_) => LocaleProvider(),
      child: Builder(
        builder: (context) {
          final seedColor = Colors.blue;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'International Transport',
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: seedColor,
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: seedColor,
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: const Color(0xFF121212),
            ),
            locale: Provider.of<LocaleProvider>(context, listen: false).locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) {
              final isRtl = Provider.of<LocaleProvider>(context, listen: false).locale.languageCode == 'ar';
              return Directionality(
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                child: child!,
              );
            },
            home: StreamBuilder<AuthState>(
              stream: authStateStream ?? Supabase.instance.client.auth.onAuthStateChange,
              builder: (context, snapshot) {
                Session? session;
                try {
                  session = snapshot.data?.session ??
                      Supabase.instance.client.auth.currentSession;
                } catch (e) {
                  session = null;
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    session == null) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (session != null) {
                  return const RealtimeNotifications(child: MainScreen());
                } else {
                  return const LoginScreen();
                }
              },
            ),
          );
        },
      ),
    );
  }
}
