import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/models/invoice.dart';
import 'package:decimal/decimal.dart';
import 'package:international_transport_app/services/sync_service.dart';
import 'package:international_transport_app/services/client_service.dart';

class InvoiceRepository {
  final SupabaseClient supabase;
  final ClientService _clientService = ClientService();

  InvoiceRepository(this.supabase);

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  Future<List<Invoice>?> getCachedInvoices() async {
    final rows = await SyncService.instance.getAllCachedRows('invoices');
    if (rows == null) return null;
    return rows.map((e) => Invoice.fromMap(e)).toList();
  }

  Future<List<Invoice>> getInvoices() async {
    try {
      final invoices = await _clientService.getInvoices();
      await _cacheRows('invoices', invoices.map((e) => e.toMap()).toList());
      return invoices;
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
      return await _clientService.createInvoice(
        clientId: clientId,
        amount: amount,
        inputMode: inputMode,
        bankAccountId: bankAccountId,
        bankAccountType: bankAccountType,
        bankInfoText: bankInfoText,
        issueDate: issueDate,
        dueDate: dueDate,
      );
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
      await _clientService.updateInvoiceStatus(invoiceId, newPaidAmount);
    } catch (e) {
      debugPrint('Error updating invoice status: $e');
      rethrow;
    }
  }

  Future<void> addInvoicePayment(Map<String, dynamic> data) async {
    try {
      await _clientService.addInvoicePayment(data);
    } catch (e) {
      debugPrint('Error adding invoice payment: $e');
      rethrow;
    }
  }
}
