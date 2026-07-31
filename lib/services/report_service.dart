import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getUpcomingInvoices({int daysAhead = 30}) async {
    try {
      final now = DateTime.now();
      final threshold = now.add(Duration(days: daysAhead));
      final response = await supabase
          .from('invoices')
          .select()
          .neq('status', 'paid')
          .lte('due_date', threshold.toIso8601String().split('T').first)
          .order('due_date', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching upcoming invoices: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUpcomingDocumentExpiries({int daysAhead = 30}) async {
    try {
      final now = DateTime.now();
      final threshold = now.add(Duration(days: daysAhead));
      final thresholdStr = threshold.toIso8601String().split('T').first;
      final response = await supabase
          .from('fleet_documents')
          .select()
          .lte('expiry_date', thresholdStr)
          .order('expiry_date', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching upcoming document expiries: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUpcomingMaintenanceDueDates({int daysAhead = 30}) async {
    try {
      final now = DateTime.now();
      final threshold = now.add(Duration(days: daysAhead));
      final thresholdStr = threshold.toIso8601String().split('T').first;
      final response = await supabase
          .from('maintenance_schedule')
          .select()
          .eq('is_deleted', false)
          .neq('status', 'completed')
          .lte('scheduled_date', thresholdStr)
          .order('scheduled_date', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching upcoming maintenance due dates: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUpcomingVisaExpiries({int daysAhead = 30}) async {
    try {
      final now = DateTime.now();
      final threshold = now.add(Duration(days: daysAhead));
      final response = await supabase
          .from('drivers')
          .select()
          .gt('visa_expiry_date', now.toIso8601String().split('T').first)
          .lte('visa_expiry_date', threshold.toIso8601String().split('T').first)
          .order('visa_expiry_date', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching upcoming visa expiries: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCompanyFinancialReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await supabase.rpc('get_financial_summary', params: {
        'p_start_date': DateFormat('yyyy-MM-dd').format(startDate.toUtc()),
        'p_end_date':   DateFormat('yyyy-MM-dd').format(endDate.toUtc()),
      });
      if (response is Map<String, dynamic>) {
        return [response];
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching company financial report: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCompanyProfitReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await supabase.rpc('get_profit_report', params: {
        'p_start_date': DateFormat('yyyy-MM-dd').format(startDate.toUtc()),
        'p_end_date':   DateFormat('yyyy-MM-dd').format(endDate.toUtc()),
      });
      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching company profit report: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getOwnerDashboard({String period = 'all'}) async {
    try {
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate;

      switch (period) {
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          endDate = now;
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 1);
          break;
        case 'all':
        default:
          startDate = DateTime(2000);
          endDate = DateTime(2100);
          break;
      }

      final invoicesResponse = await supabase
          .from('invoices')
          .select('total_amount, paid_amount, status, issue_date')
          .gte('issue_date', startDate.toIso8601String().split('T').first)
          .lt('issue_date', endDate.toIso8601String().split('T').first);
      final invoices = List<Map<String, dynamic>>.from(invoicesResponse);

      double totalRevenue = 0.0;
      double totalPaid = 0.0;
      int pendingCount = 0;
      int paidCount = 0;

      for (final invoice in invoices) {
        final total = (invoice['total_amount'] as num?)?.toDouble() ?? 0.0;
        final paid = (invoice['paid_amount'] as num?)?.toDouble() ?? 0.0;
        final status = invoice['status']?.toString() ?? '';

        totalRevenue += total;
        totalPaid += paid;

        if (status == 'paid') {
          paidCount++;
        } else {
          pendingCount++;
        }
      }

      final trucksResponse = await supabase.from('trucks').select('id');
      final trucksCount = (trucksResponse as List).length;

      final driversResponse = await supabase.from('drivers').select('id');
      final driversCount = (driversResponse as List).length;

      final clientsResponse = await supabase.from('clients').select('id');
      final clientsCount = (clientsResponse as List).length;

      return {
        'total_revenue': totalRevenue,
        'total_paid': totalPaid,
        'pending_invoices': pendingCount,
        'paid_invoices': paidCount,
        'trucks_count': trucksCount,
        'drivers_count': driversCount,
        'clients_count': clientsCount,
        'month': period == 'all' ? 'الكل' : period == 'week' ? 'أسبوعي' : DateFormat('MMMM yyyy', 'ar_MA').format(now),
      };
    } catch (e) {
      debugPrint('Error fetching owner dashboard: $e');
      return {};
    }
  }
}