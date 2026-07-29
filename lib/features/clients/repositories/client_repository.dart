import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/models/client.dart';
import 'package:international_transport_app/models/invoice.dart';
import 'package:international_transport_app/services/sync_service.dart';

class ClientRepository {
  final SupabaseClient supabase;

  ClientRepository(this.supabase);

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
            debugPrint('ClientRepository: stripping unknown column "$column" (PGRST204)');
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

  Future<void> _writeClient(
    Future<void> Function(Map<String, dynamic>) op,
    Map<String, dynamic> data,
  ) async {
    var attempt = Map<String, dynamic>.from(data);
    if (attempt.containsKey('name') && !attempt.containsKey('company_name')) {
      attempt['company_name'] = attempt['name'];
    }
    if (attempt.containsKey('company_name') && !attempt.containsKey('name')) {
      attempt['name'] = attempt['company_name'];
    }
    await _writeRow(op, attempt);
  }

  Map<String, dynamic> _normalizeClient(Map<String, dynamic> client) {
    final name = client['name']?.toString() ??
        client['full_name']?.toString() ??
        client['company_name']?.toString() ??
        client['client_name']?.toString() ??
        'بدون اسم';
    return Map<String, dynamic>.from(client)..['name'] = name;
  }

  Future<List<Client>?> getCachedClients() async {
    final rows = await SyncService.instance.getAllCachedRows('clients');
    if (rows == null) return null;
    return rows.map((e) => Client.fromMap(e)).toList();
  }

  Future<List<Client>> getClients({bool activeOnly = false}) async {
    try {
      var query = supabase.from('clients').select();
      if (activeOnly) {
        query = query.eq('is_active', true);
      }
      final response = await query;
      final clients = List<Map<String, dynamic>>.from(response)
          .map((e) => Client.fromMap(e))
          .toList();
      await _cacheRows('clients', response);
      return clients;
    } catch (e) {
      debugPrint('Error fetching clients: $e');
      return [];
    }
  }

  Future<void> addClient(Client client) async {
    await _writeClient(
      (d) => supabase.from('clients').insert(d),
      client.toMap(),
    );
  }

  Future<void> updateClient(Client client, {Map<String, dynamic>? localRow}) async {
    if (localRow == null) {
      await _writeClient(
        (d) => supabase.from('clients').update(d).eq('id', client.id!),
        client.toMap(),
      );
      return;
    }
    await _updateWithLww(
      () => _writeClient(
        (d) => supabase.from('clients').update(d).eq('id', client.id!),
        client.toMap(),
      ),
      'clients',
      localRow,
    );
  }

  Future<void> deleteClient(int id) async {
    try {
      await supabase.from('clients').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting client: $e');
      rethrow;
    }
  }

  Future<Client?> getClientById(String id) async {
    try {
      final response = await supabase
          .from('clients')
          .select()
          .eq('id', id)
          .maybeSingle();
      await _cacheSingleRow('clients', response);
      return response != null ? Client.fromMap(response) : null;
    } catch (e) {
      debugPrint('Error fetching client by id: $e');
      return null;
    }
  }

  Future<void> updateClientDefaultBankAccount(int clientId, String bankAccountId) async {
    try {
      await _writeRow(
        (d) => supabase
            .from('clients')
            .update({'default_bank_account_id': bankAccountId})
            .eq('id', clientId),
        {'default_bank_account_id': bankAccountId},
      );
    } catch (e) {
      debugPrint('Error updating client default bank account: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTripOrdersByClient(int clientId) async {
    try {
      final response = await supabase
          .from('trip_orders')
          .select()
          .eq('client_id', clientId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching trip orders by client: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getInvoicePaymentsForClient(int clientId) async {
    try {
      final invoicesResponse = await supabase
          .from('invoices')
          .select('id')
          .eq('client_id', clientId);
      final invoices = List<Map<String, dynamic>>.from(invoicesResponse);
      final invoiceIds = invoices.map((inv) => inv['id'] as int).toList();

      if (invoiceIds.isEmpty) return [];

      final paymentsResponse = await supabase
          .from('invoice_payments')
          .select()
          .inFilter('invoice_id', invoiceIds)
          .order('payment_date', ascending: false);
      return List<Map<String, dynamic>>.from(paymentsResponse);
    } catch (e) {
      debugPrint('Error fetching invoice payments for client: $e');
      return [];
    }
  }

  Future<List<Invoice>> getOutstandingInvoices(int clientId) async {
    try {
      final invoicesResponse = await supabase
          .from('invoices')
          .select()
          .eq('client_id', clientId)
          .neq('status', 'paid')
          .order('issue_date', ascending: true);
      final invoices = List<Map<String, dynamic>>.from(invoicesResponse);

      final clientResponse = await supabase
          .from('clients')
          .select()
          .eq('id', clientId)
          .maybeSingle();
      final client = clientResponse != null
          ? _normalizeClient(clientResponse)
          : <String, dynamic>{};

      for (final invoice in invoices) {
        invoice['client'] = client;
      }
      await _cacheRows('invoices', invoices);
      return invoices.map((e) => Invoice.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error fetching outstanding invoices: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getClientStatement(int clientId) async {
    try {
      final invoices = await supabase
          .from('invoices')
          .select('invoice_number, issue_date, total_amount, paid_amount, status')
          .eq('client_id', clientId)
          .order('issue_date', ascending: true);

      final payments = await supabase
          .from('payments')
          .select('amount, method, ref, created_at')
          .eq('client_id', clientId)
          .order('created_at', ascending: true);

      final List<Map<String, dynamic>> items = [];

      for (final invoice in invoices) {
        items.add({
          'type': 'invoice',
          'invoice_number': invoice['invoice_number'] ?? '',
          'date': invoice['issue_date'] ?? '',
          'amount': (invoice['total_amount'] as num?)?.toDouble() ?? 0.0,
          'paid': (invoice['paid_amount'] as num?)?.toDouble() ?? 0.0,
          'status': invoice['status'] ?? 'unknown',
        });
      }

      for (final payment in payments) {
        items.add({
          'type': 'payment',
          'ref': payment['ref'] ?? '',
          'date': payment['created_at'] ?? '',
          'amount': (payment['amount'] as num?)?.toDouble() ?? 0.0,
          'method': payment['method'] ?? 'unknown',
        });
      }

      items.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

      double balance = 0.0;
      for (final item in items) {
        if (item['type'] == 'invoice') {
          balance += (item['paid'] as double);
        } else {
          balance -= (item['amount'] as double);
        }
        item['balance'] = balance;
      }

      return items;
    } catch (e) {
      debugPrint('Error getting client statement: $e');
      return [];
    }
  }

  Future<bool> isClientInUse(int clientId) async {
    try {
      final count = await supabase
          .from('invoices')
          .select()
          .eq('client_id', clientId)
          .limit(1);
      if ((count as List).isNotEmpty) return true;
      final tripCount = await supabase
          .from('trip_orders')
          .select()
          .eq('client_id', clientId)
          .limit(1);
      if ((tripCount as List).isNotEmpty) return true;
      final advanceCount = await supabase
          .from('advances')
          .select()
          .eq('client_id', clientId)
          .limit(1);
      return (advanceCount as List).isNotEmpty;
    } catch (_) {
      return true;
    }
  }
}
