import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'audio_service.dart';

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

  // ==================== Trip Notifications ====================

  /// Notify driver of a new trip assignment.
  Future<void> notifyTripAssigned(String driverName, String route, int tripOrderId) async {
    try {
      if (kIsWeb) return;
      await showNotification(
        'ØªØ§Ø±ÙŠØª Ø±Ø­Ù„Ø© Ø¬Ø¯ÙŠØ¯Ø©',
        'Ø£Ø±Ø³Ù„ØªÙ… Ø±Ø­Ù„Ø© Ø«Ø§Ù„ØªØ©: $route',
        tripOrderId,
      );
      await AudioService().playNotification();
    } catch (e) {
      debugPrint('Error sending trip assignment notification: $e');
    }
  }

  /// Notify driver of a departure time change.
  Future<void> notifyDepartureTimeChanged(String driverName, String route, String newTime) async {
    try {
      if (kIsWeb) return;
      await showNotification(
        'ØªØªØ¨Ø³Øª Ø§Ù„Ø§Ù†ØªØ²Ø§Ù„Ø©',
        'Ø§Ù„Ø±Ø­Ù„Ø© $route ØªÙ… Ø§Ù„Ø§Ù†ØªØ²Ø§Ù„ Ø§Ù„ØªØ§Ø±ÙŠØ®Ø§Øª Ø§Ù„Ø¥Ù†Ø°Ø§Ø²ÙŠØ© Ø«Ø§Ù„ØªØ©: $newTime',
        route.hashCode,
      );
    } catch (e) {
      debugPrint('Error sending departure time change notification: $e');
    }
  }

  /// Notify driver of a trip status change (by secretary).
  Future<void> notifyTripStatusChanged(String driverName, String route, String newStatus) async {
    try {
      if (kIsWeb) return;
      final statusLabel = _tripStatusLabel(newStatus);
      await showNotification(
        'تغير حالة الرحلة',
        'الرحلة $route للاتت تغيرت حالتها: $statusLabel',
        route.hashCode + newStatus.hashCode,
      );
      if (newStatus == 'en_route') {
        await AudioService().playTripStarted();
      } else if (newStatus == 'arrived') {
        await AudioService().playTripArrived();
      } else if (newStatus == 'completed') {
        await AudioService().playTripEnded();
      }
    } catch (e) {
      debugPrint('Error sending trip status change notification: $e');
    }
  }

  Future<void> showTripStartedNotification() async {
    try {
      if (kIsWeb) return;
      await showNotification(
        'بدء الرحلة',
        'تم بدء الرحلة الحالية بنجاح.',
        1001,
      );
      await AudioService().playTripStarted();
    } catch (e) {
      debugPrint('Error showing trip started notification: $e');
    }
  }

  Future<void> showTripArrivedNotification() async {
    try {
      if (kIsWeb) return;
      await showNotification(
        'الوصول إلى الوجهة',
        'تم الوصول إلى وجهة الرحلة الحالية.',
        1003,
      );
      await AudioService().playTripArrived();
    } catch (e) {
      debugPrint('Error showing trip arrived notification: $e');
    }
  }

  Future<void> showTripEndedNotification() async {
    try {
      if (kIsWeb) return;
      await showNotification(
        'انتهاء الرحلة',
        'تم إنهاء الرحلة الحالية بنجاح.',
        1002,
      );
      await AudioService().playTripEnded();
    } catch (e) {
      debugPrint('Error showing trip ended notification: $e');
    }
  }

  /// Notify secretary that a driver has ended a trip and settlement is needed.
  Future<void> notifySecretaryTripEnded(String driverName, String route, int tripOrderId) async {
    try {
      if (kIsWeb) return;
      await showNotification(
        'Ø§Ù†ØªÙ…Ø§Ø¡ Ø§Ù„Ø±Ø­Ù„Ø© - Ù„ØªØ³ÙˆÙŠØ© Ø§Ù„Ø¹Ù‡Ø¯Ø©',
        'Ø§Ù†ØªÙ…Ø§Ø¡ Ø§Ù„Ø³Ø§Ø¦Ù‚ $driverName Ø§Ù„Ø±Ø­Ù„Ø©: $route. ÙŠÙ„Ø²Ù… ØªØ³ÙˆÙŠØ© Ø§Ù„Ø¹Ù‡Ø¯Ø©.',
        tripOrderId,
      );
    } catch (e) {
      debugPrint('Error sending secretary trip-end notification: $e');
    }
  }

  /// Notify driver that a new cash advance has been delivered in his name.
  Future<void> notifyNewAdvanceDelivered(String driverName, double amount, int advanceId) async {
    try {
      if (kIsWeb) return;
      await showNotification(
        'Ø¹Ù‡Ø¯Ø© Ø¬Ø¯ÙŠØ¯Ø© Ù„Ø¯ÙŠÙƒ',
        'ØªÙ… ØªØ³Ù„Ù… Ø¹Ù‡Ø¯Ø© Ø¥Ø¬Ù…Ø§Ù†ÙŠØ©: ${amount.toStringAsFixed(2)} DH. Ø§Ø³ØªÙ„Ù… Ø§Ù„ØªØ³Ø¬ÙŠÙ„.',
        advanceId,
      );
    } catch (e) {
      debugPrint('Error sending advance delivery notification: $e');
    }
  }

  // ==================== Chat Notifications ====================

  /// Show a local notification for a new chat message when the app is in
  /// the background or the chat screen is not active.
  Future<void> showChatNotification({
    required String sender,
    required String message,
    String? payload,
  }) async {
    try {
      if (kIsWeb) return;
      await showNotification(
        'رسالة جديدة من $sender',
        message,
        sender.hashCode + DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
    } catch (e) {
      debugPrint('Error showing chat notification: $e');
    }
  }

  String _tripStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Ù†Ø´Ø·';
      case 'pending':
        return 'Ù‚Ø¯ Ø§Ù„Ø§Ù†ØªØ¸Ø§Ø±';
      case 'completed':
        return 'Ù…ÙƒØªÙ…Ù„';
      case 'en_route':
        return 'Ø§Ù„Ø±Ø­Ù„Ø© Ø§Ù„Ø§Ù†ØªØ²Ø§Ù„Ø©';
      case 'arrived':
        return 'Ø§Ù„Ø±Ø­Ù„Ø© Ø§Ù„ÙˆØµÙ„Øª';
      default:
        return status;
    }
  }
}
