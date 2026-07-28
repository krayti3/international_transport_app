import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/models/bank_account.dart';
import 'package:international_transport_app/services/sync_service.dart';

class BankAccountRepository {
  final SupabaseClient supabase;

  BankAccountRepository(this.supabase);

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  Future<void> _cacheSingleRow(String tableName, Map<String, dynamic>? row) async {
    if (row == null || row['id'] == null) return;
    await SyncService.instance.cacheRows(tableName, [row]);
  }

  String? _missingColumnFrom(String? message) {
    if (message == null) return null;
    final match = RegExp(r"Could not find the '(\w+)' column").firstMatch(message);
    return match?.group(1);
  }

  String? _notNullColumnFrom(String? message) {
    if (message == null) return null;
    final match = RegExp(r'null value in column "(\w+)"').firstMatch(message);
    return match?.group(1);
  }

  Future<void> _writeRow(
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
          final column = _missingColumnFrom(e.message);
          if (column != null && attempt.containsKey(column)) {
            debugPrint('BankAccountRepository: stripping unknown column "$column" (PGRST204)');
            attempt.remove(column);
            continue;
          }
        } else if (e.code == '23502') {
          final column = _notNullColumnFrom(e.message);
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

  Future<List<BankAccount>> getBankAccounts() async {
    try {
      final response = await supabase.from('bank_accounts').select();
      final bankAccounts = List<Map<String, dynamic>>.from(response).map((e) => BankAccount.fromMap(e)).toList();
      await _cacheRows('bank_accounts', response);
      return bankAccounts;
    } catch (e) {
      debugPrint('Error fetching bank accounts: $e');
      return [];
    }
  }

  Future<BankAccount?> getBankAccountById(String id) async {
    try {
      final response = await supabase
          .from('bank_accounts')
          .select()
          .eq('id', id)
          .maybeSingle();
      await _cacheSingleRow('bank_accounts', response);
      return response != null ? BankAccount.fromMap(response) : null;
    } catch (e) {
      debugPrint('Error fetching bank account: $e');
      return null;
    }
  }

  Future<void> addBankAccount(Map<String, dynamic> data) async {
    await _writeRow((d) => supabase.from('bank_accounts').insert(d), data);
  }

  Future<void> updateBankAccount(String id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    if (localRow == null) {
      await _writeRow(
        (d) => supabase.from('bank_accounts').update(d).eq('id', id),
        data,
      );
      return;
    }
    final localStamp = DateTime.tryParse(localRow['updated_at']?.toString() ?? '')?.millisecondsSinceEpoch;
    if (localStamp == null) {
      await _writeRow(
        (d) => supabase.from('bank_accounts').update(d).eq('id', id),
        data,
      );
      return;
    }
    final server = await supabase
        .from('bank_accounts')
        .select('updated_at')
        .eq('id', id)
        .maybeSingle();
    final serverStamp = DateTime.tryParse(server?['updated_at']?.toString() ?? '')?.millisecondsSinceEpoch;
    if (serverStamp != null && serverStamp > localStamp) {
      return;
    }
    await _writeRow(
      (d) => supabase.from('bank_accounts').update(d).eq('id', id),
      data,
    );
  }

  Future<void> deleteBankAccount(String id) async {
    try {
      await supabase.from('bank_accounts').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting bank account: $e');
      rethrow;
    }
  }
}
