import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/sync_service.dart';
import 'package:international_transport_app/services/treasury_service.dart';

class CashBoxRepository {
  final SupabaseClient supabase;
  final TreasuryService _treasuryService = TreasuryService();

  CashBoxRepository(this.supabase);

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  Future<List<Map<String, dynamic>>> getCashBoxes() async {
    try {
      final boxes = await _treasuryService.getCashBoxes();
      await _cacheRows('cash_boxes', boxes);
      return boxes;
    } catch (e) {
      debugPrint('Error fetching cash boxes: $e');
      return [];
    }
  }
}
