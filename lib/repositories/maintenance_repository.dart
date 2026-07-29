import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/sync_service.dart';
import 'package:international_transport_app/services/fleet_service.dart';

class MaintenanceRepository {
  final SupabaseClient supabase;
  final FleetService _fleetService = FleetService();

  MaintenanceRepository(this.supabase);

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  Future<List<Map<String, dynamic>>> getMaintenanceSchedules({String? status}) async {
    try {
      var query = supabase.from('maintenance_schedules').select();
      if (status != null) query = query.eq('status', status);
      final response = await query.order('scheduled_date', ascending: true);
      final schedules = List<Map<String, dynamic>>.from(response);
      await _cacheRows('maintenance_schedules', response);
      return schedules;
    } catch (e) {
      debugPrint('Error fetching maintenance schedules: $e');
      return [];
    }
  }

  Future<void> addMaintenanceSchedule(Map<String, dynamic> data) async {
    try {
      await _fleetService.insertMaintenanceSchedule(data);
    } catch (e) {
      debugPrint('Error adding maintenance schedule: $e');
      rethrow;
    }
  }

  Future<void> updateMaintenanceSchedule(int id, Map<String, dynamic> data) async {
    try {
      await _fleetService.updateMaintenanceSchedule(id, data);
    } catch (e) {
      debugPrint('Error updating maintenance schedule: $e');
      rethrow;
    }
  }

  Future<void> deleteMaintenanceSchedule(int id) async {
    try {
      await _fleetService.deleteMaintenanceSchedule(id);
    } catch (e) {
      debugPrint('Error deleting maintenance schedule: $e');
      rethrow;
    }
  }
}
