part of 'advanced_dashboard_cubit.dart';

class AdvancedDashboardState {
  final bool isLoading;
  final String? errorMessage;
  final double totalRevenue;
  final double totalExpenses;
  final double netProfit;
  final double outstandingInvoices;
  final double paidInvoices;
  final double partiallyPaidInvoices;
  final double unpaidInvoices;
  final double totalExpensesMAD;
  final double totalExpensesEUR;
  final List<Map<String, dynamic>> monthlyRevenue;
  final List<Map<String, dynamic>> monthlyExpenses;
  final List<Map<String, dynamic>> expensesByCategory;
  final List<Map<String, dynamic>> invoicesByStatus;
  final List<Map<String, dynamic>> tripsByMonth;

  const AdvancedDashboardState({
    this.isLoading = true,
    this.errorMessage,
    this.totalRevenue = 0.0,
    this.totalExpenses = 0.0,
    this.netProfit = 0.0,
    this.outstandingInvoices = 0.0,
    this.paidInvoices = 0.0,
    this.partiallyPaidInvoices = 0.0,
    this.unpaidInvoices = 0.0,
    this.totalExpensesMAD = 0.0,
    this.totalExpensesEUR = 0.0,
    this.monthlyRevenue = const [],
    this.monthlyExpenses = const [],
    this.expensesByCategory = const [],
    this.invoicesByStatus = const [],
    this.tripsByMonth = const [],
  });

  AdvancedDashboardState copyWith({
    bool? isLoading,
    String? errorMessage,
    double? totalRevenue,
    double? totalExpenses,
    double? netProfit,
    double? outstandingInvoices,
    double? paidInvoices,
    double? partiallyPaidInvoices,
    double? unpaidInvoices,
    double? totalExpensesMAD,
    double? totalExpensesEUR,
    List<Map<String, dynamic>>? monthlyRevenue,
    List<Map<String, dynamic>>? monthlyExpenses,
    List<Map<String, dynamic>>? expensesByCategory,
    List<Map<String, dynamic>>? invoicesByStatus,
    List<Map<String, dynamic>>? tripsByMonth,
  }) {
    return AdvancedDashboardState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      netProfit: netProfit ?? this.netProfit,
      outstandingInvoices: outstandingInvoices ?? this.outstandingInvoices,
      paidInvoices: paidInvoices ?? this.paidInvoices,
      partiallyPaidInvoices: partiallyPaidInvoices ?? this.partiallyPaidInvoices,
      unpaidInvoices: unpaidInvoices ?? this.unpaidInvoices,
      totalExpensesMAD: totalExpensesMAD ?? this.totalExpensesMAD,
      totalExpensesEUR: totalExpensesEUR ?? this.totalExpensesEUR,
      monthlyRevenue: monthlyRevenue ?? this.monthlyRevenue,
      monthlyExpenses: monthlyExpenses ?? this.monthlyExpenses,
      expensesByCategory: expensesByCategory ?? this.expensesByCategory,
      invoicesByStatus: invoicesByStatus ?? this.invoicesByStatus,
      tripsByMonth: tripsByMonth ?? this.tripsByMonth,
    );
  }
}