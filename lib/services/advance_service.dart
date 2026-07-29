import 'package:flutter/foundation.dart';
import 'package:decimal/decimal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/services/sync_service.dart';

class AdvanceService {
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
            debugPrint('AdvanceService: stripping unknown column "$column" from update (PGRST204)');
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
      await _cacheRows('advances', advances);
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
    await _writeRow((d) => supabase.from('advances').insert(d), data);
  }

  Future<void> addProduct(Map<String, dynamic> data) async {
    await _writeRow((d) => supabase.from('advance_products').insert(d), data);
  }

  Future<void> addTripOrder(Map<String, dynamic> data) async {
    await _writeRow((d) => supabase.from('trip_orders').insert(d), data);
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
      await _writeRow((d) => supabase.from('advances').update(d).eq('id', id), data);
      return;
    }
    await _updateWithLww(() => _writeRow((d) => supabase.from('advances').update(d).eq('id', id), data), 'advances', localRow);
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
      await _cacheRows('truck_maintenance_oil', records);
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
      await _cacheRows('truck_maintenance_oil', records);
      return records;
    } catch (e) {
      debugPrint('Error fetching oil change records by truck: $e');
      return [];
    }
  }
}
