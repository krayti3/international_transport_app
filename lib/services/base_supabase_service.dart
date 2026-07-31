import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/sync_service.dart';

class BaseSupabaseService {
  final SupabaseClient supabase = Supabase.instance.client;

  static int? parseUpdatedAt(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return null;
    return dt.millisecondsSinceEpoch;
  }

  Future<bool> updateWithLww(
    Future<void> Function() updateOp,
    String tableName,
    Map<String, dynamic> localRow,
  ) async {
    final localStamp = parseUpdatedAt(localRow['updated_at']?.toString());
    if (localStamp == null) {
      await updateOp();
      return true;
    }
    final id = localRow['id'];
    if (id == null) return false;
    final server = await supabase
        .from(tableName)
        .select('updated_at')
        .eq('id', id)
        .maybeSingle();
    final serverStamp = parseUpdatedAt(server?['updated_at']?.toString());
    if (serverStamp != null && serverStamp > localStamp) {
      return false;
    }
    await updateOp();
    return true;
  }

  Future<void> cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  Future<void> cacheSingleRow(String tableName, Map<String, dynamic>? row) async {
    if (row == null || row['id'] == null) return;
    await SyncService.instance.cacheRows(tableName, [row]);
  }

  String? missingColumnFrom(String? message) {
    if (message == null) return null;
    final match = RegExp(r"Could not find the '(\w+)' column").firstMatch(message);
    return match?.group(1);
  }

  String? notNullColumnFrom(String? message) {
    if (message == null) return null;
    final match = RegExp(r'null value in column "(\w+)"').firstMatch(message);
    return match?.group(1);
  }

  Future<void> writeRow(
    Future<void> Function(Map<String, dynamic>) op,
    Map<String, dynamic> data,
  ) async {
    var attempt = Map<String, dynamic>.from(data);
    String? lastFilledColumn;
    for (var i = 0; i < 10; i++) {
      try {
        await op(attempt);
        return;
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST204') {
          final column = missingColumnFrom(e.message);
          if (column != null && attempt.containsKey(column)) {
            debugPrint('$runtimeType: stripping unknown column "$column" from update (PGRST204)');
            attempt.remove(column);
            continue;
          }
        } else if (e.code == '23502') {
          final column = notNullColumnFrom(e.message);
          if (column != null) {
            attempt[column] = '';
            lastFilledColumn = column;
            continue;
          }
        } else if (e.code == '22P02') {
          if (lastFilledColumn != null) {
            attempt[lastFilledColumn] = 0;
            continue;
          }
        }
        rethrow;
      }
    }
    throw Exception('تعذّر الحفظ بسبب اختلاف في مخطط قاعدة البيانات');
  }
}
