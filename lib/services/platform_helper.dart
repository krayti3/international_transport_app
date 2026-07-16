import 'dart:io';

import 'package:flutter/foundation.dart';

/// أداة مساعدة لتحديد نوع المنصة.
///
/// حزمتا google_mlkit_text_recognition و geolocator مخصصتان للهواتف فقط
/// (Android/iOS). استخدامهما على الحاسوب (Windows/Linux/macOS) أو المتصفح
/// يؤدي إلى توقف البرنامج (Crash). لذلك نعتمد على [isMobile] لحصر استدعاء
/// هذه الحزم داخل الهواتف فقط.
class PlatformHelper {
  /// هل نحن داخل المتصفح (Web).
  static bool get isWeb => kIsWeb;

  /// هل نحن داخل هاتف (Android أو iOS). هذا هو الشرط الآمن لاستخدام
  /// حزم ML Kit والـ GPS.
  static bool get isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// هل نحن داخل حاسوب مكتبي (Windows أو Linux أو macOS).
  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// رسالة يظهرها المستخدم عند محاولة استخدام ميزة غير مدعومة على الحاسوب
  /// أو المتصفح.
  static String get unsupportedFeatureMessage {
    if (kIsWeb) return 'هذه الميزة غير متاحة على المتصفح';
    return 'هذه الميزة غير متاحة على نسخة الحاسوب، يرجى التعبئة اليدوية';
  }
}
