import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

Future<Map<String, String>> _loadEnv() async {
  try {
    final content = await rootBundle.loadString('.env');
    final result = <String, String>{};
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      final key = trimmed.substring(0, eq).trim();
      final value = trimmed.substring(eq + 1).trim();
      if (key.isNotEmpty) {
        result[key] = value;
      }
    }
    return result;
  } catch (e) {
    debugPrint('خطأ في تحميل ملف .env: $e');
    rethrow;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await SyncService.instance.init();

  final env = await _loadEnv();
  final supabaseUrl = env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception(
      'SUPABASE_URL أو SUPABASE_ANON_KEY مفقودة في ملف .env',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );
  await initializeDateFormatting('ar');
  await initializeDateFormatting('fr');
  await initializeDateFormatting('en');
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
  runApp(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => themeProvider,
      child: ChangeNotifierProvider.value(
        value: invoiceProvider,
        child: MyApp(themeProvider: themeProvider),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.authStateStream, required this.themeProvider});
  final Stream<AuthState>? authStateStream;
  final ThemeProvider themeProvider;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<void>? _themeInit;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _themeInit = widget.themeProvider.initialize(Supabase.instance.client.auth.currentUser?.id);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = Provider.of<ThemeProvider>(context, listen: true).themeMode;

    return ChangeNotifierProvider<LocaleProvider>(
      create: (_) => LocaleProvider(),
      child: Builder(
        builder: (context) {
          final seedColor = Colors.blue;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'International Transport',
            themeMode: themeMode,
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
              ).copyWith(
                surface: const Color(0xFF121212),
                surfaceContainer: const Color(0xFF1E1E1E),
                surfaceContainerHighest: const Color(0xFF2A2A2A),
                onSurface: const Color(0xFFE6E6E6),
                onSurfaceVariant: const Color(0xFFB3B3B3),
              ),
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
            home: FutureBuilder(
              future: _themeInit,
              builder: (context, themeSnapshot) {
                if (themeSnapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return StreamBuilder<AuthState>(
                  stream: widget.authStateStream ?? Supabase.instance.client.auth.onAuthStateChange,
                  builder: (context, snapshot) {
                    final session = snapshot.data?.session ??
                        Supabase.instance.client.auth.currentSession;
                    final userId = session?.user.id ??
                        Supabase.instance.client.auth.currentUser?.id;

                    if (_lastUserId != userId) {
                      _lastUserId = userId;
                      if (userId != null) {
                        widget.themeProvider.reloadForUser(userId);
                      }
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
                );
              },
            ),
          );
        },
      ),
    );
  }
}
