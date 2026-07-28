import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
  CacheService._();

  static CacheService? _instance;
  static CacheService get instance => _instance ??= CacheService._();

  static const _clientsBoxName = 'cached_clients';
  static const _trucksBoxName = 'cached_trucks';
  static const _driversBoxName = 'cached_drivers';
  static const _listKey = 'list';
  static const _tsKey = 'ts';
  static const Duration _stalenessThreshold = Duration(minutes: 15);

  Box<dynamic>? _clientsBox;
  Box<dynamic>? _trucksBox;
  Box<dynamic>? _driversBox;

  Future<void> init() async {
    _clientsBox = await Hive.openBox(_clientsBoxName);
    _trucksBox = await Hive.openBox(_trucksBoxName);
    _driversBox = await Hive.openBox(_driversBoxName);
  }

  bool _isStale(Box<dynamic>? box) {
    final ts = box?.get(_tsKey);
    if (ts is! int) return true;
    return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts)) > _stalenessThreshold;
  }

  List<Map<String, dynamic>>? _readList(Box<dynamic>? box) {
    if (box == null || !box.containsKey(_listKey)) return null;
    if (_isStale(box)) return null;
    final raw = box.get(_listKey);
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    return null;
  }

  Future<void> _writeList(Box<dynamic>? box, List<Map<String, dynamic>> items) async {
    if (box == null) return;
    final payload = items.map((e) => Map<String, dynamic>.from(e)).toList();
    await box.put(_listKey, payload);
    await box.put(_tsKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> cacheClients(List<Map<String, dynamic>> clients) => _writeList(_clientsBox, clients);

  List<Map<String, dynamic>>? getCachedClients() => _readList(_clientsBox);

  bool hasFreshClients() => _clientsBox?.containsKey(_listKey) == true && !_isStale(_clientsBox);

  Future<void> cacheTrucks(List<Map<String, dynamic>> trucks) => _writeList(_trucksBox, trucks);

  List<Map<String, dynamic>>? getCachedTrucks() => _readList(_trucksBox);

  bool hasFreshTrucks() => _trucksBox?.containsKey(_listKey) == true && !_isStale(_trucksBox);

  Future<void> cacheDrivers(List<Map<String, dynamic>> drivers) => _writeList(_driversBox, drivers);

  List<Map<String, dynamic>>? getCachedDrivers() => _readList(_driversBox);

  bool hasFreshDrivers() => _driversBox?.containsKey(_listKey) == true && !_isStale(_driversBox);

  Future<void> clearClientsCache() => _clientsBox?.clear() ?? Future.value();

  Future<void> clearTrucksCache() => _trucksBox?.clear() ?? Future.value();

  Future<void> clearDriversCache() => _driversBox?.clear() ?? Future.value();

  Future<void> clearAll() async {
    await Future.wait([
      _clientsBox?.clear() ?? Future.value(),
      _trucksBox?.clear() ?? Future.value(),
      _driversBox?.clear() ?? Future.value(),
    ]);
  }
}
