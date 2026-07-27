import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/maintenance_schedule.dart';
import '../services/notification_service.dart';

class MaintenanceService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<MaintenanceSchedule>> getMaintenanceSchedules({
    String? vehicleType,
    int? vehicleId,
    String? status,
  }) async {
    try {
      var query = supabase.from('maintenance_schedule').select();
      if (vehicleType != null) query = query.eq('vehicle_type', vehicleType);
      if (vehicleId != null) query = query.eq('vehicle_id', vehicleId);
      if (status != null) query = query.eq('status', status);
      final response = await query
          .eq('is_deleted', false)
          .order('scheduled_date', ascending: true);
      final list = List<Map<String, dynamic>>.from(response);
      return list.map((row) => MaintenanceSchedule.fromMap(row)).toList();
    } catch (e) {
      debugPrint('Error fetching maintenance schedules: $e');
      return [];
    }
  }

  Future<List<MaintenanceSchedule>> getUpcomingMaintenances({int? daysAhead}) async {
    try {
      final now = DateTime.now();
      final until = daysAhead != null ? now.add(Duration(days: daysAhead)) : null;
      var query = supabase
          .from('maintenance_schedule')
          .select()
          .eq('is_deleted', false)
          .neq('status', 'completed')
          .gte('scheduled_date', now.toIso8601String().split('T').first);
      if (until != null) {
        query = query.lte('scheduled_date', until.toIso8601String().split('T').first);
      }
      final response = await query.order('scheduled_date', ascending: true);
      final list = List<Map<String, dynamic>>.from(response);
      return list.map((row) => MaintenanceSchedule.fromMap(row)).toList();
    } catch (e) {
      debugPrint('Error fetching upcoming maintenances: $e');
      return [];
    }
  }

  Future<MaintenanceSchedule?> getMaintenanceSchedule(int id) async {
    try {
      final response = await supabase
          .from('maintenance_schedule')
          .select()
          .eq('id', id)
          .eq('is_deleted', false)
          .maybeSingle();
      if (response == null) return null;
      return MaintenanceSchedule.fromMap(response);
    } catch (e) {
      debugPrint('Error fetching maintenance schedule: $e');
      return null;
    }
  }

  Future<MaintenanceSchedule> createMaintenanceSchedule(MaintenanceSchedule schedule) async {
    try {
      final data = schedule.toMap();
      data.remove('id');
      data.remove('created_at');
      data.remove('updated_at');
      data['notification_sent'] = false;
      final response = await supabase
          .from('maintenance_schedule')
          .insert(data)
          .select()
          .single();
      return MaintenanceSchedule.fromMap(response);
    } catch (e) {
      debugPrint('Error creating maintenance schedule: $e');
      rethrow;
    }
  }

  Future<MaintenanceSchedule> updateMaintenanceSchedule(MaintenanceSchedule schedule) async {
    try {
      final data = schedule.toMap();
      data.remove('created_at');
      final response = await supabase
          .from('maintenance_schedule')
          .update(data)
          .eq('id', schedule.id!)
          .select()
          .single();
      return MaintenanceSchedule.fromMap(response);
    } catch (e) {
      debugPrint('Error updating maintenance schedule: $e');
      rethrow;
    }
  }

  Future<void> deleteMaintenanceSchedule(int id) async {
    try {
      await supabase.from('maintenance_schedule').update({'is_deleted': true}).eq('id', id);
    } catch (e) {
      debugPrint('Error deleting maintenance schedule: $e');
      rethrow;
    }
  }

  Future<void> completeMaintenanceSchedule(int id, {double? completedKm, double? actualCost, String? notes}) async {
    try {
      final updates = <String, dynamic>{
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      };
      if (completedKm != null) updates['completed_km'] = completedKm;
      if (actualCost != null) updates['actual_cost'] = actualCost;
      if (notes != null && notes.isNotEmpty) updates['notes'] = notes;
      await supabase.from('maintenance_schedule').update(updates).eq('id', id);
    } catch (e) {
      debugPrint('Error completing maintenance schedule: $e');
      rethrow;
    }
  }

  Future<void> markOverdueMaintenances() async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      await supabase
          .from('maintenance_schedule')
          .update({'status': 'overdue'})
          .eq('is_deleted', false)
          .neq('status', 'completed')
          .neq('status', 'skipped')
          .lt('scheduled_date', today);
    } catch (e) {
      debugPrint('Error marking overdue maintenances: $e');
    }
  }

  Future<void> sendMaintenanceNotifications() async {
    try {
      final upcoming = await getUpcomingMaintenances(daysAhead: 7);
      final notificationService = NotificationService();
      for (final schedule in upcoming) {
        if (schedule.notificationSent) continue;
        final vehicleLabel = schedule.vehicleType == 'truck' ? 'شاحنة' : 'مقطورة';
        await notificationService.showNotification(
          'تذكير صيانة',
          'صيانة "${schedule.taskType}" لـ$vehicleLabel #${schedule.vehicleId} بتاريخ ${schedule.scheduledDate.toLocal().toString().split(' ').first}',
          schedule.id ?? schedule.scheduledDate.hashCode,
        );
        await supabase
            .from('maintenance_schedule')
            .update({'notification_sent': true})
            .eq('id', schedule.id!);
      }
    } catch (e) {
      debugPrint('Error sending maintenance notifications: $e');
    }
  }
}
