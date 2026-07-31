import 'package:flutter/foundation.dart';
import 'package:decimal/decimal.dart';
import 'package:international_transport_app/services/base_supabase_service.dart';

class AdvanceService extends BaseSupabaseService {

  Future<String?> _driverNameById(int driverId) async {
    try {
      final row = await supabase.from('drivers').select('name').eq('id', driverId).maybeSingle();
      return row?['name']?.toString() ?? 'بدون سائق';
    } catch (_) {
      return 'بدون سائق';
    }
  }

  // Advances CRUD
  Future<List<Map<String, dynamic>>> getAdvances() async {
    try {
      final response = await supabase.from('advances').select().order('created_at', ascending: false);
      final advances = List<Map<String, dynamic>>.from(response);
      await cacheRows('advances', advances);
      return advances;
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
          .eq('driver_id', driverId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching advances by driver: $e');
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

  Future<void> addAdvance(Map<String, dynamic> data) async {
    await writeRow((d) => supabase.from('advances').insert(d), data);
  }

  Future<void> addProduct(Map<String, dynamic> data) async {
    await writeRow((d) => supabase.from('advance_products').insert(d), data);
  }

  Future<void> addTripOrder(Map<String, dynamic> data) async {
    await writeRow((d) => supabase.from('trip_orders').insert(d), data);
  }

  Future<List<Map<String, dynamic>>> getTripOrders() async {
    try {
      final response = await supabase.from('trip_orders').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
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

  Future<void> updateTripOrder(int id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    try {
      if (localRow == null) {
        await supabase.from('trip_orders').update(data).eq('id', id);
        return;
      }
      await updateWithLww(() => supabase.from('trip_orders').update(data).eq('id', id), 'trip_orders', localRow);
    } catch (e) {
      debugPrint('Error updating trip order: $e');
      rethrow;
    }
  }

  Future<void> deleteTripOrder(int id) async {
    try {
      await supabase.from('trip_orders').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting trip order: $e');
      rethrow;
    }
  }

  Future<int> createAdvanceReturning(Map<String, dynamic> data) async {
    try {
      final response = await supabase.from('advances').insert(data).select('id').single();
      return response['id'] as int;
    } catch (e) {
      debugPrint('Error creating advance returning: $e');
      rethrow;
    }
  }

  Future<void> updateAdvance(int id, Map<String, dynamic> data, {Map<String, dynamic>? localRow}) async {
    if (localRow == null) {
      await writeRow((d) => supabase.from('advances').update(d).eq('id', id), data);
      return;
    }
    await updateWithLww(() => writeRow((d) => supabase.from('advances').update(d).eq('id', id), data), 'advances', localRow);
  }

  Future<void> deleteAdvance(int id) async {
    try { await supabase.from('advances').delete().eq('id', id); } catch (e) { debugPrint('Error deleting advance: $e'); rethrow; }
  }

  Future<void> restoreAdvance(int id) async {
    try { await supabase.from('advances').update({'is_deleted': false}).eq('id', id); } catch (e) { debugPrint('Error restoring advance: $e'); rethrow; }
  }

  Future<void> syncAdvanceTreasury(int advanceId, String action) async {
    try {
      final advance = await supabase.from('advances').select().eq('id', advanceId).maybeSingle();
      if (advance == null) return;

      final driverId = advance['driver_id'] as int?;
      final amount = (advance['amount_given'] is Decimal ? (advance['amount_given'] as Decimal).toDouble() : (advance['amount_given'] as num?)?.toDouble()) ?? 0.0;
      final currency = (advance['currency']?.toString() ?? 'MAD');
      final status = advance['status']?.toString() ?? '';

      if (action == 'create' && status == 'active') {
        await supabase.from('treasury_transactions').insert({
          'amount': amount,
          'type': 'trip_expense',
          'description': 'تسليم عهدة للسائق ${driverId != null ? await _driverNameById(driverId) : ''}',
          'currency': currency,
          'cash_box_id': 1,
        });
      }
    } catch (e) {
      debugPrint('Error syncing advance treasury: $e');
    }
  }

  Future<void> notifyAdmins({required String title, required String message}) async {
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

  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final response = await supabase.from('users').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching users: $e');
      return [];
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

  Future<List<Map<String, dynamic>>> getAdvancesByIds(List<int> ids) async {
    try {
      if (ids.isEmpty) return [];
      final response = await supabase.from('advances').select().inFilter('id', ids);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching advances by ids: $e');
      return [];
    }
  }

  // Expense types
  Future<List<String>> getExpenseTypes() async {
    try {
      final response = await supabase.from('truck_maintenance').select('expense_type').order('expense_type');
      final raw = List<Map<String, dynamic>>.from(response);
      final types = <String>{};
      for (final row in raw) {
        final value = row['expense_type']?.toString();
        if (value != null && value.isNotEmpty) types.add(value);
      }
      return types.toList()..sort();
    } catch (e) {
      debugPrint('Error fetching expense types: $e');
      return [];
    }
  }

  // Dashboard & notifications
  Future<List<Map<String, dynamic>>> getTodaysActivities() async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final activities = <Map<String, dynamic>>[];

      final dueInvoices = await supabase
          .from('invoices')
          .select()
          .lte('due_date', today)
          .neq('status', 'paid');
      activities.addAll(List<Map<String, dynamic>>.from(dueInvoices).map((i) => {...i, '_type': 'invoice'}));

      final expiringDocs = await supabase
          .from('fleet_documents')
          .select()
          .lte('expiry_date', today);
      activities.addAll(List<Map<String, dynamic>>.from(expiringDocs).map((d) => {...d, '_type': 'document'}));

      final dueMaintenance = await supabase
          .from('maintenance_schedule')
          .select()
          .eq('is_deleted', false)
          .neq('status', 'completed')
          .lte('scheduled_date', today);
      activities.addAll(List<Map<String, dynamic>>.from(dueMaintenance).map((m) => {...m, '_type': 'maintenance'}));

      activities.sort((a, b) {
        final aDate = (a['due_date'] ?? a['expiry_date'] ?? a['scheduled_date'] ?? '')?.toString() ?? '';
        final bDate = (b['due_date'] ?? b['expiry_date'] ?? b['scheduled_date'] ?? '')?.toString() ?? '';
        return bDate.compareTo(aDate);
      });

      return activities;
    } catch (e) {
      debugPrint('Error fetching todays activities: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPendingNotifications() async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final notifications = <Map<String, dynamic>>[];

      final overdueInvoices = await supabase
          .from('invoices')
          .select()
          .lte('due_date', today)
          .neq('status', 'paid');
      for (final invoice in overdueInvoices) {
        notifications.add({
          'id': 'invoice_${invoice['id']}',
          'type': 'overdue_invoice',
          'title': 'فاتورة متأخرة',
          'message': 'الفاتورة ${invoice['invoice_number']} مستحقة الدفع',
          'date': invoice['due_date'],
          'priority': 'high',
        });
      }

      final expiringDocs = await supabase
          .from('fleet_documents')
          .select()
          .lte('expiry_date', today);
      for (final doc in expiringDocs) {
        notifications.add({
          'id': 'doc_${doc['id']}',
          'type': 'expiring_document',
          'title': 'وثيقة منتهية الصلاحية',
          'message': 'وثيقة ${doc['doc_type']} منتهية الصلاحية',
          'date': doc['expiry_date'],
          'priority': 'high',
        });
      }

      final oilAlerts = await getOilChangeAlerts();
      for (final alert in oilAlerts) {
        notifications.add({
          'id': 'oil_${alert['id']}',
          'type': 'oil_change',
          'title': 'تنبيه تغيير زيت',
          'message': 'الشاحنة ${alert['plate_number']} تحتاج لتغيير الزيت',
          'date': DateTime.now().toIso8601String().split('T').first,
          'priority': 'medium',
        });
      }

      notifications.sort((a, b) {
        final priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
        return (priorityOrder[a['priority']] ?? 3).compareTo(priorityOrder[b['priority']] ?? 3);
      });

      return notifications;
    } catch (e) {
      debugPrint('Error fetching pending notifications: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getOilChangeAlerts() async {
    try {
      final response = await supabase.from('trucks').select().gt('oil_change_km', 0).order('current_km', ascending: true);
      final trucks = List<Map<String, dynamic>>.from(response);
      final alerts = <Map<String, dynamic>>[];
      for (final truck in trucks) {
        final currentKm = (truck['current_km'] as num?)?.toDouble() ?? 0;
        final oilChangeKm = (truck['oil_change_km'] as num?)?.toDouble() ?? 0;
        if (oilChangeKm > 0 && currentKm >= oilChangeKm * 0.9) {
          alerts.add({...truck, 'km_remaining': oilChangeKm - currentKm, 'percentage': (currentKm / oilChangeKm * 100).toInt()});
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
      final response = await supabase.from('truck_maintenance').select().eq('expense_type', 'oil_change').order('created_at', ascending: false);
      final records = List<Map<String, dynamic>>.from(response);
      await cacheRows('truck_maintenance_oil', records);
      return records;
    } catch (e) {
      debugPrint('Error fetching oil change records: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getOilChangeRecordsByTruck(int truckId) async {
    try {
      final response = await supabase.from('truck_maintenance').select().eq('truck_id', truckId).eq('expense_type', 'oil_change').order('created_at', ascending: false);
      final records = List<Map<String, dynamic>>.from(response);
      await cacheRows('truck_maintenance_oil', records);
      return records;
    } catch (e) {
      debugPrint('Error fetching oil change records by truck: $e');
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> watchNotifications() {
    return supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .order('created_at');
  }

  Future<bool> isTripOrderInUse(int orderId) async {
    try {
      final count = await supabase.from('trip_orders').select('id').eq('id', orderId).limit(1);
      return (count as List).isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  Future<List<Map<String, dynamic>>> getTripDocuments(int tripOrderId) async {
    try {
      final response = await supabase.from('trip_documents').select().eq('trip_order_id', tripOrderId).order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching trip documents: $e');
      return [];
    }
  }

  Future<void> addTripDocument(Map<String, dynamic> data) async {
    try { await supabase.from('trip_documents').insert(data); } catch (e) { debugPrint('Error adding trip document: $e'); rethrow; }
  }

  Future<void> deleteTripDocument(int id) async {
    try { await supabase.from('trip_documents').delete().eq('id', id); } catch (e) { debugPrint('Error deleting trip document: $e'); rethrow; }
  }

  Future<String> uploadTripDocument(String fileName, List<int> bytes) async {
    try {
      final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = 'trip_docs/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await supabase.storage.from('trip_docs').uploadBinary(path, Uint8List.fromList(bytes));
      return supabase.storage.from('trip_docs').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading trip document: $e');
      rethrow;
    }
  }

  Future<void> addTripOrderItem(Map<String, dynamic> data) async {
    try { await supabase.from('trip_order_items').insert(data); } catch (e) { debugPrint('Error adding trip order item: $e'); rethrow; }
  }

  Future<List<Map<String, dynamic>>> getTripOrdersPage({int offset = 0, int limit = 20}) async {
    try {
      final response = await supabase.from('trip_orders').select().order('created_at', ascending: false).range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching trip orders page: $e');
      return [];
    }
  }
}

