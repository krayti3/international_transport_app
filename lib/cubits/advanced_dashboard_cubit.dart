import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../models/invoice.dart';
import '../../services/advance_service.dart';
import '../../services/client_service.dart';
import '../../services/fleet_service.dart';
import '../../services/treasury_service.dart';

part 'advanced_dashboard_state.dart';

class AdvancedDashboardCubit extends Cubit<AdvancedDashboardState> {
  AdvancedDashboardCubit() : super(const AdvancedDashboardState()) {
    loadDashboardData();
  }

  final AdvanceService _advanceService = AdvanceService();
  final ClientService _clientService = ClientService();
  final FleetService _fleetService = FleetService();
  final TreasuryService _treasuryService = TreasuryService();

  Future<void> loadDashboardData() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final trips = await _advanceService.getTripOrders();
      final invoices = await _clientService.getInvoices();
      final maintenances = await _fleetService.getTruckMaintenances();
      final treasuryTxs = await _treasuryService.getTreasuryTransactions();

      double totalRevenue = 0.0;
      double totalExpenses = 0.0;
      double totalExpensesMAD = 0.0;
      double totalExpensesEUR = 0.0;
      double outstandingInvoices = 0.0;
      double paidInvoices = 0.0;
      double partiallyPaidInvoices = 0.0;
      double unpaidInvoices = 0.0;

      for (final trip in trips) {
        final price = (trip['price'] as num?)?.toDouble() ?? 0.0;
        final expenses = (trip['specific_expenses'] as num?)?.toDouble() ?? 0.0;
        totalRevenue += (price - expenses);
      }

      for (final maint in maintenances) {
        final amount = (maint['amount'] as num?)?.toDouble() ?? 0.0;
        totalExpenses += amount;
      }

      for (final tx in treasuryTxs) {
        final type = tx['type']?.toString() ?? '';
        if (type == 'trip_expense' || type == 'office_expense' || type == 'salary') {
          totalExpenses += (tx['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      for (final inv in invoices) {
        final amount = inv.totalAmount.toDouble();
        final paid = inv.paidAmount?.toDouble() ?? 0.0;
        final currency = inv.currency ?? 'MAD';
        final status = inv.status;

        if (status == 'paid') {
          paidInvoices += amount;
        } else if (status == 'partially_paid') {
          partiallyPaidInvoices += amount;
        } else {
          unpaidInvoices += amount;
        }

        if (status != 'paid') {
          outstandingInvoices += (amount - paid);
        }

        if (currency == 'EUR') {
          totalExpensesEUR += amount;
        } else {
          totalExpensesMAD += amount;
        }
      }

      final netProfit = totalRevenue - totalExpenses;

      final now = DateTime.now();
      final monthlyRevenue = _buildMonthlyRevenue(trips, now);
      final monthlyExpenses = _buildMonthlyExpenses(maintenances, treasuryTxs, now);
      final expensesByCategory = _buildExpensesByCategory(maintenances, treasuryTxs);
      final invoicesByStatus = _buildInvoicesByStatus(invoices);
      final tripsByMonth = _buildTripsByMonth(trips, now);

      emit(state.copyWith(
        isLoading: false,
        totalRevenue: totalRevenue,
        totalExpenses: totalExpenses,
        netProfit: netProfit,
        outstandingInvoices: outstandingInvoices,
        paidInvoices: paidInvoices,
        partiallyPaidInvoices: partiallyPaidInvoices,
        unpaidInvoices: unpaidInvoices,
        totalExpensesMAD: totalExpensesMAD,
        totalExpensesEUR: totalExpensesEUR,
        monthlyRevenue: monthlyRevenue,
        monthlyExpenses: monthlyExpenses,
        expensesByCategory: expensesByCategory,
        invoicesByStatus: invoicesByStatus,
        tripsByMonth: tripsByMonth,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  List<Map<String, dynamic>> _buildMonthlyRevenue(
    List<Map<String, dynamic>> trips,
    DateTime now,
  ) {
    final months = <Map<String, dynamic>>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthStart = month.toIso8601String();
      final monthEnd = (month.month == 12
              ? DateTime(month.year + 1, 1, 1)
              : DateTime(month.year, month.month + 1, 1))
          .toIso8601String();

      double revenue = 0.0;
      int count = 0;

      for (final trip in trips) {
        final depDate = trip['departure_date']?.toString() ?? '';
        if (depDate.compareTo(monthStart) >= 0 && depDate.compareTo(monthEnd) < 0) {
          count++;
          final price = (trip['price'] as num?)?.toDouble() ?? 0.0;
          final tripExpenses = (trip['specific_expenses'] as num?)?.toDouble() ?? 0.0;
          revenue += (price - tripExpenses);
        }
      }

      months.add({
        'month': DateFormat('MMM yyyy').format(month),
        'revenue': revenue,
        'count': count,
      });
    }

    return months;
  }

  List<Map<String, dynamic>> _buildMonthlyExpenses(
    List<Map<String, dynamic>> maintenances,
    List<Map<String, dynamic>> treasuryTxs,
    DateTime now,
  ) {
    final months = <Map<String, dynamic>>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthStart = month.toIso8601String();
      final monthEnd = (month.month == 12
              ? DateTime(month.year + 1, 1, 1)
              : DateTime(month.year, month.month + 1, 1))
          .toIso8601String();

      double maintenance = 0.0;
      double fuel = 0.0;
      double salary = 0.0;
      double office = 0.0;

      for (final maint in maintenances) {
        final date = maint['maintenance_date']?.toString() ?? '';
        if (date.compareTo(monthStart) >= 0 && date.compareTo(monthEnd) < 0) {
          maintenance += (maint['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      for (final tx in treasuryTxs) {
        final created = tx['created_at']?.toString() ?? '';
        final type = tx['type']?.toString() ?? '';
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;

        if (created.compareTo(monthStart) >= 0 && created.compareTo(monthEnd) < 0) {
          switch (type) {
            case 'trip_expense':
              fuel += amount;
              break;
            case 'salary':
              salary += amount;
              break;
            case 'office_expense':
              office += amount;
              break;
            default:
              break;
          }
        }
      }

      months.add({
        'month': DateFormat('MMM').format(month),
        'maintenance': maintenance,
        'fuel': fuel,
        'salary': salary,
        'office': office,
      });
    }

    return months;
  }

  List<Map<String, dynamic>> _buildExpensesByCategory(
    List<Map<String, dynamic>> maintenances,
    List<Map<String, dynamic>> treasuryTxs,
  ) {
    double maintenance = 0.0;
    double fuel = 0.0;
    double salary = 0.0;
    double office = 0.0;
    double other = 0.0;

    for (final maint in maintenances) {
      maintenance += (maint['amount'] as num?)?.toDouble() ?? 0.0;
    }

    for (final tx in treasuryTxs) {
      final type = tx['type']?.toString() ?? '';
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;

      switch (type) {
        case 'trip_expense':
          fuel += amount;
          break;
        case 'salary':
          salary += amount;
          break;
        case 'office_expense':
          office += amount;
          break;
        default:
          other += amount;
          break;
      }
    }

    return [
      {'category': 'maintenance', 'amount': maintenance, 'label': 'صيانة'},
      {'category': 'fuel', 'amount': fuel, 'label': 'وقود'},
      {'category': 'salary', 'amount': salary, 'label': 'رواتب'},
      {'category': 'office', 'amount': office, 'label': 'مصاريف مكتبية'},
      {'category': 'other', 'amount': other, 'label': 'أخرى'},
    ];
  }

  List<Map<String, dynamic>> _buildInvoicesByStatus(
    List<Invoice> invoices,
  ) {
    double paid = 0.0;
    double partiallyPaid = 0.0;
    double unpaid = 0.0;
    double madPaid = 0.0;
    double eurPaid = 0.0;
    double madPartiallyPaid = 0.0;
    double eurPartiallyPaid = 0.0;
    double madUnpaid = 0.0;
    double eurUnpaid = 0.0;

    for (final inv in invoices) {
      final amount = inv.totalAmount.toDouble();
      final currency = inv.currency ?? 'MAD';
      final status = inv.status;

      switch (status) {
        case 'paid':
          paid += amount;
          if (currency == 'EUR') {
            eurPaid += amount;
          } else {
            madPaid += amount;
          }
          break;
        case 'partially_paid':
          partiallyPaid += amount;
          if (currency == 'EUR') {
            eurPartiallyPaid += amount;
          } else {
            madPartiallyPaid += amount;
          }
          break;
        default:
          unpaid += amount;
          if (currency == 'EUR') {
            eurUnpaid += amount;
          } else {
            madUnpaid += amount;
          }
          break;
      }
    }

    return [
      {
        'status': 'paid',
        'label': 'مدفوعة',
        'amount': paid,
        'madAmount': madPaid,
        'eurAmount': eurPaid,
        'count': invoices.where((i) => i.status == 'paid').length,
      },
      {
        'status': 'partially_paid',
        'label': 'مدفوعة جزئياً',
        'amount': partiallyPaid,
        'madAmount': madPartiallyPaid,
        'eurAmount': eurPartiallyPaid,
        'count': invoices.where((i) => i.status == 'partially_paid').length,
      },
      {
        'status': 'unpaid',
        'label': 'غير مدفوعة',
        'amount': unpaid,
        'madAmount': madUnpaid,
        'eurAmount': eurUnpaid,
        'count': invoices.where((i) => i.status == 'unpaid').length,
      },
    ];
  }

  List<Map<String, dynamic>> _buildTripsByMonth(
    List<Map<String, dynamic>> trips,
    DateTime now,
  ) {
    final months = <Map<String, dynamic>>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthStart = month.toIso8601String();
      final monthEnd = (month.month == 12
              ? DateTime(month.year + 1, 1, 1)
              : DateTime(month.year, month.month + 1, 1))
          .toIso8601String();

      int count = 0;
      double revenue = 0.0;

      for (final trip in trips) {
        final depDate = trip['departure_date']?.toString() ?? '';
        if (depDate.compareTo(monthStart) >= 0 && depDate.compareTo(monthEnd) < 0) {
          count++;
          final price = (trip['price'] as num?)?.toDouble() ?? 0.0;
          final tripExpenses = (trip['specific_expenses'] as num?)?.toDouble() ?? 0.0;
          revenue += (price - tripExpenses);
        }
      }

      months.add({
        'month': DateFormat('MMM').format(month),
        'count': count,
        'revenue': revenue,
      });
    }

    return months;
  }
}