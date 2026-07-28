import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/sync_service.dart';

class SettingsRepository {
  final SupabaseClient supabase;

  SettingsRepository(this.supabase);

  Future<void> _cacheSingleRow(String tableName, Map<String, dynamic>? row) async {
    if (row == null || row['id'] == null) return;
    await SyncService.instance.cacheRows(tableName, [row]);
  }

  Future<Map<String, dynamic>?> getSystemSettings() async {
    try {
      final response = await supabase
          .from('system_settings')
          .select()
          .eq('id', 1)
          .maybeSingle();
      await _cacheSingleRow('system_settings', response);
      return response;
    } catch (e) {
      debugPrint('Error fetching system settings: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAppSettings() async {
    try {
      final response = await supabase
          .from('app_settings')
          .select()
          .eq('id', 1)
          .maybeSingle();
      await _cacheSingleRow('app_settings', response);
      return response;
    } catch (e) {
      debugPrint('Error fetching app settings: $e');
      return null;
    }
  }
}
