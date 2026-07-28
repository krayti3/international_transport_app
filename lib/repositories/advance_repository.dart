import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/sync_service.dart';

class AdvanceRepository {
  final SupabaseClient supabase;

  AdvanceRepository(this.supabase);

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  Future<List<Map<String, dynamic>>> getAdvances() async {
    try {
      final response = await supabase
          .from('advances')
          .select()
          .or('is_deleted.is.null,is_deleted.eq.false')
          .order('date_out', ascending: false);
      final advances = List<Map<String, dynamic>>.from(response);
      await _cacheRows('advances', response);
      return advances;
    } catch (e) {
      debugPrint('Error fetching advances: $e');
      return [];
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

  Future<void> addAdvance(Map<String, dynamic> data) async {
    try {
      await supabase.from('advances').insert(data);
    } catch (e) {
      debugPrint('Error adding advance: $e');
      rethrow;
    }
  }

  Future<void> updateAdvance(int id, Map<String, dynamic> data) async {
    try {
      await supabase.from('advances').update(data).eq('id', id);
    } catch (e) {
      debugPrint('Error updating advance: $e');
      rethrow;
    }
  }

  Future<void> deleteAdvance(int id) async {
    try {
      await supabase.from('advances').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting advance: $e');
      rethrow;
    }
  }
}
