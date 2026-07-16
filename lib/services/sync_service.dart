import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SyncService {
  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._();
  SyncService._();

  static const String _rowCacheBox = 'row_cache';
  static const String _offlineQueueBox = 'offline_sync_queue';

  Box? _rowCacheBoxRef;
  Box? _offlineQueueBoxRef;

  Future<void> init() async {
    if (!Hive.isBoxOpen(_rowCacheBox)) {
      _rowCacheBoxRef = await Hive.openBox(_rowCacheBox);
    } else {
      _rowCacheBoxRef = Hive.box(_rowCacheBox);
    }
    if (!Hive.isBoxOpen(_offlineQueueBox)) {
      _offlineQueueBoxRef = await Hive.openBox(_offlineQueueBox);
    } else {
      _offlineQueueBoxRef = Hive.box(_offlineQueueBox);
    }
  }

  Future<void> cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    final box = _rowCacheBoxRef;
    if (box == null) {
      debugPrint('SyncService: row cache box not initialized');
      return;
    }
    for (final row in rows) {
      final id = row['id'];
      if ((id is int || id is String) && row.containsKey('updated_at')) {
        final key = '$tableName:$id';
        final value = {
          'updated_at': row['updated_at'],
          'data': row,
        };
        await box.put(key, value);
      }
    }
  }

  Map<String, dynamic>? getCachedRow(String tableName, int id) {
    final box = _rowCacheBoxRef;
    if (box == null) {
      debugPrint('SyncService: row cache box not initialized');
      return null;
    }
    final key = '$tableName:$id';
    final value = box.get(key);
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Future<void> enqueueWrite({
    required String table,
    required String operation,
    required int id,
    required Map<String, dynamic> data,
    Map<String, dynamic>? localRow,
  }) async {
    final box = _offlineQueueBoxRef;
    if (box == null) {
      debugPrint('SyncService: offline queue box not initialized');
      return;
    }
    final key = box.length;
    final entry = {
      'table': table,
      'operation': operation,
      'id': id,
      'data': data,
      'localRow': localRow ?? {},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await box.put(key, entry);
  }

  Future<void> startConnectivityListener(VoidCallback onConnected) async {
    try {
      InternetConnectionChecker.createInstance()
          .onStatusChange
          .listen((InternetConnectionStatus status) {
        if (status == InternetConnectionStatus.connected) {
          onConnected();
        }
      });
    } catch (e, stackTrace) {
      debugPrint('SyncService: connectivity listener error: $e');
      debugPrint(stackTrace.toString());
    }
  }

  Future<void> clearCacheForTable(String tableName) async {
    final box = _rowCacheBoxRef;
    if (box == null) {
      debugPrint('SyncService: row cache box not initialized');
      return;
    }
    final prefix = '$tableName:';
    final keysToDelete = box.keys
        .where((key) => key is String && key.startsWith(prefix))
        .toList();
    await box.deleteAll(keysToDelete);
  }
}
