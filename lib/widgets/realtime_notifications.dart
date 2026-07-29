import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/advance_service.dart';

/// Listens to the `notifications` table over Supabase Realtime and shows each
/// new notification both as an in-app SnackBar (works on Windows & phones) and
/// as a system notification (mobile). Wrap the authenticated app root.
class RealtimeNotifications extends StatefulWidget {
  final Widget child;

  const RealtimeNotifications({super.key, required this.child});

  @override
  State<RealtimeNotifications> createState() => _RealtimeNotificationsState();
}

class _RealtimeNotificationsState extends State<RealtimeNotifications> {
  final AdvanceService _advanceService = AdvanceService();
  final FlutterLocalNotificationsPlugin _localNotifier =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  final Set<int> _seen = {};

  @override
  void initState() {
    super.initState();
    _initLocalNotifications().then((_) => _startListening());
  }

  Future<void> _initLocalNotifications() async {
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _localNotifier.initialize(settings: settings);
      await _localNotifier
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Local notifications init failed (non-fatal): $e');
    }
  }

  void _startListening() {
    _subscription = _advanceService.watchNotifications().listen(
      (rows) {
        for (final row in rows) {
          final id = row['id'];
          if (id is int && !_seen.contains(id)) {
            _seen.add(id);
            _show(row);
          }
        }
      },
      onError: (e) => debugPrint('Notifications stream error: $e'),
    );
  }

  Future<void> _show(Map<String, dynamic> row) async {
    final title = row['title']?.toString() ?? '';
    final message = row['message']?.toString() ?? '';

    // In-app popup (works on desktop and mobile while the app is open).
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title.isNotEmpty)
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (message.isNotEmpty) Text(message),
            ],
          ),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // System notification (mobile only; web/desktop use the in-app SnackBar).
    if (!kIsWeb) {
      try {
        await _localNotifier.show(
          id: row['id'] is int ? row['id'] as int : DateTime.now().millisecond,
          title: title,
          body: message,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'advances_channel',
              'العُهد والرحلات',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      } catch (e) {
        debugPrint('Local notification show failed (non-fatal): $e');
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
