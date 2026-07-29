import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/models/truck.dart';
import 'package:international_transport_app/services/sync_service.dart';

class TruckRepository {
  final SupabaseClient supabase;

  TruckRepository(this.supabase);

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  Future<List<Map<String, dynamic>>?> getCachedTrucks() async {
    return SyncService.instance.getAllCachedRows('trucks');
  }

  Future<List<Truck>> getTrucks() async {
    try {
      final response = await supabase.from('trucks').select();
      final trucks = List<Map<String, dynamic>>.from(response)
          .map((e) => Truck.fromMap(e))
          .toList();
      await _cacheRows('trucks', response);
      return trucks;
    } catch (e) {
      debugPrint('Error fetching trucks: $e');
      return [];
    }
  }

  Future<void> addTruck(Map<String, dynamic> data) async {
    try {
      await supabase.from('trucks').insert(data);
    } catch (e) {
      debugPrint('Error adding truck: $e');
      rethrow;
    }
  }

  Future<void> updateTruck(int id, Map<String, dynamic> data) async {
    try {
      await supabase.from('trucks').update(data).eq('id', id);
    } catch (e) {
      debugPrint('Error updating truck: $e');
      rethrow;
    }
  }

  Future<void> deleteTruck(int id) async {
    try {
      await supabase.from('trucks').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting truck: $e');
      rethrow;
    }
  }

  Future<void> updateTruckLocation(int id, double latitude, double longitude) async {
    try {
      await supabase.from('trucks').update({
        'current_latitude': latitude,
        'current_longitude': longitude,
        'last_updated': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      debugPrint('Error updating truck location: $e');
      rethrow;
    }
  }

  Future<void> recordTruckLocation(int truckId, double latitude, double longitude) async {
    try {
      await supabase.from('truck_locations').insert({
        'truck_id': truckId,
        'latitude': latitude,
        'longitude': longitude,
        'recorded_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error recording truck location: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTruckLocationHistory(
    int truckId, {
    int hours = 24,
  }) async {
    try {
      final since = DateTime.now().subtract(Duration(hours: hours)).toIso8601String();
      final response = await supabase
          .from('truck_locations')
          .select()
          .eq('truck_id', truckId)
          .gte('recorded_at', since)
          .order('recorded_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching truck location history: $e');
      return [];
    }
  }
}
