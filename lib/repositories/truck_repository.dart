import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/models/truck.dart';
import 'package:international_transport_app/services/sync_service.dart';
import 'package:international_transport_app/services/fleet_service.dart';

class TruckRepository {
  final SupabaseClient supabase;
  final FleetService _fleetService = FleetService();

  TruckRepository(this.supabase);

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  Future<List<Map<String, dynamic>>?> getCachedTrucks() async {
    return SyncService.instance.getAllCachedRows('trucks');
  }

  Future<List<Truck>> getTrucks() async {
    try {
      final trucks = await _fleetService.getTrucks();
      await _cacheRows('trucks', trucks);
      return trucks.map((e) => Truck.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error fetching trucks: $e');
      return [];
    }
  }

  Future<void> addTruck(Map<String, dynamic> data) async {
    try {
      await _fleetService.addTruck(data);
    } catch (e) {
      debugPrint('Error adding truck: $e');
      rethrow;
    }
  }

  Future<void> updateTruck(int id, Map<String, dynamic> data) async {
    try {
      await _fleetService.updateTruck(id, data);
    } catch (e) {
      debugPrint('Error updating truck: $e');
      rethrow;
    }
  }

  Future<void> deleteTruck(int id) async {
    try {
      await _fleetService.deleteTruck(id);
    } catch (e) {
      debugPrint('Error deleting truck: $e');
      rethrow;
    }
  }

  Future<void> updateTruckLocation(int id, double latitude, double longitude) async {
    try {
      await _fleetService.updateTruckLocation(id, latitude, longitude);
    } catch (e) {
      debugPrint('Error updating truck location: $e');
      rethrow;
    }
  }

  Future<void> recordTruckLocation(int truckId, double latitude, double longitude) async {
    try {
      await _fleetService.recordTruckLocation(truckId, latitude, longitude);
    } catch (e) {
      debugPrint('Error recording truck location: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTruckLocationHistory(
    int truckId, {
    int hours = 24,
  }) async {
    try {
      return await _fleetService.getTruckLocationHistory(truckId, hours: hours);
    } catch (e) {
      debugPrint('Error fetching truck location history: $e');
      return [];
    }
  }
}
