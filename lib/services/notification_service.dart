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
  ///
  /// استخدم [documentId] إذا كان متوفراً لضمان معرف إشعار ثابت يسمح
  /// بالإلغاء لاحقاً عند تجديد الوثيقة.
  Future<void> scheduleDocumentExpiryNotification(
    String documentName,
    DateTime expiryDate, {
    int? documentId,
  }) async {
    try {
      if (kIsWeb) return;
      final now = tz.TZDateTime.now(tz.local);
      final expiry = tz.TZDateTime.from(expiryDate, tz.local);
      final reminderDate = expiry.subtract(const Duration(days: 7));
      final scheduledDate = reminderDate.isAfter(now) ? reminderDate : expiry;
      await _scheduleNotification(
        id: documentId ?? expiryDate.hashCode,
        title: 'تنبيه انتهاء صلاحية وثيقة',
        body: 'ستنتهي صلاحية $documentName بتاريخ ${expiryDate.toLocal().toString().split(' ').first}',
        scheduledDate: scheduledDate,
        channelId: 'document_expiry_channel',
        channelName: 'انتهاء صلاحية الوثائق',
        channelDescription: 'تذكيرات بانتهاء صلاحية وثائق الشاحنة والمقطورة',
      );
    } catch (e) {
      debugPrint('Error scheduling document expiry notification: $e');
    }
  }

  /// إلغاء تذكير انتهاء صلاحية وثيقة حسب معرف الوثيقة.
  Future<void> cancelDocumentExpiryNotification(int documentId) async {
    try {
      if (kIsWeb) return;
      await _flutterLocalNotificationsPlugin.cancel(id: documentId);
    } catch (e) {
      debugPrint('Error canceling document expiry notification: $e');
    }
  }

  /// جدولة تذكير بصيانة دورية.
  Future<void> scheduleMaintenanceNotification(
    String taskType,
    DateTime scheduledDate,
    int vehicleId,
    String vehicleType,
  ) async {
    try {
      if (kIsWeb) return;
      final now = tz.TZDateTime.now(tz.local);
      final scheduled = tz.TZDateTime.from(scheduledDate, tz.local);
      final reminderDate = scheduled.subtract(const Duration(days: 2));
      final effectiveDate = reminderDate.isAfter(now) ? reminderDate : scheduled;
      final vehicleLabel = vehicleType == 'truck' ? 'شاحنة' : 'مقطورة';
      await _scheduleNotification(
        id: scheduledDate.hashCode + vehicleId,
        title: 'تذكير صيانة دورية',
        body: 'صيانة "$taskType" لـ$vehicleLabel #$vehicleId بتاريخ ${scheduledDate.toLocal().toString().split(' ').first}',
        scheduledDate: effectiveDate,
        channelId: 'maintenance_channel',
        channelName: 'الصيانة الدورية',
        channelDescription: 'تذكيرات بمواعيد الصيانة الدورية للشاحنات والمقطورات',
      );
    } catch (e) {
      debugPrint('Error scheduling maintenance notification: $e');
    }
  }

  /// جدولة تذكير بانتهاء صلاحية تأشيرة السائق.
  ///
  /// يرسل تذكير قبل انتهاء التأشيرة ب [daysBefore] يوم.
  Future<void> scheduleVisaExpiryNotification(
    String driverName,
    String visaNumber,
    DateTime expiryDate, {
    int? driverId,
    int daysBefore = 30,
  }) async {
    try {
      if (kIsWeb) return;
      final now = tz.TZDateTime.now(tz.local);
      final expiry = tz.TZDateTime.from(expiryDate, tz.local);
      final reminderDate = expiry.subtract(Duration(days: daysBefore));
      final scheduledDate = reminderDate.isAfter(now) ? reminderDate : expiry;
      final diff = expiry.difference(now).inDays;
      String urgency;
      if (diff < 0) {
        urgency = 'انتهت منذ ${diff.abs()} يوم';
      } else if (diff <= 7) {
        urgency = 'تنتهي خلال $diff يوم فقط!';
      } else if (diff <= 30) {
        urgency = 'متبقي $diff يوم';
      } else {
        urgency = 'متبقي $diff يوم';
      }
      await _scheduleNotification(
        id: driverId ?? visaNumber.hashCode + expiryDate.hashCode,
        title: 'تنبيه انتهاء تأشيرة السائق',
        body: 'تأشيرة $driverName ($visaNumber) $urgency - تاريخ الانتهاء: ${expiryDate.toLocal().toString().split(' ').first}',
        scheduledDate: scheduledDate,
        channelId: 'visa_expiry_channel',
        channelName: 'انتهاء صلاحية التأشيرات',
        channelDescription: 'تذكيرات بانتهاء صلاحية تأشيرات السائقين',
      );
    } catch (e) {
      debugPrint('Error scheduling visa expiry notification: $e');
    }
  }

  /// إلغاء تذكير انتهاء صلاحية تأشيرة السائق.
  Future<void> cancelVisaExpiryNotification(int driverId) async {
    try {
      if (kIsWeb) return;
      await _flutterLocalNotificationsPlugin.cancel(id: driverId);
    } catch (e) {
      debugPrint('Error canceling visa expiry notification: $e');
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
