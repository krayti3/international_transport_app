import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/sync_service.dart';

class MaintenanceRepository {
  final SupabaseClient supabase;

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
      await supabase.from('maintenance_schedules').insert(data);
    } catch (e) {
      debugPrint('Error adding maintenance schedule: $e');
      rethrow;
    }
  }

  Future<void> updateMaintenanceSchedule(int id, Map<String, dynamic> data) async {
    try {
      await supabase.from('maintenance_schedules').update(data).eq('id', id);
    } catch (e) {
      debugPrint('Error updating maintenance schedule: $e');
      rethrow;
    }
  }

  Future<void> deleteMaintenanceSchedule(int id) async {
    try {
      await supabase.from('maintenance_schedules').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting maintenance schedule: $e');
      rethrow;
    }
  }
}
