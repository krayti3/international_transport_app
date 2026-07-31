import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();

  static const String _soundTripStarted = 'trip_started.mp3';
  static const String _soundTripEnded = 'trip_ended.mp3';
  static const String _soundTripArrived = 'trip_arrived.mp3';
  static const String _soundNotification = 'notification.mp3';

  Future<void> playTripStarted() async {
    await _playSound(_soundTripStarted);
  }

  Future<void> playTripEnded() async {
    await _playSound(_soundTripEnded);
  }

  Future<void> playTripArrived() async {
    await _playSound(_soundTripArrived);
  }

  Future<void> playNotification() async {
    await _playSound(_soundNotification);
  }

  Future<void> _playSound(String fileName) async {
    if (kIsWeb) return;
    try {
      final source = AssetSource('sounds/$fileName');
      await _player.play(source);
    } catch (e) {
      debugPrint('AudioService: Error playing sound $fileName: $e');
    }
  }

  Future<void> stopAll() async {
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}
