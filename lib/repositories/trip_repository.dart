import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/models/pending_update.dart';
import 'package:international_transport_app/services/sync_service.dart';

class TripRepository {
  final SupabaseClient supabase;
  final Box _pendingBox = Hive.box('pending_updates');

  TripRepository(this.supabase);

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  Future<List<Map<String, dynamic>>?> getCachedTripOrders() async {
    return SyncService.instance.getAllCachedRows('trip_orders');
  }

  Future<List<Map<String, dynamic>>> getTripOrders() async {
    try {
      final response = await supabase.from('trip_orders').select();
      final orders = List<Map<String, dynamic>>.from(response);
      await _cacheRows('trip_orders', response);
      return orders;
    } catch (e) {
      debugPrint('Error fetching trip orders: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTripOrdersByClient(int clientId) async {
    try {
      final response = await supabase
          .from('trip_orders')
          .select()
          .eq('client_id', clientId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching trips by client: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTripOrdersByDriver(int driverId) async {
    try {
      final response = await supabase
          .from('trip_orders')
          .select()
          .eq('driver_id', driverId);
      return List<Map<String, dynamic>>.from(response);
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
      await supabase.from('trip_orders').insert(data);
    } catch (e) {
      debugPrint('Error adding trip order: $e');
      rethrow;
    }
  }

  Future<void> updateTripOrder(int id, Map<String, dynamic> data) async {
    try {
      await supabase.from('trip_orders').update(data).eq('id', id);
    } catch (e) {
      debugPrint('Error updating trip order: $e');
      rethrow;
    }
  }

  /// Updates only the status column of a trip order.
  /// On failure, the update is queued offline in a dedicated Hive box
  /// for automatic sync when connectivity is restored.
  Future<void> updateTripStatus(int id, String status) async {
    try {
      await supabase.from('trip_orders').update({'status': status}).eq('id', id);
      await _removePendingUpdate(id);
      debugPrint('✅ تم التحديث عبر الإنترنت');
    } catch (e) {
      debugPrint('Error updating trip status: $e');
      await _savePendingUpdate(id, status);
      throw Exception('لا يوجد اتصال بالإنترنت. سيتم المزامنة تلقائياً عند عودة الاتصال.');
    }
  }

  Future<void> _savePendingUpdate(int tripId, String status) async {
    final pending = PendingStatusUpdate(
      tripId: tripId,
      status: status,
      timestamp: DateTime.now(),
    );
    await _pendingBox.put(tripId.toString(), pending.toMap());
  }

  Future<void> _removePendingUpdate(int tripId) async {
    await _pendingBox.delete(tripId.toString());
  }

  List<PendingStatusUpdate> getPendingUpdates() {
    final List<PendingStatusUpdate> updates = [];
    for (var key in _pendingBox.keys) {
      final data = _pendingBox.get(key);
      if (data != null) {
        updates.add(PendingStatusUpdate.fromMap(Map<String, dynamic>.from(data)));
      }
    }
    return updates;
  }

  Future<void> syncPendingUpdates() async {
    final pendingUpdates = getPendingUpdates();
    if (pendingUpdates.isEmpty) return;

    debugPrint('🔄 جاري مزامنة ${pendingUpdates.length} تحديث معلق...');

    for (final update in pendingUpdates) {
      try {
        await supabase
            .from('trip_orders')
            .update({'status': update.status})
            .eq('id', update.tripId);
        await _removePendingUpdate(update.tripId);
        debugPrint('✅ تمت مزامنة الرحلة ${update.tripId}');
      } catch (e) {
        debugPrint('❌ فشلت مزامنة الرحلة ${update.tripId}: $e');
      }
    }
  }

  Future<void> deleteTripOrder(int id) async {
    try {
      await supabase.from('trip_orders').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting trip order: $e');
      rethrow;
    }
  }
}
