import 'package:flutter/foundation.dart'; // debugPrint
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:decimal/decimal.dart';
import 'package:international_transport_app/services/calculation_engine.dart';
import 'package:international_transport_app/services/sync_service.dart';
import 'package:international_transport_app/models/bank_account.dart';
import 'package:international_transport_app/models/invoice.dart';
import 'package:international_transport_app/models/client.dart';
import 'package:international_transport_app/models/repair_invoice.dart';

class SupabaseService {
  final SupabaseClient supabase = Supabase.instance.client;

  /// Parses an ISO-8601 / SQL timestamptz string into milliseconds since epoch.
  /// Returns null if parsing fails.
  static int? _parseUpdatedAt(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return null;
    return dt.millisecondsSinceEpoch;
  }

  /// Wraps a Supabase update call with a LWW guard: the update is allowed
  /// only when the server row has not been modified AFTER [localUpdatedAt].
  /// Returns true if the write succeeded, false if a newer server version
  /// exists (silently skipped to preserve the freshest data).
  Future<bool> _updateWithLww(
    Future<void> Function() updateOp,
    String tableName,
    Map<String, dynamic> localRow,
  ) async {
    final localStamp = _parseUpdatedAt(localRow['updated_at']?.toString());
    if (localStamp == null) {
      // No timestamp → just apply the write (legacy safety)
      await updateOp();
      return true;
    }
    // 1) Read the current server row
    final id = localRow['id'];
    if (id == null) return false;
    final server = await supabase
        .from(tableName)
        .select('updated_at')
        .eq('id', id)
        .maybeSingle();
    final serverStamp = _parseUpdatedAt(server?['updated_at']?.toString());
    if (serverStamp != null && serverStamp > localStamp) {
      // Server is newer → skip write (LWW)
      return false;
    }
    // 2) Apply the update
    await updateOp();
    return true;
  }

  /// Caches a list of rows from a table so their updated_at timestamps are
  /// available later when the app needs to build a [localRow] for LWW updates.
  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  /// Caches a single row (from a .maybeSingle() or .single() query).
  Future<void> _cacheSingleRow(String tableName, Map<String, dynamic>? row) async {
    if (row == null || row['id'] == null) return;
    await SyncService.instance.cacheRows(tableName, [row]);
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

  /// Inserts/updates a client while keeping the app's 'name' in sync with the
  /// DB's canonical 'company_name' column, then delegates to [_writeRow] which
  /// tolerates any remaining schema drift.
  Future<void> _writeClient(
    Future<void> Function(Map<String, dynamic>) op,
    Map<String, dynamic> data,
  ) async {
    var attempt = Map<String, dynamic>.from(data);
    // Keep the app's 'name' and the DB's 'company_name' in sync.
    if (attempt.containsKey('name') && !attempt.containsKey('company_name')) {
      attempt['company_name'] = attempt['name'];
    }
    if (attempt.containsKey('company_name') && !attempt.containsKey('name')) {
      attempt['name'] = attempt['company_name'];
    }
    await _writeRow(op, attempt);
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

  /// Generic tolerant writer used by every table. Keeps working despite schema
  /// drift between the app and the live database:
  ///  - Unknown columns (PGRST204) are stripped and retried.
  ///  - NOT NULL violations (23502) are filled with an empty string and retried.
  /// Any other error (or too many conflicts) is rethrown so the caller can show
  /// feedback to the user.
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
            debugPrint('SupabaseService: stripping unknown column "$column" from update (PGRST204)');
            attempt.remove(column);
            continue;
          }
        } else if (e.code == '23502') {
          final column = _notNullColumnFrom(e.message);
          if (column != null) {
            // NOT NULL violation: fill the column with an empty string (valid
            // for text columns). Remember it so a numeric column that rejects
            // '' with 22P02 can be retried with 0.
            attempt[column] = '';
            lastFilledColumn = column;
            continue;
          }
        } else if (e.code == '22P02') {
          // A numeric column rejected the '' placeholder we just set. Retry
          // with 0, which Postgres coerces for both numeric and text columns.
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

  // Trip Orders CRUD
  Future<List<Map<String, dynamic>>> getTripOrders() async {
    try {
      final response = await supabase.from('trip_orders').select();
      final orders = List<Map<String, dynamic>>.from(response);
      await _cacheRows('trip_orders', response);
      return orders;
    } catch (e) {
      debugPrint('Error fetching trip orders: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTripOrdersByClient(int clientId) async {
    try {
      final response = await supabase.from('trip_orders').select().eq('client_id', clientId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching trip orders by client: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTripOrdersByDriver(int driverId) async {
    try {
      final response = await supabase.from('trip_orders').select().eq('driver_id', driverId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching trip orders by driver: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAdvancesByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    try {
      final response = await supabase
          .from('advances')
          .select()
          .or('is_deleted.is.null,is_deleted.eq.false')
          .inFilter('id', ids)
          .order('date_out', ascending: false);
      final advances = List<Map<String, dynamic>>.from(response);
      await _cacheRows('advances', advances);
      return advances;
    } catch (e) {
      debugPrint('Error fetching advances by ids: $e');
      return [];
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

  /// Returns all invoice payments for a given client by fetching the client's
  /// invoices first, then fetching payments for those invoices.
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

  Future<void> updateTripOrder(int id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    if (localRow == null) {
      await supabase.from('trip_orders').update(data).eq('id', id);
      return;
    }
    await _updateWithLww(
      () => supabase.from('trip_orders').update(data).eq('id', id),
      'trip_orders',
      localRow,
    );
  }

  Future<void> deleteTripOrder(int id) async {
    try {
      await supabase.from('trip_orders').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting trip order: $e');
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

  Map<String, dynamic> _normalizeClient(Map<String, dynamic> client) {
    final name = client['name']?.toString() ??
        client['full_name']?.toString() ??
        client['company_name']?.toString() ??
        client['client_name']?.toString() ??
        '';
    return Map<String, dynamic>.from(client)..['name'] = name;
  }

  /// تسجيل دفعة إجمالية من زبون وتوزيعها تلقائياً على فواتيره غير المدفوعة
  /// بالكامل وفقاً لمبدأ FIFO (أقدم فاتورة أولاً).
  ///
  /// خطوات العمل:
  /// 1. التحقق من صلاحيات الأدمن عبر [_requireAdmin].
  /// 2. إدراج سجل دفعة جديد في جدول [payments] واسترجاع المعرف الخاص به.
  /// 3. جلب جميع فواتير الزبون التي حالتها ليست `paid` مرتبة تصاعدياً
  ///    حسب [issue_date] (الأقدم أولاً).
  /// 4. تكرار عملية توزيع المبلغ على كل فاتورة:
  ///    - إذا كان المبلغ المتبقي للدفعة يفي بإغلاق الفاتورة:
  ///      * يُضاف المبلغ الكامل للرصيد المدفوع.
  ///      * تُحدث حالة الفاتورة إلى `paid`.
  ///    - إذا لم يكن المبلغ المتبقي كافياً:
  ///      * يُضاف ما تبقى من الدفعة للرصيد المدفوع.
  ///      * تُحدث حالة الفاتورة إلى `partially_paid`.
  /// 5. تسجيل تفاصيل التوزيع في جدول [payment_invoice_allocations]
  ///    لكل فاتورة للحفاظ على سجل محاسبي كامل.
  ///
  /// المعاملات:
  /// - [clientId]: معرف الزبون في جدول [clients].
  /// - [totalAmountPaid]: المبلغ الإجمالي المدفوع حالياً.
  /// - [method]: طريقة الدفع (تحويل بنكي، شيك، نقداً، ...).
  /// - [ref]: الرقم المرجعي للدفعة (رقم الشيك، وصل التحويل، ...).
  ///
  /// يُرمى استثناء إذا لم يكن المستخدم مسجلاً كأدمن، أو إذا فشلت
  /// أي من عمليات قاعدة البيانات.
  Future<void> recordBulkPayment(
    int clientId,
    double totalAmountPaid,
    String method,
    String ref,
  ) async {
    try {
      await _requireAdmin();

      // أ) أدخل سطر في جدول payments
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

      // ب) استعلم عن فواتير هذا الزبون غير المدفوعة بالكامل مرتبة تصاعدياً
      final invoicesResponse = await supabase
          .from('invoices')
          .select()
          .eq('client_id', clientId)
          .neq('status', 'paid')
          .order('issue_date', ascending: true);

      final invoices = List<Map<String, dynamic>>.from(invoicesResponse);
      double remainingPayment = totalAmountPaid;

      // ج) حلقة تكرارية لتوزيع مبلغ الدفعة
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

        // تحديث الفاتورة
        await supabase
            .from('invoices')
            .update({
              'paid_amount': newPaidAmount,
              'status': newStatus,
            })
            .eq('id', invoiceId);

        // تسجيل تفاصيل التوزيع
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

  /// إرجاع فواتير الزبون غير المدفوعة بالكامل (status != 'paid') مرتبة
  /// تصاعدياً حسب [issue_date] (الأقدم أولاً)، مع ربط بيانات الزبون في
  /// الحقل 'client' لكل فاتورة. تُستخدم لبناء "كشف المطالبة / المستحقات".
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

  /// يُرجع كشف حساب كامل للزبون: يجمع فواتيره ودفعاته مرتبة زمنياً مع
  /// حساب الرصيد المتراكم (balance) بعد كل عملية.
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

      // إضافة الفواتير
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

      // إضافة الدفعات
      for (final payment in payments) {
        items.add({
          'type': 'payment',
          'ref': payment['ref'] ?? '',
          'date': payment['created_at'] ?? '',
          'amount': (payment['amount'] as num?)?.toDouble() ?? 0.0,
          'method': payment['method'] ?? 'unknown',
        });
      }

      // ترتيب حسب التاريخ
      items.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

      // حساب الرصيد المتراكم
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

  /// يُرجع الفواتير التي تجاوزت تاريخ الاستحقاق (due_date) ولم تُدفع بعد،
  /// مع ربط بيانات الزبون (الاسم ورقم الهاتف). تُستخدم لتذكيرات الواتساب.
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

  /// تسجيل دفعة واحدة وتوزيعها يدوياً على فواتير محددة للزبون.
  ///
  /// [allocations]: قائمة خرائط {'invoice_id': int, 'amount': double} تمثل
  /// المبلغ المخصص لكل فاتورة. تُحدّث حالة كل فاتورة (paid / partially_paid /
  /// unpaid) ويُسجَّل التوزيع في [payment_invoice_allocations].
  ///
  /// يرمي استثناءً إذا لم يكن المستخدم أدمن أو فشلت أي عملية.
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

  // Treasury Transactions
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
      await _cacheRows('treasury_transactions', transactions);
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

  /// تسجيل معاملة خزينة جديدة (تزويد، سحب، مصروف، راتب).
  ///
  /// تُستخدم من شاشة إدارة الخزينة المتاحة للسكرتيرة والأدمن. الرصيد يُحسب
  /// ديناميكياً عبر [getTreasuryBalance] فلا يُخزَّن رقم ثابت.
  Future<void> addTreasuryTransaction(
    double amount,
    String type,
    String description, {
    String? receiptUrl,
    int? cashBoxId,
  }) async {
    try {
      await _requireAdmin();
      await _writeRow(
        (d) => supabase.from('treasury_transactions').insert(d),
        {
          'amount': amount,
          'type': type,
          if (description.trim().isNotEmpty) 'description': description,
          if (receiptUrl != null) 'receipt_url': receiptUrl,
          if (cashBoxId != null) 'cash_box_id': cashBoxId,
        },
      );
    } catch (e) {
      if (e is Exception) rethrow;
      debugPrint('Error adding treasury transaction: $e');
      rethrow;
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

  /// يجمع كل العمليات المالية (الخزينة + العهد + الفواتير) في سجل موحد
  /// مرتب زمنياً مع فلترة حسب الدور والفترة والبحث.
  ///
  /// [role]: 'admin' يرى كل العمليات INCLUDING المحذوفة مؤرشفاً.
  ///         'secretary' يرى فقط العمليات غير المؤرشفة.
  /// [period]: 'day' | 'month' | 'year' | 'all'
  /// [searchQuery]: نص بحث في الوصف والمستفيد
  /// [cashBoxId]: اختياري لتقييد السجل بصندوق معين
  Future<List<Map<String, dynamic>>> getUnifiedLedger({
    String role = 'secretary',
    String period = 'all',
    String? searchQuery,
    int? cashBoxId,
  }) async {
    try {
      final List<Map<String, dynamic>> unified = [];

      // 1) عمليات الخزينة
      final treasury = cashBoxId != null
          ? await getTreasuryTransactions(cashBoxId: cashBoxId)
          : await getTreasuryTransactions();
      for (final t in treasury) {
        final amount = (t['amount'] is Decimal ? (t['amount'] as Decimal).toDouble() : (t['amount'] as num?)?.toDouble()) ?? 0.0;
        final type = t['type']?.toString() ?? '';
        if (type == 'transfer') {
          final relatedId = t['related_cash_box_id'] as int?;
          if (cashBoxId != null && relatedId == cashBoxId) {
            unified.add({
              'date': t['created_at'] ?? '',
              'description': t['description'] ?? 'تحويل',
              'beneficiary': '-',
              'currency': 'DH',
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
              'currency': 'DH',
              'amount_entree': 0.0,
              'amount_sortie': amount,
              'type': 'treasury',
              'raw_type': type,
              'is_archived': false,
            });
          }
        } else {
          final isRevenue = type == 'trip_revenue' || type == 'capital_injection';
          unified.add({
            'date': t['created_at'] ?? '',
            'description': t['description'] ?? 'معاملة خزينة',
            'beneficiary': '-',
            'currency': 'DH',
            'amount_entree': isRevenue ? amount : 0.0,
            'amount_sortie': isRevenue ? 0.0 : amount,
            'type': 'treasury',
            'raw_type': type,
            'is_archived': false,
          });
        }
      }

      // 2) العهد — حسب الدور
      final advances = role == 'admin' ? await getAllAdvances() : await getAdvances();
      for (final a in advances) {
        final driverId = a['driver_id'] as int?;
        final driverName = driverId != null ? await _driverNameById(driverId) : 'بدون سائق';
        final given = (a['amount_given'] is Decimal ? (a['amount_given'] as Decimal).toDouble() : (a['amount_given'] as num?)?.toDouble()) ?? 0.0;
        final spent = (a['amount_spent'] is Decimal ? (a['amount_spent'] as Decimal).toDouble() : (a['amount_spent'] as num?)?.toDouble());
        final returned = (a['amount_returned'] is Decimal ? (a['amount_returned'] as Decimal).toDouble() : (a['amount_returned'] as num?)?.toDouble());
        final isDeleted = a['is_deleted'] == true;

        // تسليم العهدة = خروج
        unified.add({
          'date': a['date_out'] ?? '',
          'description': 'تسليم عهدة للسائق',
          'beneficiary': driverName,
          'currency': 'DH',
          'amount_entree': 0.0,
          'amount_sortie': given,
          'type': 'advance_given',
          'is_archived': isDeleted,
        });

        // تسوية العهدة = صرفيات الرحلة
        if (a['status']?.toString() == 'settled' && spent != null && spent > 0) {
          unified.add({
            'date': a['date_return'] ?? a['date_out'] ?? '',
            'description': 'تسوية عهدة (صرفيات الرحلة)',
            'beneficiary': driverName,
            'currency': 'DH',
            'amount_entree': 0.0,
            'amount_sortie': spent,
            'type': 'advance_spent',
            'is_archived': isDeleted,
          });
        }

        // المبلغ المرجع = دخول
        if (returned != null && returned > 0) {
          unified.add({
            'date': a['date_return'] ?? a['date_out'] ?? '',
            'description': 'مرجوع عهدة من السائق',
            'beneficiary': driverName,
            'currency': 'DH',
            'amount_entree': returned,
            'amount_sortie': 0.0,
            'type': 'advance_returned',
            'is_archived': isDeleted,
          });
        }
      }

      // 3) الفواتير = مداخيل
      final invoices = await getInvoices();
      for (final inv in invoices) {
        final clientName = inv['client']?['name']?.toString() ?? 'زبون';
        final total = (inv['total_amount'] is Decimal ? (inv['total_amount'] as Decimal).toDouble() : (inv['total_amount'] as num?)?.toDouble()) ?? 0.0;
        unified.add({
          'date': inv['issue_date'] ?? '',
          'description': 'فاتورة: ${inv['invoice_number'] ?? ''}',
          'beneficiary': clientName,
          'currency': 'DH',
          'amount_entree': total,
          'amount_sortie': 0.0,
          'type': 'invoice',
          'is_archived': false,
        });
      }

      // فلترة حسب الفترة الزمنية
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

      // فلترة حسب البحث
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        unified.retainWhere((item) {
          final desc = (item['description']?.toString() ?? '').toLowerCase();
          final ben = (item['beneficiary']?.toString() ?? '').toLowerCase();
          final type = (item['type']?.toString() ?? '').toLowerCase();
          return desc.contains(query) || ben.contains(query) || type.contains(query);
        });
      }

      // ترتيب تنازلي حسب التاريخ
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

  // Cash Boxes
  Future<List<Map<String, dynamic>>> getCashBoxes() async {
    try {
      final response = await supabase
          .from('cash_boxes')
          .select()
          .order('id', ascending: true);
      final boxes = List<Map<String, dynamic>>.from(response);
      await _cacheRows('cash_boxes', boxes);
      return boxes;
    } catch (e) {
      debugPrint('Error fetching cash boxes: $e');
      return [];
    }
  }

  Future<Map<int, double>> getCashBoxBalances() async {
    try {
      final response = await supabase
          .from('treasury_transactions')
          .select('amount, type, cash_box_id, related_cash_box_id');
      final transactions = List<Map<String, dynamic>>.from(response);
      final Map<int, double> balances = {};

      for (final tx in transactions) {
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final type = _normalizeTreasuryType(tx);
        final cashBoxId = tx['cash_box_id'] as int?;
        final relatedId = tx['related_cash_box_id'] as int?;
        if (cashBoxId == null) continue;

        final current = balances[cashBoxId] ?? 0.0;
        if (type == 'transfer') {
          balances[cashBoxId] = current - amount;
          if (relatedId != null) {
            balances[relatedId] = (balances[relatedId] ?? 0.0) + amount;
          }
        } else if (type == 'capital_injection' ||
            type == 'trip_revenue') {
          balances[cashBoxId] = current + amount;
        } else {
          balances[cashBoxId] = current - amount;
        }
      }

      return balances;
    } catch (e) {
      debugPrint('Error calculating cash box balances: $e');
      return {};
    }
  }

  Future<void> addCashBox(Map<String, dynamic> data) async {
    try {
      await _requireAdmin();
      await _writeRow(
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
        await _updateWithLww(updateOp, 'cash_boxes', localRow);
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

  Future<void> addTransfer({
    required double amount,
    required int fromCashBoxId,
    required int toCashBoxId,
    String description = 'تحويل بين الصناديق',
    String? receiptUrl,
  }) async {
    try {
      await _requireAdmin();
      await _writeRow(
        (d) => supabase.from('treasury_transactions').insert(d),
        {
          'amount': amount,
          'type': 'transfer',
          'description': description,
          'cash_box_id': fromCashBoxId,
          'related_cash_box_id': toCashBoxId,
          if (receiptUrl != null) 'receipt_url': receiptUrl,
        },
      );
    } catch (e) {
      if (e is Exception) rethrow;
      debugPrint('Error adding transfer: $e');
      rethrow;
    }
  }

  // App Settings (TVA)
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

  Future<void> updateAppSettings(
    bool isEnabled,
    double percentage, {
    Map<String, dynamic>? localRow,
  }) async {
    try {
      await _requireAdmin();
      Future<void> updateOp() => supabase
          .from('app_settings')
          .update({
            'is_enabled': isEnabled,
            'percentage': percentage,
          })
          .eq('id', 1);
      if (localRow == null) {
        await updateOp();
      } else {
        await _updateWithLww(updateOp, 'app_settings', localRow);
      }
    } catch (e) {
      if (e is Exception) rethrow;
      debugPrint('Error updating app settings: $e');
      rethrow;
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

  Future<void> updateSystemSettings(Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    try {
      await _requireAdmin();
      final updateData = Map<String, dynamic>.from(data);
      updateData['updated_at'] = DateTime.now().toIso8601String();
      Future<void> updateOp() => supabase
          .from('system_settings')
          .update(updateData)
          .eq('id', 1);
      if (localRow == null) {
        await updateOp();
      } else {
        await _updateWithLww(updateOp, 'system_settings', localRow);
      }
    } catch (e) {
      if (e is Exception) rethrow;
      debugPrint('Error updating system settings: $e');
      rethrow;
    }
  }

  Future<String> uploadCompanyLogo(String fileName, List<int> bytes) async {
    try {
      final path = 'logos/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await supabase.storage.from('logos').uploadBinary(path, Uint8List.fromList(bytes));
      return supabase.storage.from('logos').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading company logo: $e');
      rethrow;
    }
  }

  /// يرفع صورة وثيقة الأسطول (شاحنة/مقطورة) إلى Supabase Storage ويرجع الرابط العام.
  Future<String> uploadFleetDocImage({
    required String entityType,
    required int entityId,
    required String fileName,
    required List<int> bytes,
  }) async {
    try {
      final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = 'fleet_docs/$entityType/$entityId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await supabase.storage.from('fleet_docs').uploadBinary(path, Uint8List.fromList(bytes));
      return supabase.storage.from('fleet_docs').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading fleet doc image: $e');
      rethrow;
    }
  }

  /// يحسب مجموع الفاتورة ديناميكياً بناءً على إعدادات الـ TVA في [app_settings].
  ///
  /// يقرأ [is_enabled] و[percentage]؛ إن كان التفعيل مُفعّلاً يُرجع:
  ///   base, tva = base * percentage/100, total = base + tva
  /// وإلا يُرجع tva = 0 و total = base (فاتورة بدون ضريبة).
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

  /// Creates a new invoice with automatic HT/TTC calculation and bank account assignment.
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

      // If no bank account ID and no bank account type, resolve from client
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

      // Get bank account details (for currency and type inference)
      String? currency;
      BankAccount? resolvedBankAccount;
      if (finalBankAccountId != null) {
        resolvedBankAccount = await getBankAccountById(finalBankAccountId);
        if (resolvedBankAccount == null) {
          throw Exception('الحساب البنكي المحدد غير موجود.');
        }
        currency = resolvedBankAccount.currency;
      }

      // Infer bank account type from currency if not explicitly set
      if (finalBankAccountType == null && resolvedBankAccount != null) {
        finalBankAccountType = resolvedBankAccount.currency == 'EUR' ? 'european' : 'moroccan';
      }

      // Set currency based on bank account type if no bank account ID
      if (currency == null && finalBankAccountType != null) {
        currency = finalBankAccountType == 'european' ? 'EUR' : 'MAD';
      }

      // Fetch bank info text from system_settings if not provided
      if (finalBankAccountType != null && finalBankInfoText == null) {
        final sysSettings = await getSystemSettings();
        if (finalBankAccountType == 'moroccan') {
          finalBankInfoText = sysSettings?['bank_account_ma']?.toString();
        } else if (finalBankAccountType == 'european') {
          finalBankInfoText = sysSettings?['bank_account_eu']?.toString();
        }
      }

      // Get TVA settings
      final settings = await getAppSettings();
      final isEnabled = settings?['is_enabled'] as bool? ?? false;
      final percentage = (settings?['percentage'] as num?)?.toDouble() ?? 0.0;

      // Calculate amounts using Decimal
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

      // Generate invoice number
      final now = DateTime.now();
      final invoiceNumber = 'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 10000}';

      // Create invoice
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

  // Financial Report
  Future<Map<String, double>> getCompanyFinancialReport() async {
    try {
      double totalTripRevenue = 0.0;
      double totalOfficeExpense = 0.0;
      double totalSalary = 0.0;
      double totalTruckMaintenance = 0.0;
      double totalTripExpense = 0.0;

      // إجمالي مداخيل الرحلات من الفواتير
      final invoices = await getInvoices();
      for (final invoice in invoices) {
        final totalAmount = (invoice['total_amount'] as num?)?.toDouble() ?? 0.0;
        totalTripRevenue += totalAmount;
      }

      // Read truck maintenance directly from the truck_maintenance table
      final maintResponse = await supabase.from('truck_maintenance').select('amount');
      final maintenances = List<Map<String, dynamic>>.from(maintResponse);
      for (final m in maintenances) {
        totalTruckMaintenance += (m['amount'] as num?)?.toDouble() ?? 0.0;
      }

      final totalExpenses = totalOfficeExpense + totalSalary + totalTripExpense + totalTruckMaintenance;
      final netProfit = totalTripRevenue - totalExpenses;

      return {
        'total_trip_revenue': totalTripRevenue,
        'total_office_expense': totalOfficeExpense,
        'total_salary': totalSalary,
        'total_truck_maintenance': totalTruckMaintenance,
        'total_trip_expense': totalTripExpense,
        'total_expenses': totalExpenses,
        'net_profit': netProfit,
      };
    } catch (e) {
      debugPrint('Error calculating financial report: $e');
      return {
        'total_trip_revenue': 0.0,
        'total_office_expense': 0.0,
        'total_salary': 0.0,
        'total_trip_expense': 0.0,
        'total_truck_maintenance': 0.0,
        'total_expenses': 0.0,
        'net_profit': 0.0,
      };
    }
  }

  /// تقرير الأرباح للأدمن: يجمع مداخيل الفواتير (بدون TVA) ومصاريف الشركة
  /// (تشغيل الرحلات + المكتب + الأجور) لـ **الشهر الحالي** فقط، ثم يحسب
  /// الأرباح الإجمالية والصافية.
  ///
  /// صافي الأرباح = إجمالي المداخيل بدون الـ TVA - إجمالي المصاريف.
  Future<Map<String, double>> getCompanyProfitReport() async {
    try {
      // نطاق الشهر الحالي
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startStr = startOfMonth.toIso8601String();
      final endStr = (now.month == 12
              ? DateTime(now.year + 1, 1, 1)
              : DateTime(now.year, now.month + 1, 1))
          .toIso8601String();

      // 1) مداخيل الفواتير للشهر الحالي
      final invoicesResponse = await supabase
          .from('invoices')
          .select('total_amount, issue_date')
          .gte('issue_date', startStr)
          .lt('issue_date', endStr);
      final invoices = List<Map<String, dynamic>>.from(invoicesResponse);
      double totalRevenueWithTva = 0.0;
      for (final inv in invoices) {
        totalRevenueWithTva += (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
      }

      // 2) اقتطاع الـ TVA ديناميكياً حسب app_settings
      final settings = await getAppSettings();
      final isTvaEnabled = settings?['is_enabled'] as bool? ?? false;
      final tvaPct = (settings?['percentage'] as num?)?.toDouble() ?? 0.0;
      final totalRevenue = isTvaEnabled && tvaPct > 0
          ? totalRevenueWithTva / (1 + tvaPct / 100)
          : totalRevenueWithTva;
      final tvaAmount = totalRevenueWithTva - totalRevenue;

      // 3) مصاريف الشركة للشهر الحالي (3 أنواع فقط)
      final txResponse = await supabase
          .from('treasury_transactions')
          .select('amount, type, created_at')
          .gte('created_at', startStr)
          .lt('created_at', endStr);
      final txs = List<Map<String, dynamic>>.from(txResponse);
      double tripExpense = 0.0;
      double officeExpense = 0.0;
      double salary = 0.0;
      for (final tx in txs) {
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        switch (tx['type']?.toString()) {
          case 'trip_expense':
            tripExpense += amount;
            break;
          case 'office_expense':
            officeExpense += amount;
            break;
          case 'salary':
            salary += amount;
            break;
          default:
            break;
        }
      }

      final maintResponse = await supabase
          .from('truck_maintenance')
          .select('amount, maintenance_date')
          .gte('maintenance_date', startStr)
          .lt('maintenance_date', endStr);
      final maints = List<Map<String, dynamic>>.from(maintResponse);
      double truckMaintenance = 0.0;
      for (final m in maints) {
        truckMaintenance += (m['amount'] as num?)?.toDouble() ?? 0.0;
      }
      final totalExpenses = tripExpense + officeExpense + salary + truckMaintenance;

      final grossProfit = totalRevenue; // إجمالي المداخيل بدون TVA
      final netProfit = grossProfit - totalExpenses;

      return {
        'total_revenue_with_tva': totalRevenueWithTva,
        'tva_amount': tvaAmount,
        'total_revenue': totalRevenue,
        'trip_expense': tripExpense,
        'office_expense': officeExpense,
        'salary': salary,
        'truck_maintenance': truckMaintenance,
        'total_expenses': totalExpenses,
        'gross_profit': grossProfit,
        'net_profit': netProfit,
      };
    } catch (e) {
      debugPrint('Error calculating company profit report: $e');
      return {
        'total_revenue_with_tva': 0.0,
        'tva_amount': 0.0,
        'total_revenue': 0.0,
        'trip_expense': 0.0,
        'office_expense': 0.0,
        'salary': 0.0,
        'truck_maintenance': 0.0,
        'total_expenses': 0.0,
        'gross_profit': 0.0,
        'net_profit': 0.0,
      };
    }
  }

  /// Ensure the authenticated user has a row in the 'users' RBAC table.
  /// Accounts created before the migration existed have no row, which makes
  /// them look like non-admins (no add/edit buttons). Insert one with the
  /// default 'admin' role (matching signup_screen) if it is missing.
  Future<void> ensureUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final existing = await supabase
          .from('users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      if (existing != null) return;

      await supabase.from('users').insert({
        'id': user.id,
        'email': user.email,
        'role': 'driver',
      });
    } catch (e) {
      debugPrint('Error ensuring user profile: $e');
    }
  }

  // RBAC - Role Based Access Control
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

  bool get isAdmin => _currentRole == 'admin';
  bool get isSecretary => _currentRole == 'secretary';
  bool get isDriver => _currentRole == 'driver';

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

  /// List all users (id, email, role) for the admin user-management screen.
  /// Allowed by the "Users are viewable by team" RLS policy.
  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      await _requireAdmin();
      final response = await supabase
          .from('users')
          .select('id, email, role')
          .order('email', ascending: true);
      final users = List<Map<String, dynamic>>.from(response);
      await _cacheRows('users', users);
      return users;
    } catch (e) {
      debugPrint('Error fetching users: $e');
      rethrow;
    }
  }

  /// Update the role of a user (admin / secretary / driver).
  /// Restricted to admins (enforced here and by the RLS policy).
  Future<void> updateUserRole(
    String userId,
    String role, {
    Map<String, dynamic>? localRow,
  }) async {
    try {
      await _requireAdmin();
      Future<void> updateOp() => supabase.from('users').update({'role': role}).eq('id', userId);
      if (localRow == null) {
        await updateOp();
      } else {
        await _updateWithLww(updateOp, 'users', localRow);
      }
    } catch (e) {
      if (e is Exception) rethrow;
      debugPrint('Error updating user role: $e');
      rethrow;
    }
  }

  // Driver Salary Calculation
  Future<Map<String, dynamic>> calculateDriverSalary({
    required String driverId,
    required int month,
    required int year,
  }) async {
    try {
      // Fetch driver profile for base salary and bonus percentage
      final driverResponse = await supabase
          .from('drivers')
          .select('base_salary, bonus_percentage')
          .eq('id', driverId)
          .maybeSingle();

      final baseSalary = (driverResponse?['base_salary'] as num?)?.toDouble() ?? 0.0;
      final bonusPercentage = (driverResponse?['bonus_percentage'] as num?)?.toDouble() ?? 0.0;

      // Fetch completed trips for this driver in the given month/year
      final startDate = DateTime(year, month, 1);
      final endDate = month == 12
          ? DateTime(year + 1, 1, 1).subtract(const Duration(days: 1))
          : DateTime(year, month + 1, 1).subtract(const Duration(days: 1));

      final tripsResponse = await supabase
          .from('trip_orders')
          .select('id, price, status')
          .eq('driver_id', driverId)
          .eq('status', 'completed')
          .gte('departure_date', startDate.toIso8601String().split('T').first)
          .lte('departure_date', endDate.toIso8601String().split('T').first);

      final trips = List<Map<String, dynamic>>.from(tripsResponse);
      double totalTripValue = 0.0;
      for (final trip in trips) {
        totalTripValue += (trip['price'] as num?)?.toDouble() ?? 0.0;
      }

      final bonusAmount = totalTripValue * (bonusPercentage / 100);
      final totalSalary = baseSalary + bonusAmount;

      return {
        'driver_id': driverId,
        'month': month,
        'year': year,
        'base_salary': baseSalary,
        'bonus_percentage': bonusPercentage,
        'completed_trips_count': trips.length,
        'total_trip_value': totalTripValue,
        'bonus_amount': bonusAmount,
        'total_salary': totalSalary,
      };
    } catch (e) {
      debugPrint('Error calculating driver salary: $e');
      return {
        'driver_id': driverId,
        'month': month,
        'year': year,
        'base_salary': 0.0,
        'bonus_percentage': 0.0,
        'completed_trips_count': 0,
        'total_trip_value': 0.0,
        'bonus_amount': 0.0,
        'total_salary': 0.0,
      };
    }
  }

  // Trucks CRUD
  Future<List<Map<String, dynamic>>> getTrucks() async {
    try {
      final response = await supabase
          .from('trucks')
          .select()
          .order('id', ascending: true);
      final trucks = List<Map<String, dynamic>>.from(response);
      await _cacheRows('trucks', trucks);
      return trucks;
    } catch (e) {
      debugPrint('Error fetching trucks: $e');
      return [];
    }
  }

  /// Returns true if no other truck has the same [plate].
  /// When [excludeId] is provided, that truck is ignored (useful for updates).
  Future<bool> checkTruckPlateUnique(String plate, {int? excludeId}) async {
    try {
      var query = supabase.from('trucks').select('id').eq('plate_number', plate);
      if (excludeId != null) {
        query = query.neq('id', excludeId);
      }
      final result = await query.maybeSingle();
      return result == null;
    } catch (e) {
      debugPrint('Error checking truck plate uniqueness: $e');
      return true;
    }
  }

  /// Returns true if no other trailer has the same [plate].
  /// When [excludeId] is provided, that trailer is ignored (useful for updates).
  Future<bool> checkTrailerPlateUnique(String plate, {int? excludeId}) async {
    try {
      var query = supabase.from('trailers').select('id').eq('plate_number', plate);
      if (excludeId != null) {
        query = query.neq('id', excludeId);
      }
      final result = await query.maybeSingle();
      return result == null;
    } catch (e) {
      debugPrint('Error checking trailer plate uniqueness: $e');
      return true;
    }
  }

  /// Returns true if [trailerId] is not already assigned as default_trailer_id
  /// to another truck. When [excludeTruckId] is provided, that truck is ignored.
  Future<bool> checkDefaultTrailerAvailable(int trailerId, {int? excludeTruckId}) async {
    try {
      var query = supabase.from('trucks').select('id').eq('default_trailer_id', trailerId);
      if (excludeTruckId != null) {
        query = query.neq('id', excludeTruckId);
      }
      final result = await query.maybeSingle();
      return result == null;
    } catch (e) {
      debugPrint('Error checking default trailer availability: $e');
      return true;
    }
  }

  /// If [trailerId] is currently assigned as default_trailer_id to another truck
  /// (excluding [excludeTruckId]), clears that assignment so the trailer can be
  /// reassigned. Returns the id of the truck that was cleared, or null if no
  /// reassignment was needed or if the column does not exist yet.
  Future<int?> reassignDefaultTrailer(int trailerId, {int? excludeTruckId}) async {
    try {
      var query = supabase.from('trucks').select('id').eq('default_trailer_id', trailerId);
      if (excludeTruckId != null) {
        query = query.neq('id', excludeTruckId);
      }
      final otherTruck = await query.maybeSingle();
      if (otherTruck == null) return null;

      final otherTruckId = otherTruck['id'] as int;
      await supabase
          .from('trucks')
          .update({'default_trailer_id': null})
          .eq('id', otherTruckId);
      return otherTruckId;
    } on PostgrestException catch (e) {
      // Column may not exist yet (migration not applied), or other DB error.
      debugPrint('Error reassigning default trailer: $e');
      return null;
    } catch (e) {
      debugPrint('Error reassigning default trailer: $e');
      return null;
    }
  }

  Future<bool> checkDefaultDriverAvailable(int driverId, {int? excludeTruckId}) async {
    try {
      var query = supabase.from('trucks').select('id').eq('default_driver_id', driverId);
      if (excludeTruckId != null) {
        query = query.neq('id', excludeTruckId);
      }
      final result = await query.maybeSingle();
      return result == null;
    } catch (e) {
      debugPrint('Error checking default driver availability: $e');
      return true;
    }
  }

  Future<int?> reassignDefaultDriver(int driverId, {int? excludeTruckId}) async {
    try {
      var query = supabase.from('trucks').select('id').eq('default_driver_id', driverId);
      if (excludeTruckId != null) {
        query = query.neq('id', excludeTruckId);
      }
      final otherTruck = await query.maybeSingle();
      if (otherTruck == null) return null;

      final otherTruckId = otherTruck['id'] as int;
      await supabase
          .from('trucks')
          .update({'default_driver_id': null})
          .eq('id', otherTruckId);
      return otherTruckId;
    } on PostgrestException catch (e) {
      debugPrint('Error reassigning default driver: $e');
      return null;
    } catch (e) {
      debugPrint('Error reassigning default driver: $e');
      return null;
    }
  }

  Future<void> addTruck(Map<String, dynamic> data) async {
    await _writeRow((d) => supabase.from('trucks').insert(d), data);
  }

  Future<void> updateTruck(int id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    if (localRow == null) {
      await _writeRow((d) => supabase.from('trucks').update(d).eq('id', id), data);
      return;
    }
    await _updateWithLww(
      () => _writeRow((d) => supabase.from('trucks').update(d).eq('id', id), data),
      'trucks',
      localRow,
    );
  }

  Future<void> deleteTruck(int id) async {
    try {
      await supabase.from('trucks').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting truck: $e');
      rethrow;
    }
  }

  Future<void> updateTruckLocation(int id, double latitude, double longitude) async {
    try {
      await supabase.from('trucks').update({
        'current_latitude': latitude,
        'current_longitude': longitude,
      }).eq('id', id);
    } catch (e) {
      debugPrint('Error updating truck location: $e');
      rethrow;
    }
  }

  // Truck maintenance expenses (operational expenses deducted from net profit)
  Future<List<Map<String, dynamic>>> getTruckMaintenances() async {
    try {
      final response = await supabase
          .from('truck_maintenance')
          .select()
          .order('created_at', ascending: false);
      final maintenances = List<Map<String, dynamic>>.from(response);
      await _cacheRows('truck_maintenance', maintenances);
      return maintenances;
    } catch (e) {
      debugPrint('Error fetching truck maintenances: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTruckMaintenancesByTruck(int truckId) async {
    try {
      final response = await supabase
          .from('truck_maintenance')
          .select()
          .order('created_at', ascending: false);
      final maintenances = List<Map<String, dynamic>>.from(response);
      await _cacheRows('truck_maintenance', maintenances);
      return maintenances;
    } catch (e) {
      debugPrint('Error fetching truck maintenances: $e');
      return [];
    }
  }

  Future<void> addTruckMaintenance(Map<String, dynamic> data) async {
    await _writeRow((d) => supabase.from('truck_maintenance').insert(d), data);
  }

  Future<void> updateTruckMaintenance(int id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    if (localRow == null) {
      await _writeRow(
        (d) => supabase.from('truck_maintenance').update(d).eq('id', id),
        data,
      );
      return;
    }
    await _updateWithLww(
      () => _writeRow(
        (d) => supabase.from('truck_maintenance').update(d).eq('id', id),
        data,
      ),
      'truck_maintenance',
      localRow,
    );
  }

  Future<void> deleteTruckMaintenance(int id) async {
    try {
      await supabase.from('truck_maintenance').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting truck maintenance: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTruckMaintenancesFiltered({
    int? truckId,
    String? paymentStatus,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var query = supabase.from('truck_maintenance').select();
      if (truckId != null) query = query.eq('truck_id', truckId);
      if (paymentStatus != null) query = query.eq('payment_status', paymentStatus);
      if (fromDate != null) query = query.gte('maintenance_date', fromDate.toIso8601String());
      if (toDate != null) query = query.lt('maintenance_date', toDate.toIso8601String());
      final response = await query.order('maintenance_date', ascending: false);
      final maintenances = List<Map<String, dynamic>>.from(response);
      await _cacheRows('truck_maintenance', maintenances);
      return maintenances;
    } catch (e) {
      debugPrint('Error fetching filtered truck maintenances: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMaintenancesByExpenseType(String expenseType) async {
    try {
      final combined = <Map<String, dynamic>>[];
      final truckResponse = await supabase
          .from('truck_maintenance')
          .select()
          .eq('expense_type', expenseType)
          .order('maintenance_date', ascending: false);
      for (final row in truckResponse) {
        final doc = Map<String, dynamic>.from(row);
        doc['vehicle_type'] = 'truck';
        doc['vehicle_id'] = doc['truck_id'];
        combined.add(doc);
      }
      final trailerResponse = await supabase
          .from('trailer_maintenance')
          .select()
          .eq('expense_type', expenseType)
          .order('maintenance_date', ascending: false);
      for (final row in trailerResponse) {
        final doc = Map<String, dynamic>.from(row);
        doc['vehicle_type'] = 'trailer';
        doc['vehicle_id'] = doc['trailer_id'];
        combined.add(doc);
      }
      combined.sort((a, b) {
        final aDate = a['maintenance_date']?.toString() ?? '';
        final bDate = b['maintenance_date']?.toString() ?? '';
        return bDate.compareTo(aDate);
      });
      return combined;
    } catch (e) {
      debugPrint('Error fetching maintenances by expense type: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTrailerMaintenances() async {
    try {
      final response = await supabase
          .from('trailer_maintenance')
          .select()
          .order('created_at', ascending: false);
      final maintenances = List<Map<String, dynamic>>.from(response);
      await _cacheRows('trailer_maintenance', maintenances);
      return maintenances;
    } catch (e) {
      debugPrint('Error fetching trailer maintenances: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTrailerMaintenancesByTrailer(int trailerId) async {
    try {
      final response = await supabase
          .from('trailer_maintenance')
          .select()
          .eq('trailer_id', trailerId)
          .order('created_at', ascending: false);
      final maintenances = List<Map<String, dynamic>>.from(response);
      await _cacheRows('trailer_maintenance', maintenances);
      return maintenances;
    } catch (e) {
      debugPrint('Error fetching trailer maintenances by trailer: $e');
      return [];
    }
  }

  Future<void> addTrailerMaintenance(Map<String, dynamic> data) async {
    await _writeRow((d) => supabase.from('trailer_maintenance').insert(d), data);
  }

  Future<void> updateTrailerMaintenance(int id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    if (localRow == null) {
      await _writeRow(
        (d) => supabase.from('trailer_maintenance').update(d).eq('id', id),
        data,
      );
      return;
    }
    await _updateWithLww(
      () => _writeRow(
        (d) => supabase.from('trailer_maintenance').update(d).eq('id', id),
        data,
      ),
      'trailer_maintenance',
      localRow,
    );
  }

  Future<void> deleteTrailerMaintenance(int id) async {
    try {
      await supabase.from('trailer_maintenance').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting trailer maintenance: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTrailerMaintenancesFiltered({
    int? trailerId,
    String? paymentStatus,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var query = supabase.from('trailer_maintenance').select();
      if (trailerId != null) query = query.eq('trailer_id', trailerId);
      if (paymentStatus != null) query = query.eq('payment_status', paymentStatus);
      if (fromDate != null) query = query.gte('maintenance_date', fromDate.toIso8601String());
      if (toDate != null) query = query.lt('maintenance_date', toDate.toIso8601String());
      final response = await query.order('maintenance_date', ascending: false);
      final maintenances = List<Map<String, dynamic>>.from(response);
      await _cacheRows('trailer_maintenance', maintenances);
      return maintenances;
    } catch (e) {
      debugPrint('Error fetching filtered trailer maintenances: $e');
      return [];
    }
  }

  /// Returns a list of unique expense types currently used in
  /// `truck_maintenance`, sorted alphabetically.
  Future<List<String>> getExpenseTypes() async {
    try {
      final response = await supabase
          .from('truck_maintenance')
          .select('expense_type')
          .order('expense_type');
      final raw = List<Map<String, dynamic>>.from(response);
      final types = <String>{};
      for (final row in raw) {
        final value = row['expense_type']?.toString();
        if (value != null && value.isNotEmpty) {
          types.add(value);
        }
      }
      return types.toList()..sort();
    } catch (e) {
      debugPrint('Error fetching expense types: $e');
      return [];
    }
  }

  /// Returns trucks where current_km >= 90% of oil_change_km threshold.
  Future<List<Map<String, dynamic>>> getOilChangeAlerts() async {
    try {
      final response = await supabase
          .from('trucks')
          .select()
          .gt('oil_change_km', 0)
          .order('current_km', ascending: true);
      final trucks = List<Map<String, dynamic>>.from(response);
      final alerts = <Map<String, dynamic>>[];
      for (final truck in trucks) {
        final currentKm = (truck['current_km'] as num?)?.toDouble() ?? 0;
        final oilChangeKm = (truck['oil_change_km'] as num?)?.toDouble() ?? 0;
        if (oilChangeKm > 0 && currentKm >= oilChangeKm * 0.9) {
          alerts.add({
            ...truck,
            'km_remaining': oilChangeKm - currentKm,
            'percentage': (currentKm / oilChangeKm * 100).toInt(),
          });
        }
      }
      return alerts;
    } catch (e) {
      debugPrint('Error fetching oil change alerts: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getOilChangeRecords() async {
    try {
      final response = await supabase
          .from('truck_maintenance')
          .select()
          .eq('expense_type', 'oil_change')
          .order('created_at', ascending: false);
      final records = List<Map<String, dynamic>>.from(response);
      await _cacheRows('truck_maintenance_oil', records);
      return records;
    } catch (e) {
      debugPrint('Error fetching oil change records: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getOilChangeRecordsByTruck(int truckId) async {
    try {
      final response = await supabase
          .from('truck_maintenance')
          .select()
          .eq('truck_id', truckId)
          .eq('expense_type', 'oil_change')
          .order('created_at', ascending: false);
      final records = List<Map<String, dynamic>>.from(response);
      await _cacheRows('truck_maintenance_oil', records);
      return records;
    } catch (e) {
      debugPrint('Error fetching oil change records by truck: $e');
      return [];
    }
  }

  Future<Map<String, double>> getTruckMaintenanceTotals() async {
    try {
      final response = await supabase.from('truck_maintenance').select('amount');
      final rows = List<Map<String, dynamic>>.from(response);
      double total = 0.0;
      for (final row in rows) {
        total += (row['amount'] as num?)?.toDouble() ?? 0.0;
      }
      return {'total': total};
    } catch (e) {
      debugPrint('Error calculating truck maintenance totals: $e');
      return {'total': 0.0};
    }
  }

  // Fleet documents (unified trucks + trailers)
  Future<List<Map<String, dynamic>>> getDocuments() async {
    try {
      final response = await supabase
          .from('documents')
          .select()
          .order('expiry_date', ascending: true);
      final documents = List<Map<String, dynamic>>.from(response);
      await _cacheRows('documents', documents);
      return documents;
    } catch (e) {
      debugPrint('Error fetching documents: $e');
      return [];
    }
  }

  Future<void> addDocument(Map<String, dynamic> data) async {
    await _writeRow((d) => supabase.from('documents').insert(d), data);
  }

  Future<void> deleteDocument(int id) async {
    try {
      await supabase.from('documents').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting document: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTrailers() async {
    try {
      final response = await supabase.from('trailers').select().order('id', ascending: true);
      final trailers = List<Map<String, dynamic>>.from(response);
      await _cacheRows('trailers', trailers);
      return trailers;
    } catch (e) {
      debugPrint('Error fetching trailers: $e');
      return [];
    }
  }

  Future<int?> addTrailer(Map<String, dynamic> data) async {
    try {
      final response = await supabase
          .from('trailers')
          .insert(data)
          .select('id')
          .single();
      return response['id'] as int?;
    } catch (e) {
      debugPrint('Error adding trailer: $e');
      rethrow;
    }
  }

  Future<void> updateTrailer(int id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    if (localRow == null) {
      await _writeRow((d) => supabase.from('trailers').update(d).eq('id', id), data);
      return;
    }
    await _updateWithLww(
      () => _writeRow((d) => supabase.from('trailers').update(d).eq('id', id), data),
      'trailers',
      localRow,
    );
  }

  Future<void> deleteTrailer(int id) async {
    try {
      await supabase.from('trailers').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting trailer: $e');
      rethrow;
    }
  }

  // Drivers CRUD
  Future<int?> addDriver(Map<String, dynamic> data) async {
    try {
      final response = await supabase
          .from('drivers')
          .insert(data)
          .select('id')
          .single();
      return response['id'] as int?;
    } catch (e) {
      debugPrint('Error adding driver: $e');
      rethrow;
    }
  }

  Future<void> updateDriver(int id, Map<String, dynamic> data) async {
    await _writeRow((d) => supabase.from('drivers').update(d).eq('id', id), data);
  }

  Future<void> deleteDriver(int id) async {
    try {
      await supabase.from('drivers').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting driver: $e');
      rethrow;
    }
  }

  // Truck Documents CRUD
  Future<List<Map<String, dynamic>>> getTruckDocuments() async {
    try {
      final response = await supabase
          .from('truck_documents')
          .select()
          .order('expiry_date', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching truck documents: $e');
      return [];
    }
  }

  Future<void> addTruckDocument(Map<String, dynamic> data) async {
    try {
      await _writeRow((d) => supabase.from('truck_documents').insert(d), data);
    } catch (e) {
      debugPrint('Error adding truck document: $e');
      rethrow;
    }
  }

  Future<bool> hasTruckDocumentType(int truckId, String type) async {
    try {
      final result = await supabase
          .from('truck_documents')
          .select('id')
          .eq('truck_id', truckId)
          .eq('type', type)
          .maybeSingle();
      return result != null;
    } catch (e) {
      debugPrint('Error checking truck document type: $e');
      return false;
    }
  }

  Future<void> updateTruckDocument(int id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    try {
      Future<void> updateOp() => supabase.from('truck_documents').update(data).eq('id', id);
      if (localRow == null) {
        await updateOp();
      } else {
        await _updateWithLww(updateOp, 'truck_documents', localRow);
      }
    } catch (e) {
      debugPrint('Error updating truck document: $e');
      rethrow;
    }
  }

  Future<void> deleteTruckDocument(int id) async {
    try {
      await supabase.from('truck_documents').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting truck document: $e');
      rethrow;
    }
  }

  // ===== Fleet Documents CRUD (unified trucks + trailers) =====

  Future<List<Map<String, dynamic>>> getDocumentCategories() async {
    try {
      final response = await supabase
          .from('document_categories')
          .select()
          .order('name', ascending: true);
      final rows = List<Map<String, dynamic>>.from(response);
      final seen = <String>{};
      final deduped = <Map<String, dynamic>>[];
      for (final row in rows) {
        final name = row['name']?.toString() ?? '';
        if (name.isEmpty || seen.contains(name)) continue;
        seen.add(name);
        deduped.add(row);
      }
      return deduped;
    } catch (e) {
      debugPrint('Error fetching document categories: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFleetDocumentsByDocType(String docType) async {
    try {
      final response = await supabase
          .from('fleet_documents')
          .select()
          .eq('doc_type', docType)
          .order('expiry_date', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching fleet documents by doc type: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getVehicleInfo(String entityType, int entityId) async {
    try {
      if (entityType == 'truck') {
        final response = await supabase
            .from('trucks')
            .select()
            .eq('id', entityId)
            .maybeSingle();
        return response != null ? Map<String, dynamic>.from(response) : null;
      } else if (entityType == 'trailer') {
        final response = await supabase
            .from('trailers')
            .select()
            .eq('id', entityId)
            .maybeSingle();
        return response != null ? Map<String, dynamic>.from(response) : null;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching vehicle info: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getVehicleDocumentsByType({
    required String entityType,
    required int entityId,
    required String docType,
  }) async {
    try {
      final List<Map<String, dynamic>> combined = [];
      final fleetResponse = await supabase
          .from('fleet_documents')
          .select()
          .eq('entity_type', entityType)
          .eq('entity_id', entityId)
          .eq('doc_type', docType)
          .order('expiry_date', ascending: true);
      for (final row in fleetResponse) {
        combined.add(Map<String, dynamic>.from(row));
        combined.last['_source'] = 'fleet';
      }
      if (entityType == 'truck') {
        final truckResponse = await supabase
            .from('truck_documents')
            .select()
            .eq('truck_id', entityId)
            .eq('type', docType)
            .order('expiry_date', ascending: true);
        for (final row in truckResponse) {
          final doc = Map<String, dynamic>.from(row);
          doc['entity_type'] = 'truck';
          doc['entity_id'] = doc['truck_id'];
          doc['doc_type'] = doc['type'];
          doc['_source'] = 'truck_legacy';
          combined.add(doc);
        }
      }
      combined.sort((a, b) {
        final aDate = a['expiry_date']?.toString() ?? '';
        final bDate = b['expiry_date']?.toString() ?? '';
        return aDate.compareTo(bDate);
      });
      return combined;
    } catch (e) {
      debugPrint('Error fetching vehicle documents by type: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDocumentsByDocType(String docType) async {
    try {
      final fleetResponse = await supabase
          .from('fleet_documents')
          .select()
          .eq('doc_type', docType)
          .order('expiry_date', ascending: true);
      final truckResponse = await supabase
          .from('truck_documents')
          .select()
          .eq('type', docType)
          .order('expiry_date', ascending: true);

      final combined = <Map<String, dynamic>>[];
      for (final row in fleetResponse) {
        combined.add(Map<String, dynamic>.from(row));
      }
      for (final row in truckResponse) {
        final doc = Map<String, dynamic>.from(row);
        doc['entity_type'] = 'truck';
        doc['entity_id'] = doc['truck_id'];
        doc['doc_type'] = doc['type'];
        combined.add(doc);
      }
      combined.sort((a, b) {
        final aDate = a['expiry_date']?.toString() ?? '';
        final bDate = b['expiry_date']?.toString() ?? '';
        return aDate.compareTo(bDate);
      });
      return combined;
    } catch (e) {
      debugPrint('Error fetching documents by doc type: $e');
      return [];
    }
  }

  Future<void> addDocumentCategory(Map<String, dynamic> data) async {
    try {
      await supabase.from('document_categories').insert(data);
    } catch (e) {
      debugPrint('Error adding document category: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getFleetDocuments({String? entityType, int? entityId}) async {
    try {
      var query = supabase.from('fleet_documents').select();
      if (entityType != null) query = query.eq('entity_type', entityType);
      if (entityId != null) query = query.eq('entity_id', entityId);
      final response = await query.order('expiry_date', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching fleet documents: $e');
      return [];
    }
  }

  Future<void> addFleetDocument(Map<String, dynamic> data) async {
    try {
      await _writeRow((d) => supabase.from('fleet_documents').insert(d), data);
    } catch (e) {
      debugPrint('Error adding fleet document: $e');
      rethrow;
    }
  }

  Future<bool> hasFleetDocumentType(String entityType, int entityId, String docType) async {
    try {
      final result = await supabase
          .from('fleet_documents')
          .select('id')
          .eq('entity_type', entityType)
          .eq('entity_id', entityId)
          .eq('doc_type', docType)
          .maybeSingle();
      return result != null;
    } catch (e) {
      debugPrint('Error checking fleet document type: $e');
      return false;
    }
  }

  Future<void> updateFleetDocument(int id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    try {
      Future<void> updateOp() => supabase.from('fleet_documents').update(data).eq('id', id);
      if (localRow == null) {
        await updateOp();
      } else {
        await _updateWithLww(updateOp, 'fleet_documents', localRow);
      }
    } catch (e) {
      debugPrint('Error updating fleet document: $e');
      rethrow;
    }
  }

  Future<void> deleteFleetDocument(int id) async {
    try {
      await supabase.from('fleet_documents').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting fleet document: $e');
      rethrow;
    }
  }

  /// Returns fleet documents expiring within [daysThreshold] days or already expired.
  /// Note: doc_type is now free-text, no longer joined with document_categories.
  Future<List<Map<String, dynamic>>> getExpiringFleetDocs({int daysThreshold = 30}) async {
    try {
      final now = DateTime.now();
      final threshold = now.add(Duration(days: daysThreshold));
      final thresholdStr = threshold.toIso8601String().split('T').first;

      final response = await supabase
          .from('fleet_documents')
           .select('*')
          .lte('expiry_date', thresholdStr)
          .order('expiry_date', ascending: true);

      final docs = List<Map<String, dynamic>>.from(response);
      // Filter out any that might have null expiry_date (defensive)
      return docs.where((doc) => doc['expiry_date'] != null).toList();
    } catch (e) {
      debugPrint('Error fetching expiring fleet documents: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDrivers() async {
    try {
      final response = await supabase.from('drivers').select();
      final drivers = List<Map<String, dynamic>>.from(response);
      await _cacheRows('drivers', drivers);
      return drivers;
    } catch (e) {
      debugPrint('Error fetching drivers: $e');
      return [];
    }
  }

  /// Updates the visa information for a driver.
  Future<void> updateDriverVisa(String driverId, String visaNumber, DateTime expiryDate) async {
    try {
      await _writeRow(
        (d) => supabase.from('drivers').update({
          'visa_number': visaNumber,
          'visa_expiry_date': expiryDate.toIso8601String().split('T').first,
          'has_valid_visa': true,
        }).eq('id', int.parse(driverId)),
        {
          'visa_number': visaNumber,
          'visa_expiry_date': expiryDate.toIso8601String().split('T').first,
          'has_valid_visa': true,
        },
      );
    } catch (e) {
      debugPrint('Error updating driver visa: $e');
      rethrow;
    }
  }

  /// Returns drivers whose visa is expiring within the next [daysThreshold] days
  /// or has already expired. Only returns drivers with a non-null visa_expiry_date.
  Future<List<Map<String, dynamic>>> getExpiringVisas({int daysThreshold = 30}) async {
    try {
      final allDrivers = await getDrivers();
      final now = DateTime.now();
      final threshold = now.add(Duration(days: daysThreshold));

      return allDrivers.where((driver) {
        final expiryStr = driver['visa_expiry_date']?.toString();
        if ( expiryStr == null || expiryStr.isEmpty) return false;
        final expiryDate = DateTime.tryParse(expiryStr);
        if (expiryDate == null) return false;
        return expiryDate.isBefore(threshold) || expiryDate.isAtSameMomentAs(now);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching expiring visas: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUpcomingInvoices({int? days = 30}) async {
    try {
      final toDate = DateTime.now().add(Duration(days: days ?? 30));
      final response = await supabase
          .from('invoices')
          .select('*, client:clients(name)')
          .gte('due_date', DateTime.now().toIso8601String())
          .lte('due_date', toDate.toIso8601String())
          .order('due_date', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching upcoming invoices: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUpcomingDocumentExpiries({int? days = 30}) async {
    try {
      final toDate = DateTime.now().add(Duration(days: days ?? 30));
      final fromDateStr = DateTime.now().toIso8601String().split('T').first;
      final toDateStr = toDate.toIso8601String().split('T').first;

      final fleetDocs = await supabase
          .from('fleet_documents')
          .select()
          .gte('expiry_date', fromDateStr)
          .lte('expiry_date', toDateStr)
          .order('expiry_date', ascending: true);

      final truckDocs = await supabase
          .from('truck_documents')
          .select('*, truck:trucks(plate_number)')
          .gte('expiry_date', fromDateStr)
          .lte('expiry_date', toDateStr)
          .order('expiry_date', ascending: true);

      final trucks = await supabase.from('trucks').select('id, plate_number');
      final trailers = await supabase.from('trailers').select('id, plate_number');
      final truckMap = {for (final t in trucks) t['id'] as int: t['plate_number']?.toString() ?? ''};
      final trailerMap = {for (final t in trailers) t['id'] as int: t['plate_number']?.toString() ?? ''};

      final result = <Map<String, dynamic>>[];
      for (final doc in List<Map<String, dynamic>>.from(fleetDocs)) {
        final entityType = doc['entity_type']?.toString() ?? '';
        final entityId = (doc['entity_id'] as num?)?.toInt();
        final plate = entityType == 'truck'
            ? (entityId != null ? truckMap[entityId] : null)
            : (entityId != null ? trailerMap[entityId] : null);
        result.add({
          ...doc,
          'source': 'fleet',
          'plate': plate ?? '',
        });
      }
      for (final doc in List<Map<String, dynamic>>.from(truckDocs)) {
        result.add({
          ...doc,
          'source': 'truck',
          'plate': doc['truck']?['plate_number']?.toString() ?? '',
        });
      }
      return result;
    } catch (e) {
      debugPrint('Error fetching upcoming document expiries: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUpcomingMaintenanceDueDates({int? days = 30}) async {
    try {
      final toDate = DateTime.now().add(Duration(days: days ?? 30));
      final fromDateStr = DateTime.now().toIso8601String().split('T').first;
      final toDateStr = toDate.toIso8601String().split('T').first;

      final response = await supabase
          .from('truck_maintenance')
          .select('*, truck:trucks(plate_number)')
          .gte('due_date', fromDateStr)
          .lte('due_date', toDateStr)
          .order('due_date', ascending: true);
      return List<Map<String, dynamic>>.from(response)
          .where((m) => m['due_date'] != null)
          .toList();
    } catch (e) {
      debugPrint('Error fetching upcoming maintenance due dates: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUpcomingVisaExpiries({int? days = 30}) async {
    try {
      final toDate = DateTime.now().add(Duration(days: days ?? 30));
      final fromDateStr = DateTime.now().toIso8601String().split('T').first;
      final toDateStr = toDate.toIso8601String().split('T').first;

      final response = await supabase
          .from('drivers')
          .select()
          .gte('visa_expiry_date', fromDateStr)
          .lte('visa_expiry_date', toDateStr)
          .order('visa_expiry_date', ascending: true);
      return List<Map<String, dynamic>>.from(response)
          .where((d) => d['visa_expiry_date'] != null)
          .toList();
    } on PostgrestException catch (e) {
      if (e.code == '42703' || e.message.contains('does not exist')) {
        debugPrint('visa_expiry_date column not found, skipping visa alerts');
        return [];
      }
      rethrow;
    } catch (e) {
      debugPrint('Error fetching upcoming visa expiries: $e');
      return [];
    }
  }

  // Advances (العُهد) CRUD
  Future<List<Map<String, dynamic>>> getAdvances() async {
    try {
      final response = await supabase
          .from('advances')
          .select()
          .or('is_deleted.is.null,is_deleted.eq.false')
          .order('date_out', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching advances: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAdvancesByDriver(int driverId) async {
    try {
      final response = await supabase
          .from('advances')
          .select()
          .or('is_deleted.is.null,is_deleted.eq.false')
          .eq('driver_id', driverId)
          .order('date_out', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching advances by driver: $e');
      return [];
    }
  }

  /// For admin view: fetches ALL advances including archived/deleted ones.
  Future<List<Map<String, dynamic>>> getAllAdvances() async {
    try {
      final response = await supabase
          .from('advances')
          .select()
          .order('date_out', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching all advances: $e');
      return [];
    }
  }

  Future<void> addAdvance(Map<String, dynamic> data) async {
    await _writeRow((d) => supabase.from('advances').insert(d), data);
  }

  Future<void> addProduct(Map<String, dynamic> data) async {
    try {
      await supabase.from('products').insert(data);
    } catch (e) {
      debugPrint('Error adding product: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addTripOrder(Map<String, dynamic> data) async {
    try {
      final response = await supabase.from('trip_orders').insert(data).select().single();
      await _cacheSingleRow('trip_orders', response);
      return response;
    } catch (e) {
      debugPrint('Error adding trip order: $e');
      rethrow;
    }
  }

  /// Insert an advance (mission) and return the created row so callers can
  /// link trip-order legs (outbound/return) to it via trip_id.
  Future<Map<String, dynamic>?> createAdvanceReturning(Map<String, dynamic> data) async {
    try {
      final res = await supabase.from('advances').insert(data).select().single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      debugPrint('Error creating advance: $e');
      rethrow;
    }
  }

  Future<void> updateAdvance(int id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    if (localRow == null) {
      await _writeRow(
        (d) => supabase.from('advances').update(d).eq('id', id),
        data,
      );
      return;
    }
    await _updateWithLww(
      () => _writeRow(
        (d) => supabase.from('advances').update(d).eq('id', id),
        data,
      ),
      'advances',
      localRow,
    );
  }

  /// Soft delete: flip is_deleted so the row vanishes from the secretary's
  /// view but stays in the archive for undo/audit. Also removes the linked
  /// treasury postings (the cash returns to the box on delete).
  Future<void> deleteAdvance(int id) async {
    try {
      final adv = await supabase
          .from('advances')
          .select('treasury_tx_id, treasury_tx_extra_id')
          .eq('id', id)
          .maybeSingle();
      final txId = adv?['treasury_tx_id'] as int?;
      final txExtraId = adv?['treasury_tx_extra_id'] as int?;
      if (txId != null) await _deleteTreasuryTransaction(txId);
      if (txExtraId != null) await _deleteTreasuryTransaction(txExtraId);
      await supabase.from('advances').update({
        'is_deleted': true,
        'treasury_tx_id': null,
        'treasury_tx_extra_id': null,
      }).eq('id', id);
    } catch (e) {
      debugPrint('Error deleting advance: $e');
      rethrow;
    }
  }

  /// Undo a soft delete by restoring the row, then re-create its treasury
  /// postings.
  Future<void> restoreAdvance(int id) async {
    try {
      await supabase.from('advances').update({'is_deleted': false}).eq('id', id);
      await syncAdvanceTreasury(id);
    } catch (e) {
      debugPrint('Error restoring advance: $e');
      rethrow;
    }
  }

  /// يُبقي الخزينة (treasury_transactions) متوافقة مع حالة عهدة السائق.
  ///
  /// pending  -> قيد trip_expense واحد بقيمة amount_given (خرج المال من الصندوق).
  /// settled  -> المصروف الفعلي هو amount_spent:
  ///    - spent <= given : يُخفَّض القيد الأساسي إلى spent (الرجوع ضمني).
  ///    - spent  > given : يبقى القيد الأساسي بـ given + قيد إضافي (spent-given).
  Future<void> syncAdvanceTreasury(int advanceId) async {
    try {
      final adv = await supabase
          .from('advances')
          .select(
              'id, driver_id, amount_given, amount_spent, status, treasury_tx_id, treasury_tx_extra_id')
          .eq('id', advanceId)
          .maybeSingle();
      if (adv == null) return;

      final driverId = adv['driver_id'] as int?;
      final given = (adv['amount_given'] as num?)?.toDouble() ?? 0.0;
      final spent = (adv['amount_spent'] as num?)?.toDouble();
      final status = adv['status']?.toString() ?? 'pending';
      final driverName = driverId != null ? await _driverNameById(driverId) : 'بدون سائق';

      double base;
      double extra;
      if (status == 'settled' && spent != null) {
        if (spent <= given) {
          base = spent;
          extra = 0;
        } else {
          base = given;
          extra = spent - given;
        }
      } else {
        base = given;
        extra = 0;
      }

      int? txId = adv['treasury_tx_id'] as int?;
      int? txExtraId = adv['treasury_tx_extra_id'] as int?;

      if (txId == null) {
        final row = await supabase
            .from('treasury_transactions')
            .insert({
              'type': 'trip_expense',
              'amount': base,
              'description': 'عهدة السائق $driverName — تسليم عهدة (معرّف #$advanceId)',
            })
            .select('id')
            .single();
        txId = row['id'] as int?;
        await supabase.from('advances').update({'treasury_tx_id': txId}).eq('id', advanceId);
      } else {
        await supabase
            .from('treasury_transactions')
            .update({'amount': base})
            .eq('id', txId);
      }

      if (extra > 0) {
        if (txExtraId == null) {
          final row = await supabase
              .from('treasury_transactions')
              .insert({
                'type': 'trip_expense',
                'amount': extra,
                'description': 'تكملة عهدة السائق $driverName — فرق صرف (معرّف #$advanceId)',
              })
              .select('id')
              .single();
          txExtraId = row['id'] as int?;
          await supabase
              .from('advances')
              .update({'treasury_tx_extra_id': txExtraId})
              .eq('id', advanceId);
        } else {
          await supabase
              .from('treasury_transactions')
              .update({'amount': extra})
              .eq('id', txExtraId);
        }
      } else if (txExtraId != null) {
        await _deleteTreasuryTransaction(txExtraId);
        await supabase
            .from('advances')
            .update({'treasury_tx_extra_id': null})
            .eq('id', advanceId);
      }
    } catch (e) {
      debugPrint('Error syncing advance treasury: $e');
      rethrow;
    }
  }

  Future<String> _driverNameById(int driverId) async {
    try {
      final row =
          await supabase.from('drivers').select('name').eq('id', driverId).maybeSingle();
      return row?['name']?.toString() ?? 'بدون سائق';
    } catch (_) {
      return 'بدون سائق';
    }
  }

  Future<void> _deleteTreasuryTransaction(int id) async {
    try {
      await supabase.from('treasury_transactions').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting treasury transaction: $e');
      rethrow;
    }
  }

  // Notifications (Realtime)
  /// Insert a single notification targeted at [userId] (or a broadcast to
  /// everyone when [userId] is null).
  Future<void> insertNotification({
    required String title,
    required String message,
    String? userId,
  }) async {
    try {
      await supabase.from('notifications').insert({
        if (userId != null) 'user_id': userId,
        'title': title,
        'message': message,
      });
    } catch (e) {
      debugPrint('Error inserting notification: $e');
    }
  }

  /// Notify every admin (owner) with a notification.
  Future<void> notifyAdmins({
    required String title,
    required String message,
  }) async {
    try {
      final users = await getUsers();
      final adminIds = users
          .where((u) => (u['role']?.toString() ?? '') == 'admin')
          .map((u) => u['id']?.toString())
          .whereType<String>()
          .toList();
      if (adminIds.isEmpty) return;
      await supabase.from('notifications').insert(
        adminIds
            .map((id) => {
                  'user_id': id,
                  'title': title,
                  'message': message,
                })
            .toList(),
      );
    } catch (e) {
      debugPrint('Error notifying admins: $e');
    }
  }

  /// Realtime stream of notifications visible to the current user (their own
  /// targeted rows plus broadcasts). RLS already restricts visibility.
  Stream<List<Map<String, dynamic>>> watchNotifications() {
    return supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .order('created_at');
  }

  /// Realtime stream of all trucks and their current positions.
  Stream<List<Map<String, dynamic>>> watchTrucks() {
    return supabase
        .from('trucks')
        .stream(primaryKey: ['id'])
        .order('id');
  }

  /// Build the owner's tracking/statistics dashboard.
  ///
  /// Computes:
  ///  - [treasury_balance]: current cash in the secretary's box (treasury).
  ///  - [money_on_road]: total cash currently with drivers (sum of pending
  ///    advances' outstanding amount given - returned), plus a per-driver split.
  ///  - [truck_expenses]: actual trip spending (amount_spent of settled advances)
  ///    aggregated by each driver's default truck, filtered by [period]
  ///    ('all' | 'week' | 'month') on date_out.
  Future<Map<String, dynamic>> getOwnerDashboard({String period = 'all'}) async {
    try {
      await _requireAdmin();
      final advances = await getAdvances();
      final drivers = await getDrivers();
      final trucks = await getTrucks();
      final treasuryBalance = await getTreasuryBalance();

      final driverName = <int, String>{};
      final driverTruck = <int, int>{};
      for (final d in drivers) {
        final id = d['id'] as int?;
        if (id == null) continue;
        driverName[id] = d['name']?.toString() ?? 'بدون اسم';
        final t = d['default_truck_id'];
        if (t != null) {
          driverTruck[id] = t is int ? t : int.tryParse(t.toString()) ?? -1;
        }
      }

      final truckPlate = <int, String>{};
      for (final t in trucks) {
        final id = t['id'] as int?;
        if (id != null) truckPlate[id] = t['plate']?.toString() ?? t['plate_number']?.toString() ?? 'بدون لوحة';
      }

      DateTime? from;
      final now = DateTime.now();
      if (period == 'week') {
        from = now.subtract(const Duration(days: 7));
      } else if (period == 'month') {
        from = DateTime(now.year, now.month - 1, now.day);
      }

      double moneyOnRoad = 0.0;
      final onRoadByDriver = <int, double>{};
      final truckExpenses = <int, double>{};
      int pendingCount = 0;

      for (final a in advances) {
        final status = a['status']?.toString() ?? 'pending';
        final given = (a['amount_given'] as num?)?.toDouble() ?? 0.0;
        final returned = (a['amount_returned'] as num?)?.toDouble() ?? 0.0;
        final spent = (a['amount_spent'] as num?)?.toDouble() ?? 0.0;
        final driverId = a['driver_id'] as int?;
        final dateOut = a['date_out']?.toString() ?? '';

        var inPeriod = true;
        if (from != null && dateOut.isNotEmpty) {
          final dt = DateTime.tryParse(dateOut);
          if (dt != null) inPeriod = !dt.isBefore(from);
        }

        if (status == 'pending') {
          final outstanding = given - returned;
          moneyOnRoad += outstanding;
          if (driverId != null) {
            onRoadByDriver[driverId] = (onRoadByDriver[driverId] ?? 0) + outstanding;
          }
          pendingCount++;
        }

        if (inPeriod && status == 'settled') {
          final t = driverTruck[driverId];
          if (t != null && t != -1) {
            truckExpenses[t] = (truckExpenses[t] ?? 0) + spent;
          }
        }
      }

      final onRoadList = onRoadByDriver.entries
          .map((e) => {
                'driver_id': e.key,
                'driver_name': driverName[e.key] ?? 'بدون اسم',
                'amount': e.value,
              })
          .toList()
        ..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

      final truckExpenseList = truckExpenses.entries
          .map((e) => {
                'truck_id': e.key,
                'truck_plate': truckPlate[e.key] ?? 'بدون لوحة',
                'amount': e.value,
              })
          .toList()
        ..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

      return {
        'treasury_balance': treasuryBalance,
        'money_on_road': moneyOnRoad,
        'pending_count': pendingCount,
        'on_road_by_driver': onRoadList,
        'truck_expenses': truckExpenseList,
      };
    } catch (e) {
      debugPrint('Error building owner dashboard: $e');
      return {
        'treasury_balance': 0.0,
        'money_on_road': 0.0,
        'pending_count': 0,
        'on_road_by_driver': <Map<String, dynamic>>[],
        'truck_expenses': <Map<String, dynamic>>[],
      };
    }
  }

  /// Upload a receipt image to the public 'receipts' storage bucket and return
  /// its public URL so it can be stored in advances.receipts_images.
  Future<String> uploadReceipt(String fileName, List<int> bytes) async {
    final fileExt = fileName.contains('.') ? fileName.split('.').last : 'jpg';
    final path = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    await supabase.storage.from('receipts').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(contentType: 'image/*', upsert: true),
        );
    return supabase.storage.from('receipts').getPublicUrl(path);
  }

  Future<void> saveDriverSalary({
    required String driverId,
    required int month,
    required int year,
    required double totalSalary,
    required double baseSalary,
    required double bonusAmount,
    required int completedTripsCount,
  }) async {
    try {
      await _writeRow(
        (d) => supabase.from('driver_salaries').insert(d),
        {
          'driver_id': driverId,
          'month': month,
          'year': year,
          'total_salary': totalSalary,
          'base_salary': baseSalary,
          'bonus_amount': bonusAmount,
          'completed_trips_count': completedTripsCount,
        },
      );
    } catch (e) {
      debugPrint('Error saving driver salary: $e');
      rethrow;
    }
  }

  Future<String> uploadTripDocument(String fileName, List<int> bytes) async {
    try {
      final path = 'trip_documents/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await supabase.storage.from('trip_documents').uploadBinary(path, Uint8List.fromList(bytes));
      return supabase.storage.from('trip_documents').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading trip document: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTripDocuments(int tripOrderId) async {
    try {
      final response = await supabase.from('trip_documents').select().eq('trip_order_id', tripOrderId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching trip documents: $e');
      return [];
    }
  }

  Future<void> addTripOrderItem(Map<String, dynamic> data) async {
    try {
      await supabase.from('trip_order_items').insert(data);
    } catch (e) {
      debugPrint('Error adding trip order item: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addTripDocument(Map<String, dynamic> data) async {
    try {
      final response = await supabase.from('trip_documents').insert(data).select().single();
      return response;
    } catch (e) {
      debugPrint('Error adding trip document: $e');
      rethrow;
    }
  }

  Future<void> deleteTripDocument(int id) async {
    try {
      await supabase.from('trip_documents').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting trip document: $e');
      rethrow;
    }
  }

  /// Drains the offline sync queue stored in the Hive box 'offline_sync_queue'.
  ///
  /// Each entry has the shape:
  ///   {'table': 'invoices', 'operation': 'update', 'id': 123,
  ///    'data': {...}, 'localRow': {...}, 'timestamp': 1234567890}
  ///
  /// For update operations the matching `update*` method is invoked with the
  /// [localRow] so the LWW guard decides whether the write is applied. Entries
  /// that succeed are removed from the box; failures are left in place for the
  /// next sync attempt.
  Future<void> syncOfflineQueue() async {
    final Box box;
    try {
      box = Hive.box('offline_sync_queue');
    } catch (e) {
      debugPrint('offline_sync_queue box not opened: $e');
      return;
    }
    final keys = box.keys.toList();
    for (final key in keys) {
      final entry = box.get(key);
      if (entry is! Map) continue;
      final m = Map<String, dynamic>.from(entry);
      try {
        final table = m['table']?.toString();
        final operation = m['operation']?.toString();
        final id = m['id'];
        final data = (m['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        final localRowRaw = m['localRow'];
        final localRow = localRowRaw is Map
            ? localRowRaw.cast<String, dynamic>()
            : <String, dynamic>{};

        if (operation == 'update' && table != null) {
          switch (table) {
             case 'clients':
               await updateClient(Client.fromMap(data), localRow: localRow);
               break;
            case 'trip_orders':
              await updateTripOrder(id as int, data, localRow: localRow);
              break;
            case 'invoices':
              final newPaidAmount = (data['paid_amount'] as num?)?.toDouble() ?? 0.0;
              await updateInvoiceStatus(id as int, newPaidAmount, localRow: localRow);
              break;
            case 'trucks':
              await updateTruck(id as int, data, localRow: localRow);
              break;
            case 'truck_maintenance':
              await updateTruckMaintenance(id as int, data, localRow: localRow);
              break;
            case 'truck_documents':
              await updateTruckDocument(id as int, data, localRow: localRow);
              break;
            case 'advances':
              await updateAdvance(id as int, data, localRow: localRow);
              break;
            case 'users':
              final role = data['role']?.toString() ?? '';
              await updateUserRole(id as String, role, localRow: localRow);
              break;
            case 'app_settings':
              final isEnabled = data['is_enabled'] as bool? ?? false;
              final percentage = (data['percentage'] as num?)?.toDouble() ?? 0.0;
              await updateAppSettings(isEnabled, percentage, localRow: localRow);
              break;
            default:
              debugPrint('Unknown table in offline queue: $table');
              break;
          }
        }
        await box.delete(key);
      } catch (e) {
        debugPrint('Error syncing offline queue entry $key: $e');
      }
    }
  }

  Future<void> deleteDocumentCategory(int id) async {
    await supabase.from('document_categories').delete().eq('id', id);
  }

  Future<void> updateDocumentCategory(int id, Map<String, dynamic> data) async {
    await supabase.from('document_categories').update(data).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getExpenseCategories() async {
    try {
      final response = await supabase.from('expense_categories').select().order('name');
      final rows = List<Map<String, dynamic>>.from(response);
      final seen = <String>{};
      final deduped = <Map<String, dynamic>>[];
      for (final row in rows) {
        final name = row['name']?.toString() ?? '';
        if (name.isEmpty || seen.contains(name)) continue;
        seen.add(name);
        deduped.add(row);
      }
      return deduped;
    } catch (e) {
      debugPrint('Error fetching expense categories: $e');
      return [];
    }
  }

  Future<int> addExpenseCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw Exception('اسم النوع مطلوب');
    final response = await supabase.from('expense_categories').insert({'name': trimmed}).select('id').single();
    return (response['id'] as num).toInt();
  }

  Future<void> deleteExpenseCategory(int id) async {
    await supabase.from('expense_categories').delete().eq('id', id);
  }

  Future<void> updateExpenseCategory(int id, Map<String, dynamic> data) async {
    await supabase.from('expense_categories').update(data).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getProviders() async {
    try {
      final response = await supabase.from('providers').select().order('name');
      final rows = List<Map<String, dynamic>>.from(response);
      final seen = <String>{};
      final deduped = <Map<String, dynamic>>[];
      for (final row in rows) {
        final name = row['name']?.toString() ?? '';
        if (name.isEmpty || seen.contains(name)) continue;
        seen.add(name);
        deduped.add(row);
      }
      return deduped;
    } catch (e) {
      debugPrint('Error fetching providers: $e');
      return [];
    }
  }

  Future<int> addProvider(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw Exception('اسم الورشة مطلوب');
    final response = await supabase.from('providers').insert({'name': trimmed}).select('id').single();
    return (response['id'] as num).toInt();
  }

  Future<void> deleteProvider(int id) async {
    await supabase.from('providers').delete().eq('id', id);
  }

  Future<void> updateProvider(int id, Map<String, dynamic> data) async {
    await supabase.from('providers').update(data).eq('id', id);
  }

  Future<bool> isProviderInUse(int id) async {
    try {
      final provider = await supabase.from('providers').select('name').eq('id', id).maybeSingle();
      final name = provider?['name']?.toString();
      if (name == null || name.isEmpty) return false;
      final truckCount = await supabase
          .from('truck_maintenances')
          .select()
          .eq('provider_name', name)
          .limit(1);
      if ((truckCount as List).isNotEmpty) return true;
      final trailerCount = await supabase
          .from('trailer_maintenances')
          .select()
          .eq('provider_name', name)
          .limit(1);
      final oilCount = await supabase
          .from('oil_change_records')
          .select()
          .eq('provider_name', name)
          .limit(1);
      return (trailerCount as List).isNotEmpty || (oilCount as List).isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  Future<bool> isExpenseCategoryInUse(int id) async {
    try {
      final cat = await supabase.from('expense_categories').select('name').eq('id', id).maybeSingle();
      final name = cat?['name']?.toString();
      if (name == null || name.isEmpty) return false;
      final count = await supabase
          .from('truck_maintenances')
          .select()
          .eq('expense_type', name)
          .limit(1);
      if ((count as List).isNotEmpty) return true;
      final trailerCount = await supabase
          .from('trailer_maintenances')
          .select()
          .eq('expense_type', name)
          .limit(1);
      return (trailerCount as List).isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  Future<bool> isDocumentCategoryInUse(int id) async {
    try {
      final cat = await supabase.from('document_categories').select('name').eq('id', id).maybeSingle();
      final name = cat?['name']?.toString();
      if (name == null || name.isEmpty) return false;
      final truckDocs = await supabase
          .from('truck_documents')
          .select()
          .eq('type', name)
          .limit(1);
      if ((truckDocs as List).isNotEmpty) return true;
      final fleetDocs = await supabase
          .from('fleet_documents')
          .select()
          .eq('doc_type', name)
          .limit(1);
      return (fleetDocs as List).isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  Future<bool> isTruckInUse(int truckId) async {
    try {
      final tables = [
        'trip_orders',
        'truck_maintenances',
        'truck_documents',
        'advances',
        'trailer_maintenances',
        'oil_change_records'
      ];
      for (final table in tables) {
        final count = await supabase
            .from(table)
            .select()
            .eq('truck_id', truckId)
            .limit(1);
        if ((count as List).isNotEmpty) return true;
      }
      final defaultExists = await supabase
          .from('trucks')
          .select('id')
          .eq('default_trailer_id', truckId)
          .limit(1);
      if ((defaultExists as List).isNotEmpty) return true;
      return false;
    } catch (_) {
      return true;
    }
  }

  Future<bool> isTrailerInUse(int trailerId) async {
    try {
      final count = await supabase
          .from('fleet_documents')
          .select()
          .eq('entity_id', trailerId)
          .eq('entity_type', 'trailer')
          .limit(1);
      if ((count as List).isNotEmpty) return true;
      final maintCount = await supabase
          .from('trailer_maintenances')
          .select()
          .eq('trailer_id', trailerId)
          .limit(1);
      if ((maintCount as List).isNotEmpty) return true;
      final advanceCount = await supabase
          .from('advances')
          .select()
          .eq('trailer_id', trailerId)
          .limit(1);
      if ((advanceCount as List).isNotEmpty) return true;
      final tripCount = await supabase
          .from('trip_orders')
          .select()
          .eq('trailer_id', trailerId)
          .limit(1);
      if ((tripCount as List).isNotEmpty) return true;
      final defaultTruck = await supabase
          .from('trucks')
          .select('id')
          .eq('default_trailer_id', trailerId)
          .limit(1);
      return (defaultTruck as List).isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  Future<bool> isDriverInUse(int driverId) async {
    try {
      final count = await supabase
          .from('trip_orders')
          .select()
          .eq('driver_id', driverId)
          .limit(1);
      if ((count as List).isNotEmpty) return true;
      final advanceCount = await supabase
          .from('advances')
          .select()
          .eq('driver_id', driverId)
          .limit(1);
      if ((advanceCount as List).isNotEmpty) return true;
      final defaultTruck = await supabase
          .from('trucks')
          .select('id')
          .eq('default_driver_id', driverId)
          .limit(1);
      return (defaultTruck as List).isNotEmpty;
    } catch (_) {
      return true;
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

  Future<bool> isAdvanceInUse(int advanceId) async {
    try {
      final count = await supabase
          .from('payments')
          .select()
          .eq('advance_id', advanceId)
          .limit(1);
      return (count as List).isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  Future<bool> isTripOrderInUse(int orderId) async {
    try {
      final count = await supabase
          .from('payments')
          .select()
          .eq('trip_order_id', orderId)
          .limit(1);
      if ((count as List).isNotEmpty) return true;
      final childCount = await supabase
          .from('trip_orders')
          .select()
          .eq('trip_id', orderId)
          .limit(1);
      return (childCount as List).isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  Future<bool> isInvoiceInUse(int invoiceId) async {
    try {
      final count = await supabase
          .from('payment_invoice_allocations')
          .select()
          .eq('invoice_id', invoiceId)
          .limit(1);
      return (count as List).isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  Future<bool> isBankAccountInUse(String bankAccountId) async {
    try {
      final clientCount = await supabase
          .from('clients')
          .select()
          .eq('default_bank_account_id', bankAccountId)
          .limit(1);
      if ((clientCount as List).isNotEmpty) return true;
      final invoiceCount = await supabase
          .from('invoices')
          .select()
          .eq('bank_account_id', bankAccountId)
          .limit(1);
      return (invoiceCount as List).isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  Future<void> updateUserThemeMode(String userId, String mode) async {
    if (userId.isEmpty) return;
    try {
      await _writeRow(
        (d) => supabase.from('users').update(d).eq('id', userId),
        {'theme_mode': mode},
      );
    } catch (e) {
      debugPrint('Error updating theme mode for user $userId: $e');
      rethrow;
    }
  }

  // ─── Repair Invoice CRUD ────────────────────────────────────────────────

  Future<List<RepairInvoice>> getRepairInvoices({String? workshopId}) async {
    try {
      var query = supabase.from('repair_invoices').select();
      if (workshopId != null && workshopId.isNotEmpty) {
        query = query.eq('workshop_id', workshopId);
      }
      final response = await query.order('date', ascending: false);
      final rows = List<Map<String, dynamic>>.from(response);
      await _cacheRows('repair_invoices', rows);
      return rows.map((e) => RepairInvoice.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error fetching repair invoices: $e');
      return [];
    }
  }

  Future<List<RepairInvoice>> getRepairInvoicesByWorkshop(String workshopId) async {
    try {
      final response = await supabase
          .from('repair_invoices')
          .select()
          .eq('workshop_id', workshopId)
          .order('date', ascending: true);
      final rows = List<Map<String, dynamic>>.from(response);
      await _cacheRows('repair_invoices', rows);
      return rows.map((e) => RepairInvoice.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error fetching repair invoices for workshop $workshopId: $e');
      return [];
    }
  }

  Future<RepairInvoice?> getRepairInvoice(int id) async {
    try {
      final response = await supabase
          .from('repair_invoices')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response == null) return null;
      return RepairInvoice.fromMap(response);
    } catch (e) {
      debugPrint('Error fetching repair invoice $id: $e');
      return null;
    }
  }

  Future<int?> insertRepairInvoice(RepairInvoice invoice) async {
    try {
      final response = await supabase
          .from('repair_invoices')
          .insert(invoice.toMap())
          .select()
          .single();
      return response['id'] as int?;
    } catch (e) {
      debugPrint('Error inserting repair invoice: $e');
      rethrow;
    }
  }

  Future<void> updateRepairInvoice(int id, Map<String, dynamic> data) async {
    try {
      await supabase.from('repair_invoices').update(data).eq('id', id);
    } catch (e) {
      debugPrint('Error updating repair invoice $id: $e');
      rethrow;
    }
  }

  Future<void> deleteRepairInvoice(int id) async {
    try {
      await supabase.from('repair_invoices').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting repair invoice: $e');
      rethrow;
    }
  }

  Future<int?> insertDebtInvoice({
    required String workshopId,
    required String vehicleType,
    required String vehicleId,
    required String expenseType,
    required double amount,
    String? description,
    DateTime? date,
    String? invoiceNumber,
  }) async {
    try {
      final now = date ?? DateTime.now();
      final number = invoiceNumber ??
          'INV-DEBT-${now.millisecondsSinceEpoch % 10000}';
      final invoiceData = {
        'workshop_id': workshopId,
        'invoice_number': number,
        'vehicle_type': vehicleType,
        'vehicle_id': vehicleId,
        'total_amount': amount,
        'paid_amount': 0.0,
        'remaining_amount': amount,
        'status': 'unpaid',
        'date': now.toIso8601String(),
        'description': description,
      };
      final response = await supabase
          .from('repair_invoices')
          .insert(invoiceData)
          .select()
          .single();
      final invoiceId = response['id'] as int?;

      final expenseData = {
        if (vehicleType == 'truck') 'truck_id': int.tryParse(vehicleId) ?? 0
        else 'trailer_id': int.tryParse(vehicleId) ?? 0,
        'expense_type': expenseType,
        'amount': amount,
        'description': description,
        'payment_status': 'on_credit',
        'maintenance_date': now.toIso8601String(),
        'provider_name': workshopId,
      };
      if (vehicleType == 'truck') {
        await supabase.from('truck_maintenance').insert(expenseData);
      } else {
        await supabase.from('trailer_maintenance').insert(expenseData);
      }

      return invoiceId;
    } catch (e) {
      debugPrint('Error inserting debt invoice: $e');
      rethrow;
    }
  }

  // ─── Workshop Payment & FIFO Settlement ─────────────────────────────────

  /// تسجيل دفعة وتوزيعها على فواتير الورش وفق مبدأ FIFO (أقدم فاتورة أولاً).
  ///
  /// عند [mode] == 0 (تلقائي): يوزع المبلغ على جميع فواتير [workshopId]
  /// غير المدفوعة بالكامل مرتبة تصاعدياً حسب التاريخ.
  /// عند [mode] == 1 (يدوي): يوزع المبلغ فقط على الـ [invoiceIds] المحددة،
  /// وبنفس الترتيب منها (الأقدم أولاً).
  ///
  /// يُسجَّل كل توزيع في جدول [workshop_payment_allocations] للحفاظ
  /// على سجل محاسبي كامل.
  Future<void> recordWorkshopPayment({
    required String workshopId,
    required double amount,
    required String method,
    required String ref,
    required int mode, // 0 = FIFO auto, 1 = manual
    List<int>? manualInvoiceIds,
    String? vehicleType,
    String? vehicleId,
    String? note,
  }) async {
    try {
      await _requireAdmin();
      // أ) إدراج سطر في جدول workshop_payments
      final paymentResponse = await supabase
          .from('workshop_payments')
          .insert({
            'workshop_id': workshopId,
            'amount': amount,
            'method': method,
            'ref': ref,
            if (vehicleType != null) 'vehicle_type': vehicleType,
            if (vehicleId != null) 'vehicle_id': vehicleId,
            'note': note,
          })
          .select()
          .single();
      final paymentId = paymentResponse['id'] as int;

      // ب) جلب الفواتير المستهدفة
      List<Map<String, dynamic>> invoices;
      if (mode == 1 && manualInvoiceIds != null && manualInvoiceIds.isNotEmpty) {
        // وضع يدوي: نجلب فقط الفواتير المحددة مرتبة حسب التاريخ
        final response = await supabase
            .from('repair_invoices')
            .select()
            .inFilter('id', manualInvoiceIds)
            .neq('status', 'paid')
            .order('date', ascending: true);
        invoices = List<Map<String, dynamic>>.from(response);
      } else {
        // وضع تلقائي (FIFO): نجلب كل الفواتير غير المدفوعة بالكامل
        final response = await supabase
            .from('repair_invoices')
            .select()
            .eq('workshop_id', workshopId)
            .neq('status', 'paid')
            .order('date', ascending: true);
        invoices = List<Map<String, dynamic>>.from(response);
      }

      if (invoices.isEmpty) return;

      double remainingPayment = amount;

      // ج) حلقة FIFO لتوزيع المبلغ
      for (final invoice in invoices) {
        if (remainingPayment <= 0) break;

        final invoiceId = invoice['id'] as int;
        final totalAmount = (invoice['total_amount'] as num?)?.toDouble() ?? 0.0;
        final currentPaid = (invoice['paid_amount'] as num?)?.toDouble() ?? 0.0;
        final remainingToClose = totalAmount - currentPaid;

        if (remainingToClose <= 0) continue;

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

        // تحديث الفاتورة
        await supabase
            .from('repair_invoices')
            .update({
              'paid_amount': newPaidAmount,
              'status': newStatus,
            })
            .eq('id', invoiceId);

        // تسجيل تفاصيل التوزيع
        await supabase
            .from('workshop_payment_allocations')
            .insert({
              'payment_id': paymentId,
              'repair_invoice_id': invoiceId,
              'allocated_amount': allocatedAmount,
            });
      }
    } catch (e) {
      debugPrint('Error recording workshop payment: $e');
      rethrow;
    }
  }

  /// يُرجع فواتير الورش غير المدفوعة بالكامل مرتبة تصاعدياً حسب التاريخ.
  Future<List<RepairInvoice>> getOutstandingRepairInvoices(String workshopId) async {
    try {
      final response = await supabase
          .from('repair_invoices')
          .select()
          .eq('workshop_id', workshopId)
          .neq('status', 'paid')
          .order('date', ascending: true);
      final rows = List<Map<String, dynamic>>.from(response);
      return rows.map((e) => RepairInvoice.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error fetching outstanding repair invoices: $e');
      return [];
    }
  }

  /// يُرجع جميع فواتير الورش مع رصيد متبقي لكل ورشة.
  Future<List<Map<String, dynamic>>> getWorkshopDebtSummary() async {
    try {
      final response = await supabase
          .from('repair_invoices')
          .select('workshop_id, total_amount, paid_amount, remaining_amount, status');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching workshop debt summary: $e');
      return [];
    }
  }

}
