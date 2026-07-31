import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/treasury_service.dart';

class TreasuryRepository {
  final SupabaseClient supabase;
  final TreasuryService _treasuryService = TreasuryService();

  TreasuryRepository(this.supabase);

  Future<List<Map<String, dynamic>>> getCashBoxes() async {
    try {
      return await _treasuryService.getCashBoxes();
    } catch (e) {
      debugPrint('Error fetching cash boxes: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<Map<int, Map<String, double>>> getCashBoxBalances() async {
    try {
      return await _treasuryService.getCashBoxBalances();
    } catch (e) {
      debugPrint('Error calculating cash box balances: $e');
      return <int, Map<String, double>>{};
    }
  }

  Future<List<Map<String, dynamic>>> getTreasuryTransactions({int? cashBoxId}) async {
    try {
      return await _treasuryService.getTreasuryTransactions(cashBoxId: cashBoxId);
    } catch (e) {
      debugPrint('Error fetching treasury transactions: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<double> getTreasuryBalance({int? cashBoxId}) async {
    try {
      return await _treasuryService.getTreasuryBalance(cashBoxId: cashBoxId);
    } catch (e) {
      debugPrint('Error calculating treasury balance: $e');
      return 0.0;
    }
  }

  Stream<List<Map<String, dynamic>>> treasuryStream() {
    return supabase
        .from('treasury_transactions')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Future<void> addTreasuryTransaction(
    double amount,
    String type,
    String description, {
    String? receiptUrl,
    int? cashBoxId,
    String currency = 'MAD',
  }) async {
    try {
      await _treasuryService.addTreasuryTransaction(
        amount,
        type,
        description,
        receiptUrl: receiptUrl,
        cashBoxId: cashBoxId,
        currency: currency,
      );
    } catch (e) {
      if (e is Exception) rethrow;
      debugPrint('Error adding treasury transaction: $e');
      rethrow;
    }
  }

  Future<void> addTransfer({
    required double amount,
    required int fromCashBoxId,
    required int toCashBoxId,
    String description = 'تحويل بين الصناديق',
    String? receiptUrl,
    String currency = 'MAD',
  }) async {
    try {
      await _treasuryService.addTransfer(
        amount: amount,
        fromCashBoxId: fromCashBoxId,
        toCashBoxId: toCashBoxId,
        description: description,
        receiptUrl: receiptUrl,
        currency: currency,
      );
    } catch (e) {
      if (e is Exception) rethrow;
      debugPrint('Error adding transfer: $e');
      rethrow;
    }
  }

  Future<bool> isOperationAllowed(int cashBoxId, String operationCode) async {
    try {
      final ops = await getAllowedOperations(cashBoxId);
      if (ops.contains('all')) return true;
      return ops.contains(operationCode);
    } catch (e) {
      debugPrint('Error checking operation permission: $e');
      return false;
    }
  }

  Future<List<String>> getAllowedOperations(int cashBoxId) async {
    try {
      final response = await supabase
          .from('cash_box_operations')
          .select('operation_code')
          .eq('cash_box_id', cashBoxId);
      final rows = List<Map<String, dynamic>>.from(response);
      return rows
          .map((r) => r['operation_code']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Error fetching allowed operations: $e');
      return <String>[];
    }
  }
}
