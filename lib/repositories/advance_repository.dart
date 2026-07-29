import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/sync_service.dart';
import 'package:international_transport_app/services/advance_service.dart';

class AdvanceRepository {
  final SupabaseClient supabase;
  final AdvanceService _advanceService = AdvanceService();

  AdvanceRepository(this.supabase);

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  Future<List<Map<String, dynamic>>> getAdvances() async {
    try {
      final advances = await _advanceService.getAdvances();
      await _cacheRows('advances', advances);
      return advances;
    } catch (e) {
      debugPrint('Error fetching advances: $e');
      return [];
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

  Future<void> addAdvance(Map<String, dynamic> data) async {
    try {
      await _advanceService.addAdvance(data);
    } catch (e) {
      debugPrint('Error adding advance: $e');
      rethrow;
    }
  }

  Future<void> updateAdvance(int id, Map<String, dynamic> data) async {
    try {
      await _advanceService.updateAdvance(id, data);
    } catch (e) {
      debugPrint('Error updating advance: $e');
      rethrow;
    }
  }

  Future<void> deleteAdvance(int id) async {
    try {
      await _advanceService.deleteAdvance(id);
    } catch (e) {
      debugPrint('Error deleting advance: $e');
      rethrow;
    }
  }
}
