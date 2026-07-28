import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/sync_service.dart';

class DriverRepository {
  final SupabaseClient supabase;

  DriverRepository(this.supabase);

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  Future<List<Map<String, dynamic>>> getDrivers() async {
    try {
      final response = await supabase.from('drivers').select();
      final drivers = List<Map<String, dynamic>>.from(response);
      await _cacheRows('drivers', response);
      return drivers;
    } catch (e) {
      debugPrint('Error fetching drivers: $e');
      return [];
    }
  }

  Future<void> addDriver(Map<String, dynamic> data) async {
    try {
      await supabase.from('drivers').insert(data);
    } catch (e) {
      debugPrint('Error adding driver: $e');
      rethrow;
    }
  }

  Future<void> updateDriver(int id, Map<String, dynamic> data) async {
    try {
      await supabase.from('drivers').update(data).eq('id', id);
    } catch (e) {
      debugPrint('Error updating driver: $e');
      rethrow;
    }
  }

  Future<void> deleteDriver(int id) async {
    try {
      await supabase.from('drivers').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting driver: $e');
      rethrow;
    }
  }

  Future<void> updateDriverVisa(String driverId, String visaNumber, DateTime expiryDate) async {
    try {
      await supabase.from('drivers').update({
        'visa_number': visaNumber,
        'visa_expiry_date': expiryDate.toIso8601String(),
      }).eq('id', int.parse(driverId));
    } catch (e) {
      debugPrint('Error updating driver visa: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAdvancesByDriver(int driverId) async {
    try {
      final response = await supabase
          .from('advances')
          .select()
          .eq('driver_id', driverId)
          .order('date_out', ascending: false);
      final advances = List<Map<String, dynamic>>.from(response);
      await _cacheRows('advances', response);
      return advances;
    } catch (e) {
      debugPrint('Error fetching driver advances: $e');
      return [];
    }
  }
}
