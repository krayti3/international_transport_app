import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/sync_service.dart';
import 'package:international_transport_app/services/settings_service.dart';

class SettingsRepository {
  final SupabaseClient supabase;
  final SettingsService _settingsService = SettingsService();

  SettingsRepository(this.supabase);

  Future<void> _cacheSingleRow(String tableName, Map<String, dynamic>? row) async {
    if (row == null || row['id'] == null) return;
    await SyncService.instance.cacheRows(tableName, [row]);
  }

  Future<Map<String, dynamic>?> getSystemSettings() async {
    try {
      final settings = await _settingsService.getSystemSettings();
      await _cacheSingleRow('system_settings', settings);
      return settings;
    } catch (e) {
      debugPrint('Error fetching system settings: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAppSettings() async {
    try {
      final settings = await _settingsService.getAppSettings();
      await _cacheSingleRow('app_settings', settings);
      return settings;
    } catch (e) {
      debugPrint('Error fetching app settings: $e');
      return null;
    }
  }
}
