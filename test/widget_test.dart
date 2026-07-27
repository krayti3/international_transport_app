// Basic smoke test for the International Transport app.
//
// This verifies that the app boots without throwing and lands on the login
// screen (the default route when no user session exists), showing the basic
// login form elements.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:international_transport_app/main.dart';
import 'package:international_transport_app/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    // Initialize Hive so LocaleProvider can open its box during tests.
    Hive.init('/');

    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('plugins.flutter.io/shared_preferences');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        if (call.method == 'getAll') {
          return <String, dynamic>{};
        }
        if (call.method == 'remove') {
          return null;
        }
        if (call.method == 'clear') {
          return null;
        }
        return null;
      },
    );

    // Initialize Supabase so services that access Supabase.instance do not
    // assert during smoke tests.
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      publishableKey: 'dummy-key',
    );
  });

  testWidgets('App boots and shows the login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(),
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The app should build without throwing.
    expect(find.byType(MaterialApp), findsOneWidget);

    // Basic login form elements should be present: the shipping logo icon,
    // at least the email/password fields, and a login button.
    expect(find.byIcon(Icons.local_shipping), findsWidgets);
    expect(find.byType(TextFormField), findsWidgets);
    expect(find.byType(ElevatedButton), findsWidgets);
  });
}
