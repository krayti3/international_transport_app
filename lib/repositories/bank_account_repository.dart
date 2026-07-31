import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/models/bank_account.dart';
import 'package:international_transport_app/services/sync_service.dart';
import 'package:international_transport_app/services/client_service.dart';

class BankAccountRepository {
  final SupabaseClient supabase;
  final ClientService _clientService = ClientService();

  BankAccountRepository(this.supabase);

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  Future<List<BankAccount>> getBankAccounts() async {
    try {
      final bankAccounts = await _clientService.getBankAccounts();
      await _cacheRows('bank_accounts', bankAccounts.map((e) => e.toMap()).toList());
      return bankAccounts;
    } catch (e) {
      debugPrint('Error fetching bank accounts: $e');
      return [];
    }
  }

  Future<BankAccount?> getBankAccountById(String id) async {
    try {
      return await _clientService.getBankAccountById(id);
    } catch (e) {
      debugPrint('Error fetching bank account: $e');
      return null;
    }
  }

  Future<void> addBankAccount(Map<String, dynamic> data) async {
    try {
      await _clientService.addBankAccount(data);
    } catch (e) {
      debugPrint('Error adding bank account: $e');
      rethrow;
    }
  }

  Future<void> updateBankAccount(String id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    try {
      await _clientService.updateBankAccount(id, data, localRow: localRow);
    } catch (e) {
      debugPrint('Error updating bank account: $e');
      rethrow;
    }
  }

  Future<void> deleteBankAccount(String id) async {
    try {
      await _clientService.deleteBankAccount(id);
    } catch (e) {
      debugPrint('Error deleting bank account: $e');
      rethrow;
    }
  }
}
