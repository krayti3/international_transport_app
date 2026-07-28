import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TreasuryRepository {
  final SupabaseClient supabase;

  TreasuryRepository(this.supabase);

  static const _treasuryIncomeTypes = <String>{
    'capital_injection',
    'trip_revenue',
  };

  String _normalizeTreasuryType(Map<String, dynamic> transaction) {
    return transaction['type']?.toString() ??
        transaction['category']?.toString() ??
        transaction['transaction_type']?.toString() ??
        '';
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
          final match = RegExp(r"Could not find the '(\w+)' column").firstMatch(e.message);
          final column = match?.group(1);
          if (column != null && attempt.containsKey(column)) {
            debugPrint('TreasuryRepository: stripping unknown column "$column" from update (PGRST204)');
            attempt.remove(column);
            continue;
          }
        } else if (e.code == '23502') {
          final match = RegExp(r'null value in column "(\w+)"').firstMatch(e.message);
          final column = match?.group(1);
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

  Future<void> _requireAdmin() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('يرجى تسجيل الدخول أولًا');
    }
    try {
      final response = await supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final role = response?['role']?.toString();
      if (role != 'admin') {
        throw Exception('ليس لديك صلاحية للوصول إلى هذا القسم. يرجى الاتصال بالمسؤول.');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('فشل التحقق من الصلاحيات');
    }
  }

  Future<void> _ensureOperationAllowed(int cashBoxId, String operationCode) async {
    final allowed = await isOperationAllowed(cashBoxId, operationCode);
    if (!allowed) {
      throw Exception('هذه العملية غير مسموحة لهذا الصندوق');
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

  Future<List<Map<String, dynamic>>> getCashBoxes() async {
    try {
      final response = await supabase
          .from('cash_boxes')
          .select()
          .order('id', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching cash boxes: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<Map<int, Map<String, double>>> getCashBoxBalances() async {
    try {
      final response = await supabase
          .from('treasury_transactions')
          .select('amount, type, currency, cash_box_id, related_cash_box_id');
      final transactions = List<Map<String, dynamic>>.from(response);
      final Map<int, Map<String, double>> balances = {};

      for (final tx in transactions) {
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final type = _normalizeTreasuryType(tx);
        final currency = (tx['currency']?.toString() ?? 'MAD');
        final cashBoxId = tx['cash_box_id'] as int?;
        final relatedId = tx['related_cash_box_id'] as int?;
        if (cashBoxId == null) continue;

        final boxCurrencies = balances.putIfAbsent(cashBoxId, () => {'MAD': 0.0, 'EUR': 0.0});
        if (type == 'transfer') {
          boxCurrencies[currency] = (boxCurrencies[currency] ?? 0.0) - amount;
          if (relatedId != null) {
            final relatedCurrencies = balances.putIfAbsent(relatedId, () => {'MAD': 0.0, 'EUR': 0.0});
            relatedCurrencies[currency] = (relatedCurrencies[currency] ?? 0.0) + amount;
          }
        } else if (_treasuryIncomeTypes.contains(type)) {
          boxCurrencies[currency] = (boxCurrencies[currency] ?? 0.0) + amount;
        } else {
          boxCurrencies[currency] = (boxCurrencies[currency] ?? 0.0) - amount;
        }
      }

      return balances;
    } catch (e) {
      debugPrint('Error calculating cash box balances: $e');
      return <int, Map<String, double>>{};
    }
  }

  Future<List<Map<String, dynamic>>> getTreasuryTransactions({int? cashBoxId}) async {
    try {
      final List<Map<String, dynamic>> transactions;
      if (cashBoxId != null) {
        final response = await supabase
            .from('treasury_transactions')
            .select()
            .or('cash_box_id.eq.$cashBoxId,related_cash_box_id.eq.$cashBoxId')
            .order('created_at', ascending: false);
        transactions = List<Map<String, dynamic>>.from(response);
      } else {
        final response = await supabase
            .from('treasury_transactions')
            .select()
            .order('created_at', ascending: false);
        transactions = List<Map<String, dynamic>>.from(response);
      }
      for (final transaction in transactions) {
        transaction['type'] = _normalizeTreasuryType(transaction);
      }
      return transactions;
    } catch (e) {
      debugPrint('Error fetching treasury transactions: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<double> getTreasuryBalance({int? cashBoxId}) async {
    try {
      final transactions = await getTreasuryTransactions(cashBoxId: cashBoxId);
      double balance = 0.0;

      for (final transaction in transactions) {
        final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
        final type = _normalizeTreasuryType(transaction);
        final txCashBoxId = transaction['cash_box_id'] as int?;
        final relatedCashBoxId = transaction['related_cash_box_id'] as int?;

        if (cashBoxId == null) {
          switch (type) {
            case 'capital_injection':
            case 'trip_revenue':
              balance += amount;
              break;
            case 'owner_withdrawal':
            case 'office_expense':
            case 'salary':
            case 'trip_expense':
              balance -= amount;
              break;
            default:
              break;
          }
        } else {
          if (txCashBoxId == cashBoxId) {
            if (type == 'capital_injection' ||
                type == 'trip_revenue' ||
                type == 'transfer') {
              balance += amount;
            } else {
              balance -= amount;
            }
          } else if (relatedCashBoxId == cashBoxId) {
            if (type == 'transfer') {
              balance += amount;
            }
          }
        }
      }

      return balance;
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
      await _requireAdmin();
      if (cashBoxId != null) {
        final operationCode =
            _treasuryIncomeTypes.contains(type) ? 'income' : 'expense';
        await _ensureOperationAllowed(cashBoxId, operationCode);
      }
      await _writeRow(
        (d) => supabase.from('treasury_transactions').insert(d),
        {
          'amount': amount,
          'type': type,
          if (description.trim().isNotEmpty) 'description': description,
          if (receiptUrl != null) 'receipt_url': receiptUrl,
          if (cashBoxId != null) 'cash_box_id': cashBoxId,
          'currency': currency,
        },
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
      await _requireAdmin();
      await _ensureOperationAllowed(fromCashBoxId, 'transfer');
      await _ensureOperationAllowed(toCashBoxId, 'transfer');
      await _writeRow(
        (d) => supabase.from('treasury_transactions').insert(d),
        {
          'amount': amount,
          'type': 'transfer',
          'description': description,
          'cash_box_id': fromCashBoxId,
          'related_cash_box_id': toCashBoxId,
          if (receiptUrl != null) 'receipt_url': receiptUrl,
          'currency': currency,
        },
      );
    } catch (e) {
      if (e is Exception) rethrow;
      debugPrint('Error adding transfer: $e');
      rethrow;
    }
  }
}
