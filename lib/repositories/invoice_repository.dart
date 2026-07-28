import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/models/invoice.dart';
import 'package:decimal/decimal.dart';
import 'package:international_transport_app/services/sync_service.dart';

class InvoiceRepository {
  final SupabaseClient supabase;

  InvoiceRepository(this.supabase);

  static int? _parseUpdatedAt(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return null;
    return dt.millisecondsSinceEpoch;
  }

  Future<bool> _updateWithLww(
    Future<void> Function() updateOp,
    String tableName,
    Map<String, dynamic> localRow,
  ) async {
    final localStamp = _parseUpdatedAt(localRow['updated_at']?.toString());
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
    final serverStamp = _parseUpdatedAt(server?['updated_at']?.toString());
    if (serverStamp != null && serverStamp > localStamp) {
      return false;
    }
    await updateOp();
    return true;
  }

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
            debugPrint('InvoiceRepository: stripping unknown column "$column" (PGRST204)');
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

  Future<List<Invoice>> getInvoices() async {
    try {
      final invoicesResponse = await supabase.from('invoices').select();
      final invoices = List<Map<String, dynamic>>.from(invoicesResponse);

      final clientIds = invoices
          .map((invoice) => invoice['client_id'])
          .whereType<int>()
          .toSet()
          .toList();

      final clientsResponse = clientIds.isEmpty
          ? <Map<String, dynamic>>[]
          : await supabase
              .from('clients')
              .select()
              .inFilter('id', clientIds);
      final clients =
          List<Map<String, dynamic>>.from(clientsResponse as List<dynamic>);
      final clientMap = <int, Map<String, dynamic>>{};
      for (final client in clients) {
        final id = client['id'] as int?;
        if (id == null) continue;
        final name = client['name']?.toString() ??
            client['full_name']?.toString() ??
            client['company_name']?.toString() ??
            client['client_name']?.toString() ??
            '';
        clientMap[id] = Map<String, dynamic>.from(client)..['name'] = name;
      }

      for (final invoice in invoices) {
        final clientId = invoice['client_id'] as int?;
        final client = clientId != null ? clientMap[clientId] : null;
        if (client != null) {
          invoice['client'] = client;
        }
      }

      await _cacheRows('invoices', invoices);
      return invoices.map((e) => Invoice.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error fetching invoices: $e');
      return [];
    }
  }

  Future<Invoice> createInvoice({
    required int clientId,
    required Decimal amount,
    required String inputMode,
    String? bankAccountId,
    String? bankAccountType,
    String? bankInfoText,
    DateTime? issueDate,
    DateTime? dueDate,
  }) async {
    try {
      String? finalBankAccountId = bankAccountId;
      String? finalBankAccountType = bankAccountType;
      String? finalBankInfoText = bankInfoText;

      if (finalBankAccountId == null && finalBankAccountType == null) {
        final client = await supabase
            .from('clients')
            .select('default_bank_account_id, default_bank_account')
            .eq('id', clientId)
            .maybeSingle();
        final legacyDefaultId = client?['default_bank_account_id']?.toString();
        final newDefaultType = client?['default_bank_account']?.toString();
        if (newDefaultType == 'moroccan' || newDefaultType == 'european') {
          finalBankAccountType = newDefaultType;
        } else if (legacyDefaultId == 'moroccan' || legacyDefaultId == 'european') {
          finalBankAccountType = legacyDefaultId;
        }
        if (finalBankAccountType == null && legacyDefaultId != null) {
          finalBankAccountId = legacyDefaultId;
        }
      }

      if (finalBankAccountId == null && finalBankAccountType == null) {
        throw Exception('يرجى تحديد حساب بنكي للعميل أو اختيار حساب بنكي للفاتورة.');
      }

      String? currency;
      if (finalBankAccountId != null) {
        final bankResponse = await supabase
            .from('bank_accounts')
            .select('currency')
            .eq('id', finalBankAccountId)
            .maybeSingle();
        currency = bankResponse?['currency']?.toString();
      }

      if (finalBankAccountType == 'european') {
        currency = 'EUR';
      } else if (finalBankAccountType == 'moroccan') {
        currency = 'MAD';
      }

      if (finalBankInfoText == null && finalBankAccountType != null) {
        final sysSettings = await supabase
            .from('system_settings')
            .select()
            .eq('id', 1)
            .maybeSingle();
        if (finalBankAccountType == 'moroccan') {
          finalBankInfoText = sysSettings?['bank_account_ma']?.toString();
        } else if (finalBankAccountType == 'european') {
          finalBankInfoText = sysSettings?['bank_account_eu']?.toString();
        }
      }

      final settings = await supabase
          .from('app_settings')
          .select()
          .eq('id', 1)
          .maybeSingle();
      final percentage = (settings?['percentage'] as num?)?.toDouble() ?? 0.0;

      final base = amount;
      final tvaRate = Decimal.parse(percentage.toString());

      Decimal htAmount;
      Decimal tvaAmount;
      Decimal totalAmount;

      Decimal tvaFraction = (tvaRate / Decimal.parse('100')).toDecimal();
      if (inputMode == 'HT') {
        htAmount = base;
        tvaAmount = htAmount * tvaFraction;
        totalAmount = htAmount + tvaAmount;
      } else {
        totalAmount = base;
        htAmount = (totalAmount / (Decimal.fromInt(1) + tvaFraction)).toDecimal();
        tvaAmount = totalAmount - htAmount;
      }

      final now = DateTime.now();
      final invoiceData = <String, dynamic>{
        'client_id': clientId,
        'bank_account_id': finalBankAccountId,
        'bank_account_type': finalBankAccountType,
        'bank_info_text': finalBankInfoText,
        'issue_date': (issueDate ?? now).toIso8601String(),
        'due_date': (dueDate ?? now.add(const Duration(days: 30))).toIso8601String(),
        'amount_ht': htAmount.toDouble(),
        'tva_amount': tvaAmount.toDouble(),
        'total_amount': totalAmount.toDouble(),
        'paid_amount': 0.0,
        'currency': currency ?? 'MAD',
        'status': 'unpaid',
        'input_mode': inputMode,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await supabase
          .from('invoices')
          .insert(invoiceData)
          .select()
          .single();

      await _cacheSingleRow('invoices', response);
      return Invoice.fromMap(response);
    } catch (e) {
      debugPrint('Error creating invoice: $e');
      rethrow;
    }
  }

  Future<void> updateInvoiceStatus(
    int invoiceId,
    double newPaidAmount, {
    Map<String, dynamic>? localRow,
  }) async {
    try {
      final data = <String, dynamic>{
        'paid_amount': newPaidAmount,
        'status': newPaidAmount >= 0 ? 'partially_paid' : 'overdue',
      };
      if (localRow == null) {
        await _writeRow(
          (d) => supabase.from('invoices').update(d).eq('id', invoiceId),
          data,
        );
        return;
      }
      await _updateWithLww(
        () => _writeRow(
          (d) => supabase.from('invoices').update(d).eq('id', invoiceId),
          data,
        ),
        'invoices',
        localRow,
      );
    } catch (e) {
      debugPrint('Error updating invoice status: $e');
      rethrow;
    }
  }

  Future<void> addInvoicePayment(Map<String, dynamic> data) async {
    await _writeRow(
      (d) => supabase.from('invoice_payments').insert(d),
      data,
    );
  }
}
