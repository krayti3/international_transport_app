import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/sync_service.dart';

class WorkshopService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
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
            debugPrint('WorkshopService: stripping unknown column "$column" from update (PGRST204)');
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

  // Intervention Orders CRUD
  Future<List<Map<String, dynamic>>> getInterventionOrders() async {
    try {
      final response = await supabase.from('intervention_orders').select().order('created_at', ascending: false);
      final orders = List<Map<String, dynamic>>.from(response);
      await _cacheRows('intervention_orders', orders);
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
    try { await _writeRow((d) => supabase.from('intervention_orders').update(d).eq('id', id), data); } catch (e) { debugPrint('Error updating intervention order: $e'); rethrow; }
  }

  Future<void> deleteInterventionOrder(int id) async {
    try { await supabase.from('intervention_orders').delete().eq('id', id); } catch (e) { debugPrint('Error deleting intervention order: $e'); rethrow; }
  }

  // Suppliers CRUD
  Future<List<Map<String, dynamic>>> getSuppliers() async {
    try {
      final response = await supabase.from('suppliers').select().order('name', ascending: true);
      final suppliers = List<Map<String, dynamic>>.from(response);
      await _cacheRows('suppliers', suppliers);
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
    try { await _writeRow((d) => supabase.from('suppliers').update(d).eq('id', id), data); } catch (e) { debugPrint('Error updating supplier: $e'); rethrow; }
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
    try { await _writeRow((d) => supabase.from('purchase_orders').update(d).eq('id', id), data); } catch (e) { debugPrint('Error updating purchase order: $e'); rethrow; }
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
    try { await _writeRow((d) => supabase.from('workshop_expenses').update(d).eq('id', id), data); } catch (e) { debugPrint('Error updating workshop expense: $e'); rethrow; }
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
}
