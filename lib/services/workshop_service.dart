import 'package:flutter/foundation.dart';
import 'package:international_transport_app/models/repair_invoice.dart';
import 'package:international_transport_app/services/base_supabase_service.dart';

class WorkshopService extends BaseSupabaseService {

  // Intervention Orders CRUD
  Future<List<Map<String, dynamic>>> getInterventionOrders() async {
    try {
      final response = await supabase.from('intervention_orders').select().order('created_at', ascending: false);
      final orders = List<Map<String, dynamic>>.from(response);
      await cacheRows('intervention_orders', orders);
      return orders;
    } catch (e) {
      debugPrint('Error fetching intervention orders: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getInterventionOrdersByTruck(int truckId) async {
    try {
      final response = await supabase.from('intervention_orders').select().eq('truck_id', truckId).order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching intervention orders by truck: $e');
      return [];
    }
  }

  Future<int?> createInterventionOrder(Map<String, dynamic> data) async {
    try {
      final response = await supabase.from('intervention_orders').insert(data).select('id').single();
      return response['id'] as int?;
    } catch (e) {
      debugPrint('Error creating intervention order: $e');
      rethrow;
    }
  }

  Future<void> updateInterventionOrder(int id, Map<String, dynamic> data) async {
    try { await writeRow((d) => supabase.from('intervention_orders').update(d).eq('id', id), data); } catch (e) { debugPrint('Error updating intervention order: $e'); rethrow; }
  }

  Future<void> deleteInterventionOrder(int id) async {
    try { await supabase.from('intervention_orders').delete().eq('id', id); } catch (e) { debugPrint('Error deleting intervention order: $e'); rethrow; }
  }

  // Suppliers CRUD
  Future<List<Map<String, dynamic>>> getSuppliers() async {
    try {
      final response = await supabase.from('suppliers').select().order('name', ascending: true);
      final suppliers = List<Map<String, dynamic>>.from(response);
      await cacheRows('suppliers', suppliers);
      return suppliers;
    } catch (e) {
      debugPrint('Error fetching suppliers: $e');
      return [];
    }
  }

  Future<int?> addSupplier(Map<String, dynamic> data) async {
    try {
      final response = await supabase.from('suppliers').insert(data).select('id').single();
      return response['id'] as int?;
    } catch (e) {
      debugPrint('Error adding supplier: $e');
      rethrow;
    }
  }

  Future<void> updateSupplier(int id, Map<String, dynamic> data) async {
    try { await writeRow((d) => supabase.from('suppliers').update(d).eq('id', id), data); } catch (e) { debugPrint('Error updating supplier: $e'); rethrow; }
  }

  Future<void> deleteSupplier(int id) async {
    try { await supabase.from('suppliers').delete().eq('id', id); } catch (e) { debugPrint('Error deleting supplier: $e'); rethrow; }
  }

  // Purchase Orders CRUD
  Future<List<Map<String, dynamic>>> getPurchaseOrders() async {
    try {
      final response = await supabase.from('purchase_orders').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching purchase orders: $e');
      return [];
    }
  }

  Future<int?> createPurchaseOrder(Map<String, dynamic> data) async {
    try {
      final response = await supabase.from('purchase_orders').insert(data).select('id').single();
      return response['id'] as int?;
    } catch (e) {
      debugPrint('Error creating purchase order: $e');
      rethrow;
    }
  }

  Future<void> updatePurchaseOrder(int id, Map<String, dynamic> data) async {
    try { await writeRow((d) => supabase.from('purchase_orders').update(d).eq('id', id), data); } catch (e) { debugPrint('Error updating purchase order: $e'); rethrow; }
  }

  Future<void> deletePurchaseOrder(int id) async {
    try { await supabase.from('purchase_orders').delete().eq('id', id); } catch (e) { debugPrint('Error deleting purchase order: $e'); rethrow; }
  }

  // Workshop Expenses CRUD
  Future<List<Map<String, dynamic>>> getWorkshopExpenses() async {
    try {
      final response = await supabase.from('workshop_expenses').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching workshop expenses: $e');
      return [];
    }
  }

  Future<int?> createWorkshopExpense(Map<String, dynamic> data) async {
    try {
      final response = await supabase.from('workshop_expenses').insert(data).select('id').single();
      return response['id'] as int?;
    } catch (e) {
      debugPrint('Error creating workshop expense: $e');
      rethrow;
    }
  }

  Future<void> updateWorkshopExpense(int id, Map<String, dynamic> data) async {
    try { await writeRow((d) => supabase.from('workshop_expenses').update(d).eq('id', id), data); } catch (e) { debugPrint('Error updating workshop expense: $e'); rethrow; }
  }

  Future<void> deleteWorkshopExpense(int id) async {
    try { await supabase.from('workshop_expenses').delete().eq('id', id); } catch (e) { debugPrint('Error deleting workshop expense: $e'); rethrow; }
  }

  Future<Map<String, double>> getWorkshopTotals() async {
    try {
      final response = await supabase.from('workshop_expenses').select('amount');
      final rows = List<Map<String, dynamic>>.from(response);
      double total = 0.0;
      for (final row in rows) {
        total += (row['amount'] as num?)?.toDouble() ?? 0.0;
      }
      return {'total': total};
    } catch (e) {
      debugPrint('Error calculating workshop totals: $e');
      return {'total': 0.0};
    }
  }

  Future<List<Map<String, dynamic>>> getProviders() async {
    try {
      final response = await supabase.from('providers').select().order('name', ascending: true);
      final providers = List<Map<String, dynamic>>.from(response);
      await cacheRows('providers', providers);
      return providers;
    } catch (e) {
      debugPrint('Error fetching providers: $e');
      return [];
    }
  }

  Future<void> addProvider(Map<String, dynamic> data) async {
    try { await supabase.from('providers').insert(data); } catch (e) { debugPrint('Error adding provider: $e'); rethrow; }
  }

  Future<void> updateProvider(int id, Map<String, dynamic> data) async {
    try { await writeRow((d) => supabase.from('providers').update(d).eq('id', id), data); } catch (e) { debugPrint('Error updating provider: $e'); rethrow; }
  }

  Future<void> deleteProvider(int id) async {
    try { await supabase.from('providers').delete().eq('id', id); } catch (e) { debugPrint('Error deleting provider: $e'); rethrow; }
  }

  Future<bool> isProviderInUse(int id) async {
    try {
      final count = await supabase.from('workshop_expenses').select().eq('provider_id', id).limit(1);
      return (count as List).isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  Future<List<String>> getExpenseTypes() async {
    try {
      final response = await supabase.from('expense_types').select('name').order('name', ascending: true);
      final rows = List<Map<String, dynamic>>.from(response);
      return rows.map((r) => r['name']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    } catch (e) {
      debugPrint('Error fetching expense types: $e');
      return [];
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
      final data = <String, dynamic>{
        'provider_id': workshopId,
        'vehicle_type': vehicleType,
        'vehicle_id': vehicleId,
        'expense_type': expenseType,
        'amount': amount,
        'description': description,
        'date': date?.toIso8601String(),
        'invoice_number': invoiceNumber,
        'status': 'unpaid',
        'payment_status': 'unpaid',
      };
      final response = await supabase.from('workshop_expenses').insert(data).select('id').single();
      return response['id'] as int?;
    } catch (e) {
      debugPrint('Error inserting debt invoice: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getExpenseCategories() async {
    try {
      final response = await supabase.from('expense_categories').select().order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching expense categories: $e');
      return [];
    }
  }

  Future<int> addExpenseCategory(String name) async {
    try {
      final response = await supabase.from('expense_categories').insert({'name': name}).select('id').single();
      return response['id'] as int;
    } catch (e) {
      debugPrint('Error adding expense category: $e');
      rethrow;
    }
  }

  Future<void> updateExpenseCategory(int id, Map<String, dynamic> data) async {
    try { await supabase.from('expense_categories').update(data).eq('id', id); } catch (e) { debugPrint('Error updating expense category: $e'); rethrow; }
  }

  Future<void> deleteExpenseCategory(int id) async {
    try { await supabase.from('expense_categories').delete().eq('id', id); } catch (e) { debugPrint('Error deleting expense category: $e'); rethrow; }
  }

  Future<bool> isExpenseCategoryInUse(int id) async {
    try {
      final count = await supabase.from('truck_maintenances').select('id').eq('expense_type', id.toString()).limit(1);
      if ((count as List).isNotEmpty) return true;
      final count2 = await supabase.from('trailer_maintenances').select('id').eq('expense_type', id.toString()).limit(1);
      if ((count2 as List).isNotEmpty) return true;
      return false;
    } catch (_) {
      return true;
    }
  }

  Future<List<RepairInvoice>> getRepairInvoices({String? workshopId}) async {
    try {
      var query = supabase.from('repair_invoices').select();
      if (workshopId != null) {
        query = query.eq('workshop_id', workshopId);
      }
      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response).map((e) => RepairInvoice.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error fetching repair invoices: $e');
      return [];
    }
  }

  Future<void> insertRepairInvoice(RepairInvoice invoice) async {
    try {
      await supabase.from('repair_invoices').insert(invoice.toMap());
    } catch (e) {
      debugPrint('Error inserting repair invoice: $e');
      rethrow;
    }
  }

  Future<void> updateRepairInvoice(int id, Map<String, dynamic> data) async {
    try {
      await supabase.from('repair_invoices').update(data).eq('id', id);
    } catch (e) {
      debugPrint('Error updating repair invoice: $e');
      rethrow;
    }
  }

  Future<void> recordWorkshopPayment({
    required String workshopId,
    required double amount,
    required String method,
    required String ref,
    required int mode,
    List<int>? manualInvoiceIds,
    String? vehicleType,
    String? vehicleId,
    String? note,
  }) async {
    try {
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

      List<Map<String, dynamic>> invoices;
      if (mode == 1 && manualInvoiceIds != null && manualInvoiceIds.isNotEmpty) {
        final response = await supabase
            .from('repair_invoices')
            .select()
            .inFilter('id', manualInvoiceIds)
            .neq('status', 'paid')
            .order('date', ascending: true);
        invoices = List<Map<String, dynamic>>.from(response);
      } else {
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

        await supabase
            .from('repair_invoices')
            .update({
              'paid_amount': newPaidAmount,
              'status': newStatus,
            })
            .eq('id', invoiceId);

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
}

