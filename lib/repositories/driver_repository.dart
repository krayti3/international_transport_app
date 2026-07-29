import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/sync_service.dart';
import 'package:international_transport_app/services/fleet_service.dart';
import 'package:international_transport_app/services/advance_service.dart';

class DriverRepository {
  final SupabaseClient supabase;
  final FleetService _fleetService = FleetService();
  final AdvanceService _advanceService = AdvanceService();

  DriverRepository(this.supabase);

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  Future<List<Map<String, dynamic>>?> getCachedDrivers() async {
    return SyncService.instance.getAllCachedRows('drivers');
  }

  Future<List<Map<String, dynamic>>> getDrivers() async {
    try {
      final drivers = await _fleetService.getDrivers();
      await _cacheRows('drivers', drivers);
      return drivers;
    } catch (e) {
      debugPrint('Error fetching drivers: $e');
      return [];
    }
  }

  Future<void> addDriver(Map<String, dynamic> data) async {
    try {
      await _fleetService.addDriver(data);
    } catch (e) {
      debugPrint('Error adding driver: $e');
      rethrow;
    }
  }

  Future<void> updateDriver(int id, Map<String, dynamic> data) async {
    try {
      await _fleetService.updateDriver(id, data);
    } catch (e) {
      debugPrint('Error updating driver: $e');
      rethrow;
    }
  }

  Future<void> deleteDriver(int id) async {
    try {
      await _fleetService.deleteDriver(id);
    } catch (e) {
      debugPrint('Error deleting driver: $e');
      rethrow;
    }
  }

  Future<void> updateDriverVisa(String driverId, String visaNumber, DateTime expiryDate) async {
    try {
      await _fleetService.updateDriverVisa(driverId, visaNumber, expiryDate);
    } catch (e) {
      debugPrint('Error updating driver visa: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAdvancesByDriver(int driverId) async {
    try {
      final advances = await _advanceService.getAdvancesByDriver(driverId);
      await _cacheRows('advances', advances);
      return advances;
    } catch (e) {
      debugPrint('Error fetching driver advances: $e');
      return [];
    }
  }
}
