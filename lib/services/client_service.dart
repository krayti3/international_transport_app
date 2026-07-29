import 'package:flutter/foundation.dart';
import 'package:decimal/decimal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/calculation_engine.dart';
import 'package:international_transport_app/services/sync_service.dart';
import 'package:international_transport_app/models/bank_account.dart';
import 'package:international_transport_app/models/invoice.dart';
import 'package:international_transport_app/models/client.dart';

class ClientService {
  final SupabaseClient supabase = Supabase.instance.client;

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
            debugPrint('ClientService: stripping unknown column "$column" from update (PGRST204)');
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

  // Clients CRUD
  Future<List<Client>> getClients({bool activeOnly = false}) async {
    try {
      var query = supabase.from('clients').select();
      if (activeOnly) {
        query = query.eq('is_active', true);
      }
      final response = await query;
      final clients = List<Map<String, dynamic>>.from(response).map((e) => Client.fromMap(e)).toList();
      await _cacheRows('clients', response);
      return clients;
    } catch (e) {
      debugPrint('Error fetching clients: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getClientsPage({
    int offset = 0,
    int limit = 20,
    bool activeOnly = false,
  }) async {
    try {
      var query = supabase.from('clients').select();
      if (activeOnly) {
        query = query.eq('is_active', true);
      }
      final response = await query
          .order('name', ascending: true)
          .range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching clients page: $e');
      return [];
    }
  }

  Future<void> addClient(Client client) async {
    await _writeClient((d) => supabase.from('clients').insert(d), client.toMap());
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

  // Bank Accounts CRUD
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

  Future<List<BankAccount>> getActiveBankAccounts() async {
    try {
      final response = await supabase.from('bank_accounts').select().eq('is_active', true);
      final bankAccounts = List<Map<String, dynamic>>.from(response).map((e) => BankAccount.fromMap(e)).toList();
      return bankAccounts;
    } catch (e) {
      debugPrint('Error fetching active bank accounts: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getClientsRaw() async {
    try {
      final response = await supabase.from('clients').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching clients raw: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getInvoicesRaw() async {
    try {
      final response = await supabase.from('invoices').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching invoices raw: $e');
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
    await _updateWithLww(
      () => _writeRow(
        (d) => supabase.from('bank_accounts').update(d).eq('id', id),
        data,
      ),
      'bank_accounts',
      localRow,
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
        (d) => supabase.from('clients').update({'default_bank_account_id': bankAccountId}).eq('id', clientId),
        {'default_bank_account_id': bankAccountId},
      );
    } catch (e) {
      debugPrint('Error updating client default bank account: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _normalizeClient(Map<String, dynamic> client) {
    final name = client['name']?.toString() ??
        client['full_name']?.toString() ??
        client['company_name']?.toString() ??
        client['client_name']?.toString() ??
        '';
    return Map<String, dynamic>.from(client)..['name'] = name;
  }

  Future<void> recordBulkPayment(
    int clientId,
    double totalAmountPaid,
    String method,
    String ref,
  ) async {
    try {
      await _requireAdmin();
      final paymentResponse = await supabase
          .from('payments')
          .insert({
            'client_id': clientId,
            'amount': totalAmountPaid,
            'method': method,
            'ref': ref,
          })
          .select()
          .single();
      final paymentId = paymentResponse['id'];

      final invoicesResponse = await supabase
          .from('invoices')
          .select()
          .eq('client_id', clientId)
          .neq('status', 'paid')
          .order('issue_date', ascending: true);

      final invoices = List<Map<String, dynamic>>.from(invoicesResponse);
      double remainingPayment = totalAmountPaid;

      for (final invoice in invoices) {
        if (remainingPayment <= 0) break;

        final invoiceId = invoice['id'];
        final totalAmount = (invoice['total_amount'] as num?)?.toDouble() ?? 0.0;
        final currentPaid = (invoice['paid_amount'] as num?)?.toDouble() ?? 0.0;
        final remainingToClose = totalAmount - currentPaid;

        double allocatedAmount = 0;
        String newStatus = 'partially_paid';

        if (remainingPayment >= remainingToClose) {
          allocatedAmount = remainingToClose;
          remainingPayment -= remainingToClose;
          newStatus = 'paid';
        } else {
          allocatedAmount = remainingPayment;
          remainingPayment = 0;
          newStatus = 'partially_paid';
        }

        final newPaidAmount = currentPaid + allocatedAmount;

        await supabase
            .from('invoices')
            .update({
              'paid_amount': newPaidAmount,
              'status': newStatus,
            })
            .eq('id', invoiceId);

        await supabase
            .from('payment_invoice_allocations')
            .insert({
              'payment_id': paymentId,
              'invoice_id': invoiceId,
              'allocated_amount': allocatedAmount,
            });
      }
    } catch (e) {
      if (e is Exception) rethrow;
      debugPrint('Error recording bulk payment: $e');
      rethrow;
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

  Future<List<Invoice>> getOverdueInvoices() async {
    try {
      final invoices = await getInvoices();
      final now = DateTime.now();
      final overdue = <Invoice>[];
      for (final invoice in invoices) {
        final status = invoice.status;
        if (status == 'paid') continue;
        final dueDate = invoice.dueDate;
        if (dueDate == null) continue;
        if (!dueDate.isBefore(now)) continue;
        overdue.add(invoice);
      }
      overdue.sort((a, b) {
        final da = a.dueDate ?? now;
        final db = b.dueDate ?? now;
        return da.compareTo(db);
      });
      return overdue;
    } catch (e) {
      debugPrint('Error fetching overdue invoices: $e');
      return [];
    }
  }

  Future<void> recordManualPayment({
    required int clientId,
    required double totalAmountPaid,
    required String method,
    required String ref,
    required List<Map<String, dynamic>> allocations,
  }) async {
    try {
      await _requireAdmin();

      final paymentResponse = await supabase
          .from('payments')
          .insert({
            'client_id': clientId,
            'amount': totalAmountPaid,
            'method': method,
            'ref': ref,
          })
          .select()
          .single();
      final paymentId = paymentResponse['id'];

      for (final alloc in allocations) {
        final invoiceId = alloc['invoice_id'] as int;
        final allocated = (alloc['amount'] as num?)?.toDouble() ?? 0.0;
        if (allocated <= 0) continue;

        final invResponse = await supabase
            .from('invoices')
            .select('total_amount, paid_amount')
            .eq('id', invoiceId)
            .single();
        final total = (invResponse['total_amount'] as num?)?.toDouble() ?? 0.0;
        final currentPaid = (invResponse['paid_amount'] as num?)?.toDouble() ?? 0.0;
        final newPaid = currentPaid + allocated;

        String newStatus = 'unpaid';
        if (total > 0 && newPaid >= total) {
          newStatus = 'paid';
        } else if (newPaid > 0) {
          newStatus = 'partially_paid';
        }

        await supabase
            .from('invoices')
            .update({'paid_amount': newPaid, 'status': newStatus})
            .eq('id', invoiceId);

        await supabase
            .from('payment_invoice_allocations')
            .insert({
              'payment_id': paymentId,
              'invoice_id': invoiceId,
              'allocated_amount': allocated,
            });
      }
    } catch (e) {
      if (e is Exception) rethrow;
      debugPrint('Error recording manual payment: $e');
      rethrow;
    }
  }

  // Invoices
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
        clientMap[id] = _normalizeClient(client);
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

  Future<List<Invoice>> getInvoicesPage({
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      final invoicesResponse = await supabase
          .from('invoices')
          .select()
          .order('issue_date', ascending: false)
          .range(offset, offset + limit - 1);
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
        clientMap[id] = _normalizeClient(client);
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
      debugPrint('Error fetching invoices page: $e');
      return [];
    }
  }

  Future<Invoice?> getInvoiceById(int id) async {
    try {
      final response = await supabase
          .from('invoices')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response == null) return null;
      await _cacheSingleRow('invoices', response);
      return Invoice.fromMap(response);
    } catch (e) {
      debugPrint('Error fetching invoice by id: $e');
      return null;
    }
  }

  Future<void> updateInvoice(
    int id,
    Map<String, dynamic> data, {
    Map<String, dynamic>? localRow,
  }) async {
    if (localRow == null) {
      await _writeRow(
        (d) => supabase.from('invoices').update(d).eq('id', id),
        data,
      );
      return;
    }
    await _updateWithLww(
      () => _writeRow(
        (d) => supabase.from('invoices').update(d).eq('id', id),
        data,
      ),
      'invoices',
      localRow,
    );
  }

  Future<void> deleteInvoice(int id) async {
    try {
      await supabase.from('invoices').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting invoice: $e');
      rethrow;
    }
  }

  Future<void> updateInvoiceStatus(
    int invoiceId,
    double newPaidAmount, {
    Map<String, dynamic>? localRow,
  }) async {
    try {
      await _requireAdmin();
      final data = <String, dynamic>{
        'paid_amount': newPaidAmount,
        'status': newPaidAmount >= 0 ? 'partially_paid' : 'overdue',
      };
      await _writeRow(
        (d) => supabase.from('invoices').update(d).eq('id', invoiceId),
        data,
      );
    } catch (e) {
      if (e is Exception) rethrow;
      debugPrint('Error updating invoice status: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getInvoicePayments(int invoiceId) async {
    try {
      final response = await supabase
          .from('invoice_payments')
          .select()
          .eq('invoice_id', invoiceId)
          .order('payment_date', ascending: false);
      final invoicePayments = List<Map<String, dynamic>>.from(response);
      await _cacheRows('invoice_payments', invoicePayments);
      return invoicePayments;
    } catch (e) {
      debugPrint('Error fetching invoice payments: $e');
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

  Future<void> addInvoicePayment(Map<String, dynamic> data) async {
    await _writeRow(
      (d) => supabase.from('invoice_payments').insert(d),
      data,
    );
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
      BankAccount? resolvedBankAccount;
      if (finalBankAccountId != null) {
        resolvedBankAccount = await getBankAccountById(finalBankAccountId);
        if (resolvedBankAccount == null) {
          throw Exception('الحساب البنكي المحدد غير موجود.');
        }
        currency = resolvedBankAccount.currency;
      }

      if (finalBankAccountType == null && resolvedBankAccount != null) {
        finalBankAccountType = resolvedBankAccount.currency == 'EUR' ? 'european' : 'moroccan';
      }

      if (currency == null && finalBankAccountType != null) {
        currency = finalBankAccountType == 'european' ? 'EUR' : 'MAD';
      }

      if (finalBankAccountType != null && finalBankInfoText == null) {
        final sysSettings = await getSystemSettings();
        if (finalBankAccountType == 'moroccan') {
          finalBankInfoText = sysSettings?['bank_account_ma']?.toString();
        } else if (finalBankAccountType == 'european') {
          finalBankInfoText = sysSettings?['bank_account_eu']?.toString();
        }
      }

      final settings = await getAppSettings();
      final isEnabled = settings?['is_enabled'] as bool? ?? false;
      final percentage = (settings?['percentage'] as num?)?.toDouble() ?? 0.0;

      final base = amount;
      final tvaRate = Decimal.parse(percentage.toString());

      Decimal htAmount;
      Decimal tvaAmount;
      Decimal ttcAmount;

      if (inputMode == 'HT') {
        htAmount = base;
        tvaAmount = isEnabled ? CalculationEngine.calculate(amount: base, inputMode: 'HT', tvaRate: tvaRate).tvaAmount : Decimal.zero;
        ttcAmount = isEnabled ? CalculationEngine.calculate(amount: base, inputMode: 'HT', tvaRate: tvaRate).ttcAmount : base;
      } else if (inputMode == 'TTC') {
        ttcAmount = base;
        htAmount = isEnabled ? CalculationEngine.calculate(amount: base, inputMode: 'TTC', tvaRate: tvaRate).htAmount : base;
        tvaAmount = isEnabled ? CalculationEngine.calculate(amount: base, inputMode: 'TTC', tvaRate: tvaRate).tvaAmount : Decimal.zero;
      } else {
        throw Exception('وضع الإدخال غير صالح. يجب أن يكون HT أو TTC.');
      }

      final now = DateTime.now();
      final invoiceNumber = 'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 10000}';

      final invoiceData = {
        'client_id': clientId,
        'invoice_number': invoiceNumber,
        'total_amount': ttcAmount.toDouble(),
        'paid_amount': 0.0,
        'status': 'unpaid',
        'issue_date': issueDate?.toIso8601String() ?? now.toIso8601String(),
        'due_date': dueDate?.toIso8601String() ?? now.add(const Duration(days: 30)).toIso8601String(),
        'bank_account_id': finalBankAccountId,
        'bank_account_type': finalBankAccountType,
        'bank_info_text': finalBankInfoText,
        'currency': currency ?? 'MAD',
        'input_mode': inputMode,
        'ht_amount': htAmount.toDouble(),
        'tva_rate': percentage,
        'tva_amount': tvaAmount.toDouble(),
        'ttc_amount': ttcAmount.toDouble(),
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

  Future<Map<String, dynamic>> computeInvoiceTotals(double baseAmount, {String inputMode = 'HT'}) async {
    try {
      final base = Decimal.parse(baseAmount.toString());
      final settings = await getAppSettings();
      final isEnabled = settings?['is_enabled'] as bool? ?? false;
      final percentage = (settings?['percentage'] as num?)?.toDouble() ?? 0.0;
      final tvaRate = Decimal.parse(percentage.toString());

      Decimal tva;
      Decimal total;

      if (isEnabled) {
        if (inputMode == 'HT') {
          final calc = CalculationEngine.calculate(amount: base, inputMode: 'HT', tvaRate: tvaRate);
          tva = calc.tvaAmount;
          total = calc.ttcAmount;
        } else {
          final calc = CalculationEngine.calculate(amount: base, inputMode: 'TTC', tvaRate: tvaRate);
          tva = calc.tvaAmount;
          total = calc.ttcAmount;
        }
      } else {
        tva = Decimal.zero;
        total = base;
      }

      return {
        'base': baseAmount,
        'tva': tva.toDouble(),
        'total': total.toDouble(),
      };
    } catch (e) {
      debugPrint('Error computing invoice totals: $e');
      return {'base': baseAmount, 'tva': 0.0, 'total': baseAmount};
    }
  }

  Future<bool> isClientInUse(int clientId) async {
    try {
      final invoices = await supabase.from('invoices').select('id').eq('client_id', clientId).limit(1);
      if ((invoices as List).isNotEmpty) return true;

      final trips = await supabase.from('trip_orders').select('id').eq('client_id', clientId).limit(1);
      if ((trips as List).isNotEmpty) return true;

      return false;
    } catch (e) {
      debugPrint('Error checking if client is in use: $e');
      return false;
    }
  }

  Future<bool> isInvoiceInUse(int invoiceId) async {
    try {
      final count = await supabase.from('invoice_payments').select('id').eq('invoice_id', invoiceId).limit(1);
      return (count as List).isNotEmpty;
    } catch (_) {
      return true;
    }
  }
}
