import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/sync_service.dart';
import 'package:international_transport_app/services/advance_service.dart';

class TripRepository {
  final SupabaseClient supabase;
  final AdvanceService _advanceService = AdvanceService();

  TripRepository(this.supabase);

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  Future<List<Map<String, dynamic>>?> getCachedTripOrders() async {
    return SyncService.instance.getAllCachedRows('trip_orders');
  }

  Future<List<Map<String, dynamic>>> getTripOrders() async {
    try {
      final orders = await _advanceService.getTripOrders();
      await _cacheRows('trip_orders', orders);
      return orders;
    } catch (e) {
      debugPrint('Error fetching trip orders: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTripOrdersByClient(int clientId) async {
    try {
      return await _advanceService.getTripOrdersByClient(clientId);
    } catch (e) {
      debugPrint('Error fetching trips by client: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTripOrdersByDriver(int driverId) async {
    try {
      return await _advanceService.getTripOrdersByDriver(driverId);
    } catch (e) {
      debugPrint('Error fetching trips by driver: $e');
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> getTripOrdersStream() {
    return supabase
        .from('trip_orders')
        .stream(primaryKey: ['id'])
        .order('departure_date', ascending: false);
  }

  Future<void> addTripOrder(Map<String, dynamic> data) async {
    try {
      await _advanceService.addTripOrder(data);
    } catch (e) {
      debugPrint('Error adding trip order: $e');
      rethrow;
    }
  }

  Future<void> updateTripOrder(int id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    try {
      await _advanceService.updateTripOrder(id, data, localRow: localRow);
    } catch (e) {
      debugPrint('Error updating trip order: $e');
      rethrow;
    }
  }

  Future<void> updateTripStatus(int tripId, String status) async {
    try {
      await _advanceService.updateTripOrder(tripId, {'status': status});
    } catch (e) {
      debugPrint('Error updating trip status: $e');
      rethrow;
    }
  }

  Future<void> deleteTripOrder(int id) async {
    try {
      await _advanceService.deleteTripOrder(id);
    } catch (e) {
      debugPrint('Error deleting trip order: $e');
      rethrow;
    }
  }

  Future<void> syncPendingUpdates() async {
    final Box box;
    try {
      box = Hive.box('offline_sync_queue');
    } catch (e) {
      debugPrint('offline_sync_queue box not opened: $e');
      return;
    }
    final keys = box.keys.toList();
    for (final key in keys) {
      final entry = box.get(key);
      if (entry is! Map) continue;
      final m = Map<String, dynamic>.from(entry);
      try {
        final table = m['table']?.toString();
        final operation = m['operation']?.toString();
        final id = m['id'];
        final data = (m['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        final localRowRaw = m['localRow'];
        final localRow = localRowRaw is Map ? localRowRaw.cast<String, dynamic>() : <String, dynamic>{};

        if (operation == 'update' && table == 'trip_orders') {
          await updateTripOrder(id as int, data, localRow: localRow);
        }
        await box.delete(key);
      } catch (e) {
        debugPrint('Error syncing trip order offline queue entry $key: $e');
      }
    }
  }
}
