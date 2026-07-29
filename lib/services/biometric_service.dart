import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  Future<bool> authenticate({
    required String reason,
    String? title,
    String? subtitle,
  }) async {
    if (kIsWeb) return false;
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      return authenticated;
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    }
  }

  Future<String> getBiometricName() async {
    final types = await getAvailableBiometrics();
    if (types.contains(BiometricType.face)) return 'Face ID';
    if (types.contains(BiometricType.fingerprint)) return 'بصمة الإصبع';
    if (types.contains(BiometricType.iris)) return 'مسح العين';
    return 'المصادقة الحيوية';
  }

  String getBiometricIcon() {
    return 'fingerprint';
  }
}