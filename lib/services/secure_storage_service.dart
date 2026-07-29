import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _credentialsKey = 'user_credentials';
  static const String _biometricEnabledKey = 'biometric_enabled';

  Future<void> saveCredentials(String email, String password) async {
    final data = jsonEncode({'email': email, 'password': password});
    await _storage.write(key: _credentialsKey, value: data);
  }

  Future<Map<String, String>?> getCredentials() async {
    final data = await _storage.read(key: _credentialsKey);
    if (data == null) return null;
    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      return {
        'email': map['email']?.toString() ?? '',
        'password': map['password']?.toString() ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _credentialsKey);
  }

  Future<void> saveBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }
}