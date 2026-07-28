import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/sync_service.dart';

class TripRepository {
  final SupabaseClient supabase;

  TripRepository(this.supabase);

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
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

  Future<void> deleteTripOrder(int id) async {
    try {
      await supabase.from('trip_orders').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting trip order: $e');
      rethrow;
    }
  }
}
