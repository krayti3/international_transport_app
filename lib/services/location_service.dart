import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() => _instance;

  LocationService._internal();

  /// التحقق من صلاحيات الموقع وطلبها عند الحاجة.
  /// يُرجع false على نسخة الويندوز لأن الـ GPS غير مدعوم.
  Future<bool> _ensurePermission() async {
    if (Platform.isWindows) return false;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        final status = await Permission.location.request();
        if (!status.isGranted) return false;
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied.');
        await openAppSettings();
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error ensuring location permission: $e');
      return false;
    }
  }

  /// الحصول على الموقع الحالي للجهاز.
  /// يُرجع null على نسخة الويندوز.
  Future<Position?> getCurrentPosition() async {
    if (Platform.isWindows) return null;
    try {
      final hasPermission = await _ensurePermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }

  /// بثّ مباشر للموقع الجغرافي للمركبة لأغراض التتبع اللحظي.
  /// يُرجع بثاً فارغاً على نسخة الويندوز.
  Stream<Position> getPositionStream() {
    if (Platform.isWindows) return const Stream.empty();
    try {
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
      return Geolocator.getPositionStream(locationSettings: settings)
          .handleError((e) {
        debugPrint('Error in position stream: $e');
      });
    } catch (e) {
      debugPrint('Error creating position stream: $e');
      return const Stream.empty();
    }
  }
}