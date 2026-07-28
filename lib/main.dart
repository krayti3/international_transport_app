import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/l10n/app_localizations.dart';
import 'package:international_transport_app/l10n/locale_provider.dart';
import 'package:international_transport_app/providers/theme_provider.dart';
import 'package:international_transport_app/app_router.dart';
import 'package:international_transport_app/services/sync_service.dart';
import 'package:international_transport_app/services/cache_service.dart';
import 'package:international_transport_app/repositories/treasury_repository.dart';
import 'package:international_transport_app/repositories/invoice_repository.dart';
import 'package:international_transport_app/repositories/settings_repository.dart';
import 'package:international_transport_app/repositories/bank_account_repository.dart';
import 'package:international_transport_app/repositories/cash_box_repository.dart';
import 'package:international_transport_app/repositories/driver_repository.dart';
import 'package:international_transport_app/repositories/truck_repository.dart';
import 'package:international_transport_app/repositories/trailer_repository.dart';
import 'package:international_transport_app/repositories/trip_repository.dart';
import 'package:international_transport_app/repositories/maintenance_repository.dart';
import 'package:international_transport_app/repositories/advance_repository.dart';
import 'package:international_transport_app/repositories/document_repository.dart';
import 'package:international_transport_app/features/clients/repositories/client_repository.dart';
import 'package:international_transport_app/cubits/treasury_cubit.dart';
import 'package:international_transport_app/cubits/drivers_cubit.dart';
import 'package:international_transport_app/cubits/trucks_cubit.dart';
import 'package:international_transport_app/cubits/trailers_cubit.dart';
import 'package:international_transport_app/cubits/invoices_cubit.dart';
import 'package:international_transport_app/cubits/bank_accounts_cubit.dart';
import 'package:international_transport_app/cubits/settings_cubit.dart';
import 'package:international_transport_app/cubits/trips_cubit.dart';
import 'package:international_transport_app/features/clients/cubits/clients_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await SyncService.instance.init();
  await CacheService.instance.init();
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
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => TreasuryRepository(Supabase.instance.client)),
        RepositoryProvider(create: (_) => ClientRepository(Supabase.instance.client)),
        RepositoryProvider(create: (_) => InvoiceRepository(Supabase.instance.client)),
        RepositoryProvider(create: (_) => SettingsRepository(Supabase.instance.client)),
        RepositoryProvider(create: (_) => BankAccountRepository(Supabase.instance.client)),
        RepositoryProvider(create: (_) => CashBoxRepository(Supabase.instance.client)),
        RepositoryProvider(create: (_) => DriverRepository(Supabase.instance.client)),
        RepositoryProvider(create: (_) => TruckRepository(Supabase.instance.client)),
        RepositoryProvider(create: (_) => TrailerRepository(Supabase.instance.client)),
        RepositoryProvider(create: (_) => TripRepository(Supabase.instance.client)),
        RepositoryProvider(create: (_) => MaintenanceRepository(Supabase.instance.client)),
        RepositoryProvider(create: (_) => AdvanceRepository(Supabase.instance.client)),
        RepositoryProvider(create: (_) => DocumentRepository(Supabase.instance.client)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => TreasuryCubit(context.read<TreasuryRepository>())),
          BlocProvider(create: (context) => DriversCubit(context.read<DriverRepository>())),
          BlocProvider(create: (context) => TrucksCubit(
            context.read<TruckRepository>(),
            context.read<TrailerRepository>(),
          )),
          BlocProvider(create: (context) => TrailersCubit(context.read<TrailerRepository>())),
          BlocProvider(create: (context) => InvoicesCubit(
            context.read<InvoiceRepository>(),
            context.read<ClientRepository>(),
            context.read<SettingsRepository>(),
          )),
          BlocProvider(create: (context) => BankAccountsCubit(context.read<BankAccountRepository>())),
          BlocProvider(create: (context) => SettingsCubit(context.read<SettingsRepository>())),
          BlocProvider(create: (context) => ClientsCubit(
            context.read<ClientRepository>(),
            context.read<InvoiceRepository>(),
            context.read<SettingsRepository>(),
          )),
          BlocProvider(create: (context) => TripsCubit(
            context.read<TripRepository>(),
            context.read<ClientRepository>(),
            context.read<DriverRepository>(),
            context.read<TruckRepository>(),
          )),
        ],
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()..initialize(null)),
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ],
          child: Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              final cairoTextTheme = GoogleFonts.cairoTextTheme();
              return MaterialApp.router(
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
                routerConfig: AppRouter.router,
              );
            },
          ),
        ),
      ),
    );
  }
}