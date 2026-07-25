import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// تهيئة خدمة الإشعارات المحلية والمناطق الزمنية.
  Future<void> initialize() async {
    try {
      tz.initializeTimeZones();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _flutterLocalNotificationsPlugin.initialize(settings: initSettings);
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  /// عرض إشعار محلي فوري.
  Future<void> showNotification(String title, String body, int id) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'default_channel',
        'الإشعارات الافتراضية',
        channelDescription: 'قناة الإشعارات العامة للتطبيق',
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  /// جدولة تذكير بانتهاء صلاحية وثيقة الشاحنة أو المقطورة.
  Future<void> scheduleDocumentExpiryNotification(
    String documentName,
    DateTime expiryDate,
  ) async {
    try {
      if (kIsWeb) return; // zonedSchedule not supported on web
      final now = tz.TZDateTime.now(tz.local);
      final expiry = tz.TZDateTime.from(expiryDate, tz.local);

      // تذكير قبل 7 أيام من تاريخ الانتهاء إن أمكن.
      final reminderDate = expiry.subtract(const Duration(days: 7));
      final scheduledDate = reminderDate.isAfter(now) ? reminderDate : expiry;

      const androidDetails = AndroidNotificationDetails(
        'document_expiry_channel',
        'انتهاء صلاحية الوثائق',
        channelDescription: 'تذكيرات بانتهاء صلاحية وثائق الشاحنة والمقطورة',
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id: expiryDate.hashCode,
        title: 'تنبيه انتهاء صلاحية وثيقة',
        body: 'ستنتهي صلاحية $documentName بتاريخ ${expiryDate.toLocal().toString().split(' ').first}',
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Error scheduling document expiry notification: $e');
    }
  }
}
