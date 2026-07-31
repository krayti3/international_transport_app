import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:decimal/decimal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/base_supabase_service.dart';

class TreasuryService extends BaseSupabaseService {

  String? _currentRole;

  Future<void> _loadUserRole() async {
    _currentRole = await getUserRole();
  }

  Future<void> _requireAdmin() async {
    if (_currentRole == null) {
      await _loadUserRole();
    }
    if (_currentRole != 'admin') {
      throw Exception('ليس لديك صلاحية للوصول إلى هذا القسم. يرجى الاتصال بالمسؤول.');
    }
  }

  Future<String?> getUserRole() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;
      final response = await supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      return response?['role']?.toString();
    } catch (e) {
      debugPrint('Error fetching user role: $e');
      return null;
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
      await cacheRows('treasury_transactions', transactions);
      return transactions;
    } catch (e) {
      debugPrint('Error fetching treasury transactions: $e');
      return [];
    }
  }

  String _normalizeTreasuryType(Map<String, dynamic> transaction) {
    return transaction['type']?.toString() ??
        transaction['category']?.toString() ??
        transaction['transaction_type']?.toString() ??
        '';
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
      await writeRow(
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

  Future<void> recordMaintenanceTreasuryTransaction({
    required double amount,
    required String paymentStatus,
    required String currency,
    required String description,
    int? maintenanceId,
  }) async {
    try {
      if (paymentStatus == 'on_credit') return;

      final cashBoxCode = paymentStatus == 'paid_by_owner'
          ? 'owner_cash'
          : paymentStatus;
      final cashBoxId = await getCashBoxIdByCode(cashBoxCode);
      if (cashBoxId == null) return;

      final maintenanceLabel = maintenanceId != null
          ? 'مصروف صيانة (#$maintenanceId)'
          : 'مصروف صيانة';
      await supabase.from('treasury_transactions').insert({
        'amount': amount,
        'type': 'office_expense',
        'description': '$maintenanceLabel - $description',
        'cash_box_id': cashBoxId,
        'currency': currency,
      });
    } catch (e) {
      debugPrint('Error recording maintenance treasury transaction: $e');
    }
  }

  Future<double> getTreasuryBalance({int? cashBoxId}) async {
    try {
      final List<Map<String, dynamic>> transactions;
      if (cashBoxId != null) {
        final response = await supabase
            .from('treasury_transactions')
            .select()
            .or('cash_box_id.eq.$cashBoxId,related_cash_box_id.eq.$cashBoxId');
        transactions = List<Map<String, dynamic>>.from(response);
      } else {
        final response = await supabase.from('treasury_transactions').select();
        transactions = List<Map<String, dynamic>>.from(response);
      }

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

  Future<List<Map<String, dynamic>>> getUnifiedLedger({
    String role = 'secretary',
    String period = 'all',
    String? searchQuery,
    int? cashBoxId,
  }) async {
    try {
      final List<Map<String, dynamic>> unified = [];

      final treasury = cashBoxId != null
          ? await getTreasuryTransactions(cashBoxId: cashBoxId)
          : await getTreasuryTransactions();
      for (final t in treasury) {
        final amount = (t['amount'] is Decimal ? (t['amount'] as Decimal).toDouble() : (t['amount'] as num?)?.toDouble()) ?? 0.0;
        final type = t['type']?.toString() ?? '';
        if (type == 'transfer') {
          final relatedId = t['related_cash_box_id'] as int?;
          final currency = (t['currency']?.toString() ?? 'DH');
          if (cashBoxId != null && relatedId == cashBoxId) {
            unified.add({
              'date': t['created_at'] ?? '',
              'description': t['description'] ?? 'تحويل',
              'beneficiary': '-',
              'currency': currency,
              'amount_entree': amount,
              'amount_sortie': 0.0,
              'type': 'treasury',
              'raw_type': type,
              'is_archived': false,
            });
          } else if (cashBoxId == null || t['cash_box_id'] == cashBoxId) {
            unified.add({
              'date': t['created_at'] ?? '',
              'description': t['description'] ?? 'تحويل',
              'beneficiary': '-',
              'currency': currency,
              'amount_entree': 0.0,
              'amount_sortie': amount,
              'type': 'treasury',
              'raw_type': type,
              'is_archived': false,
            });
          }
        } else {
          final isRevenue = type == 'trip_revenue' || type == 'capital_injection';
          final currency = (t['currency']?.toString() ?? 'DH');
          unified.add({
            'date': t['created_at'] ?? '',
            'description': t['description'] ?? 'معاملة خزينة',
            'beneficiary': '-',
            'currency': currency,
            'amount_entree': isRevenue ? amount : 0.0,
            'amount_sortie': isRevenue ? 0.0 : amount,
            'type': 'treasury',
            'raw_type': type,
            'is_archived': false,
          });
        }
      }

      final advances = role == 'admin' ? await getAllAdvances() : await getAdvances();
      for (final a in advances) {
        final driverId = a['driver_id'] as int?;
        final driverName = driverId != null ? await _driverNameById(driverId) : 'بدون سائق';
        final given = (a['amount_given'] is Decimal ? (a['amount_given'] as Decimal).toDouble() : (a['amount_given'] as num?)?.toDouble()) ?? 0.0;
        final spent = (a['amount_spent'] is Decimal ? (a['amount_spent'] as Decimal).toDouble() : (a['amount_spent'] as num?)?.toDouble());
        final returned = (a['amount_returned'] is Decimal ? (a['amount_returned'] as Decimal).toDouble() : (a['amount_returned'] as num?)?.toDouble());
        final currency = (a['currency']?.toString() ?? 'DH');
        final isDeleted = a['is_deleted'] == true;

        unified.add({
          'date': a['date_out'] ?? '',
          'description': 'تسليم عهدة للسائق',
          'beneficiary': driverName,
          'currency': currency,
          'amount_entree': 0.0,
          'amount_sortie': given,
          'type': 'advance_given',
          'is_archived': isDeleted,
        });

        if (a['status']?.toString() == 'settled' && spent != null && spent > 0) {
          unified.add({
            'date': a['date_return'] ?? a['date_out'] ?? '',
            'description': 'تسوية عهدة (صرفيات الرحلة)',
            'beneficiary': driverName,
            'currency': currency,
            'amount_entree': 0.0,
            'amount_sortie': spent,
            'type': 'advance_spent',
            'is_archived': isDeleted,
          });
        }

        if (returned != null && returned > 0) {
          unified.add({
            'date': a['date_return'] ?? a['date_out'] ?? '',
            'description': 'مرجوع عهدة من السائق',
            'beneficiary': driverName,
            'currency': currency,
            'amount_entree': returned,
            'amount_sortie': 0.0,
            'type': 'advance_returned',
            'is_archived': isDeleted,
          });
        }
      }

      final invoices = await getInvoices();
      for (final inv in invoices) {
        final clientName = inv['client']?['name']?.toString() ?? 'زبون';
        final total = (inv['total_amount'] is Decimal ? (inv['total_amount'] as Decimal).toDouble() : (inv['total_amount'] as num?)?.toDouble()) ?? 0.0;
        final currency = (inv['currency']?.toString() ?? 'DH');
        unified.add({
          'date': inv['issue_date'] ?? '',
          'description': 'فاتورة: ${inv['invoice_number'] ?? ''}',
          'beneficiary': clientName,
          'currency': currency,
          'amount_entree': total,
          'amount_sortie': 0.0,
          'type': 'invoice',
          'is_archived': false,
        });
      }

      final truckMaintsForLedger = await supabase
          .from('truck_maintenance')
          .select('truck_id, amount, maintenance_date, description, expense_type, provider_name, is_deleted')
          .eq('is_deleted', false)
          .order('maintenance_date', ascending: false);
      for (final m in truckMaintsForLedger) {
        final amount = (m['amount'] as num?)?.toDouble() ?? 0.0;
        if (amount <= 0) continue;
        final dateStr = m['maintenance_date']?.toString() ?? '';
        final desc = m['description']?.toString() ?? m['expense_type']?.toString() ?? 'صيانة شاحنة';
        final provider = m['provider_name']?.toString();
        unified.add({
          'date': dateStr,
          'description': provider != null && provider.isNotEmpty ? 'صيانة: $desc ($provider)' : 'صيانة: $desc',
          'beneficiary': provider ?? '-',
          'currency': (m['currency']?.toString() ?? 'MAD'),
          'amount_entree': 0.0,
          'amount_sortie': amount,
          'type': 'maintenance_expense',
          'is_archived': false,
        });
      }
      final trailerMaintsForLedger = await supabase
          .from('trailer_maintenance')
          .select('trailer_id, amount, maintenance_date, description, expense_type, provider_name, is_deleted')
          .eq('is_deleted', false)
          .order('maintenance_date', ascending: false);
      for (final m in trailerMaintsForLedger) {
        final amount = (m['amount'] as num?)?.toDouble() ?? 0.0;
        if (amount <= 0) continue;
        final dateStr = m['maintenance_date']?.toString() ?? '';
        final desc = m['description']?.toString() ?? m['expense_type']?.toString() ?? 'صيانة مقطورة';
        final provider = m['provider_name']?.toString();
        unified.add({
          'date': dateStr,
          'description': provider != null && provider.isNotEmpty ? 'صيانة مقطورة: $desc ($provider)' : 'صيانة مقطورة: $desc',
          'beneficiary': provider ?? '-',
          'currency': (m['currency']?.toString() ?? 'MAD'),
          'amount_entree': 0.0,
          'amount_sortie': amount,
          'type': 'maintenance_expense',
          'is_archived': false,
        });
      }

      if (period != 'all') {
        final now = DateTime.now();
        DateTime? from;
        DateTime? to;
        switch (period) {
          case 'day':
            from = DateTime(now.year, now.month, now.day);
            to = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
            break;
          case 'month':
            from = DateTime(now.year, now.month, 1);
            final nextMonth = now.month + 1;
            to = DateTime(nextMonth == 13 ? now.year + 1 : now.year, nextMonth == 13 ? 1 : nextMonth, 1);
            break;
          case 'year':
            from = DateTime(now.year, 1, 1);
            to = DateTime(now.year + 1, 1, 1);
            break;
        }
        if (from != null && to != null) {
          final fromSafe = from;
          final toSafe = to;
          unified.retainWhere((item) {
            final dateStr = item['date']?.toString() ?? '';
            final dt = DateTime.tryParse(dateStr);
            if (dt == null) return false;
            return dt.isAfter(fromSafe.subtract(const Duration(seconds: 1))) && dt.isBefore(toSafe);
          });
        }
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        unified.retainWhere((item) {
          final desc = (item['description']?.toString() ?? '').toLowerCase();
          final ben = (item['beneficiary']?.toString() ?? '').toLowerCase();
          final type = (item['type']?.toString() ?? '').toLowerCase();
          return desc.contains(query) || ben.contains(query) || type.contains(query);
        });
      }

      unified.sort((a, b) {
        final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });

      return unified;
    } catch (e) {
      debugPrint('Error building unified ledger: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCashBoxes() async {
    try {
      final response = await supabase
          .from('cash_boxes')
          .select()
          .order('id', ascending: true);
      final boxes = List<Map<String, dynamic>>.from(response);
      await cacheRows('cash_boxes', boxes);
      return boxes;
    } catch (e) {
      debugPrint('Error fetching cash boxes: $e');
      return [];
    }
  }

  Future<int?> getCashBoxIdByCode(String code) async {
    try {
      final response = await supabase
          .from('cash_boxes')
          .select('id')
          .eq('code', code)
          .maybeSingle();
      if (response == null) return null;
      return (response['id'] as num?)?.toInt();
    } catch (e) {
      debugPrint('Error fetching cash box by code: $e');
      return null;
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
        } else if (type == 'capital_injection' ||
            type == 'trip_revenue') {
          boxCurrencies[currency] = (boxCurrencies[currency] ?? 0.0) + amount;
        } else {
          boxCurrencies[currency] = (boxCurrencies[currency] ?? 0.0) - amount;
        }
      }

      return balances;
    } catch (e) {
      debugPrint('Error calculating cash box balances: $e');
      return {};
    }
  }

  Future<Map<String, double>> getFinancialSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await supabase.rpc('get_financial_summary', params: {
        'p_start_date': DateFormat('yyyy-MM-dd').format(startDate.toUtc()),
        'p_end_date':   DateFormat('yyyy-MM-dd').format(endDate.toUtc()),
      });
      if (response is Map<String, dynamic>) {
        return {
          'total_revenue':  (response['total_revenue'] as num?)?.toDouble() ?? 0.0,
          'total_expenses': (response['total_expenses'] as num?)?.toDouble() ?? 0.0,
          'net_profit':     (response['net_profit'] as num?)?.toDouble() ?? 0.0,
        };
      }
      return {'total_revenue': 0.0, 'total_expenses': 0.0, 'net_profit': 0.0};
    } catch (e) {
      debugPrint('Error fetching financial summary: $e');
      return {'total_revenue': 0.0, 'total_expenses': 0.0, 'net_profit': 0.0};
    }
  }

  Future<Map<String, double>> getFinancialSummaryForPeriod(DateTime startDate, DateTime endDate) async {
    return getFinancialSummary(startDate: startDate, endDate: endDate);
  }

  Future<void> addCashBox(Map<String, dynamic> data) async {
    try {
      await _requireAdmin();
      await writeRow(
        (d) => supabase.from('cash_boxes').insert(d),
        data,
      );
    } catch (e) {
      if (e is Exception) rethrow;
      debugPrint('Error adding cash box: $e');
      rethrow;
    }
  }

  Future<void> updateCashBox(int id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    try {
      await _requireAdmin();
      updateOp() => supabase.from('cash_boxes').update(data).eq('id', id);
      if (localRow == null) {
        await updateOp();
      } else {
        await updateWithLww(updateOp, 'cash_boxes', localRow);
      }
    } catch (e) {
      if (e is Exception) rethrow;
      debugPrint('Error updating cash box: $e');
      rethrow;
    }
  }

  Future<void> deleteCashBox(int id) async {
    try {
      await _requireAdmin();
      await supabase.from('cash_boxes').delete().eq('id', id);
    } catch (e) {
      if (e is Exception) rethrow;
      debugPrint('Error deleting cash box: $e');
      rethrow;
    }
  }

  static const _treasuryIncomeTypes = <String>{
    'capital_injection',
    'trip_revenue',
  };

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
      return [];
    }
  }

  Future<void> setAllowedOperations(int cashBoxId, List<String> operations) async {
    try {
      await _requireAdmin();
      await supabase.from('cash_box_operations').delete().eq('cash_box_id', cashBoxId);
      if (operations.isNotEmpty) {
        final rows = operations
            .map((op) => {
              'cash_box_id': cashBoxId,
              'operation_code': op,
            })
            .toList();
        await supabase.from('cash_box_operations').insert(rows);
      }
    } catch (e) {
      if (e is Exception) rethrow;
      debugPrint('Error setting allowed operations: $e');
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

  Future<void> _ensureOperationAllowed(int cashBoxId, String operationCode) async {
    final allowed = await isOperationAllowed(cashBoxId, operationCode);
    if (!allowed) {
      throw Exception('هذه العملية غير مسموحة لهذا الصندوق');
    }
  }

  Future<void> validateCashBoxOperationByCode(String cashBoxCode, String operationCode) async {
    try {
      final cb = await supabase
          .from('cash_boxes')
          .select('id')
          .eq('code', cashBoxCode)
          .maybeSingle();
      if (cb == null) return;
      final cashBoxId = cb['id'] as int?;
      if (cashBoxId == null) return;
      await _ensureOperationAllowed(cashBoxId, operationCode);
    } catch (e) {
      if (e is Exception) rethrow;
      debugPrint('Error validating cash box operation: $e');
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
      await writeRow(
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

  Future<String?> _driverNameById(int driverId) async {
    try {
      final row = await supabase.from('drivers').select('name').eq('id', driverId).maybeSingle();
      return row?['name']?.toString() ?? 'بدون سائق';
    } catch (_) {
      return 'بدون سائق';
    }
  }

  Future<List<Map<String, dynamic>>> getAdvances() async {
    try {
      final response = await supabase.from('advances').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching advances: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllAdvances() async {
    try {
      final response = await supabase.from('advances').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching all advances: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getInvoices() async {
    try {
      final response = await supabase.from('invoices').select().order('issue_date', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching invoices: $e');
      return [];
    }
  }

  Future<String> uploadReceipt(String fileName, List<int> bytes) async {
    try {
      final fileExt = fileName.contains('.') ? fileName.split('.').last : 'jpg';
      final path = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      await supabase.storage.from('receipts').uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: const FileOptions(contentType: 'image/*', upsert: true),
          );
      return supabase.storage.from('receipts').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading receipt: $e');
      rethrow;
    }
  }
}
