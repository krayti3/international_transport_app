import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/sync_service.dart';

class CashBoxRepository {
  final SupabaseClient supabase;

  CashBoxRepository(this.supabase);

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  Future<List<Map<String, dynamic>>> getCashBoxes() async {
    try {
      final response = await supabase
          .from('cash_boxes')
          .select()
          .order('id', ascending: true);
      final boxes = List<Map<String, dynamic>>.from(response);
      await _cacheRows('cash_boxes', boxes);
      return boxes;
    } catch (e) {
      debugPrint('Error fetching cash boxes: $e');
      return [];
    }
  }
}
