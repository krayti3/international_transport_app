import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/advance_service.dart';
import '../../services/client_service.dart';
import '../../services/fleet_service.dart';
import '../../services/treasury_service.dart';
import '../../services/ai_analysis_service.dart';

part 'ai_reports_state.dart';

class AiReportsCubit extends Cubit<AiReportsState> {
  AiReportsCubit() : super(const AiReportsState()) {
    analyze();
  }

  final AdvanceService _advanceService = AdvanceService();
  final ClientService _clientService = ClientService();
  final FleetService _fleetService = FleetService();
  final TreasuryService _treasuryService = TreasuryService();

  Future<void> analyze() async {
    emit(state.copyWith(isLoading: true, errorMessage: null, isAnalyzing: true));
    try {
      final currentMonth = DateTime.now();
      final currentMonthStart = DateTime(currentMonth.year, currentMonth.month, 1);
      final currentMonthEnd =
          currentMonth.month == 12
              ? DateTime(currentMonth.year + 1, 1, 1)
              : DateTime(currentMonth.year, currentMonth.month + 1, 1);
      final previousMonthStart =
          currentMonth.month == 1
              ? DateTime(currentMonth.year - 1, 12, 1)
              : DateTime(currentMonth.year, currentMonth.month - 1, 1);
      final previousMonthEnd = currentMonthStart;

      final trips = await _advanceService.getTripOrders();
      final invoices = await _clientService.getInvoices();
      final treasuryTxs = await _treasuryService.getTreasuryTransactions();
      final maintenances = await _fleetService.getTruckMaintenances();

      double currentRevenue = 0.0;
      double currentExpenses = 0.0;
      double currentOutstanding = 0.0;
      int currentTripsThisMonth = 0;
      int currentTripsLastMonth = 0;

      for (final t in trips) {
        final depDate = DateTime.tryParse((t['departure_date'] ?? '').toString());
        if (depDate != null && depDate.isAfter(currentMonthStart.subtract(const Duration(days: 1))) && depDate.isBefore(currentMonthEnd)) {
          final price = (t['price'] as num?)?.toDouble() ?? 0.0;
          final specificExpenses = (t['specific_expenses'] as num?)?.toDouble() ?? 0.0;
          currentRevenue += (price - specificExpenses);
          currentTripsThisMonth++;
        }
        if (depDate != null && depDate.isAfter(previousMonthStart.subtract(const Duration(days: 1))) && depDate.isBefore(previousMonthEnd)) {
          currentTripsLastMonth++;
        }
      }

      for (final inv in invoices) {
        if (inv.issueDate != null && inv.issueDate!.isAfter(currentMonthStart.subtract(const Duration(days: 1))) && inv.issueDate!.isBefore(currentMonthEnd)) {
          currentRevenue += inv.totalAmount.toDouble();
          if (inv.status != 'paid') {
            currentOutstanding += inv.remainingAmount.toDouble();
          }
        }
      }

      for (final tx in treasuryTxs) {
        final txDate = DateTime.tryParse((tx['created_at'] ?? '').toString());
        if (txDate != null && txDate.isAfter(currentMonthStart.subtract(const Duration(days: 1))) && txDate.isBefore(currentMonthEnd)) {
          final type = (tx['type'] ?? '').toString();
          if (type == 'trip_expense' || type == 'office_expense' || type == 'salary') {
            currentExpenses += (tx['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }

      for (final m in maintenances) {
        final maintDate = DateTime.tryParse((m['maintenance_date'] ?? '').toString());
        if (maintDate != null && maintDate.isAfter(currentMonthStart.subtract(const Duration(days: 1))) && maintDate.isBefore(currentMonthEnd)) {
          currentExpenses += (m['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      final monthlyData = AiAnalysisService.buildMonthlyTrends(
        trips: trips,
        invoices: invoices.map((i) {
          return <String, dynamic>{'issue_date': i.issueDate?.toIso8601String() ?? '', 'total_amount': i.totalAmount.toDouble()};
        }).toList(),
        treasuryTransactions: treasuryTxs,
        maintenances: maintenances,
      );

      final profitForecast = AiAnalysisService.forecastProfit(monthlyData);

      final expensesByCategory =
          AiAnalysisService.buildExpensesByCategory(maintenances: maintenances, treasuryTransactions: treasuryTxs);

      final firstRevenue = monthlyData.isNotEmpty ? (monthlyData.first['revenue'] as double? ?? 0.0) : 0.0;
      final lastRevenue = monthlyData.isNotEmpty ? (monthlyData.last['revenue'] as double? ?? 0.0) : 0.0;
      final firstExpenses = monthlyData.isNotEmpty ? (monthlyData.first['expenses'] as double? ?? 0.0) : 0.0;
      final lastExpenses = monthlyData.isNotEmpty ? (monthlyData.last['expenses'] as double? ?? 0.0) : 0.0;
      final revenueGrowthRate = firstRevenue > 0 ? (lastRevenue - firstRevenue) / firstRevenue : 0.0;
      final expenseGrowthRate = firstExpenses > 0 ? (lastExpenses - firstExpenses) / firstExpenses : 0.0;
      final averageMonthlyProfit = monthlyData.isEmpty ? 0.0 : monthlyData.fold<double>(0.0, (sum, m) => sum + (m['profit'] as double? ?? 0.0)) / monthlyData.length;

      final insights = AiAnalysisService.generateInsights(
        monthlyData: monthlyData,
        currentRevenue: currentRevenue,
        currentExpenses: currentExpenses,
        predictedNextProfit: profitForecast.predictedProfit,
        averageMonthlyProfit: averageMonthlyProfit,
        revenueGrowthRate: revenueGrowthRate,
        expenseGrowthRate: expenseGrowthRate,
        currentTrips: currentTripsThisMonth,
        previousTrips: currentTripsLastMonth,
        expensesByCategory: expensesByCategory,
        outstandingInvoices: currentOutstanding,
      );

      final seasonality = AiAnalysisService.analyzeSeasonality(monthlyData);

      final recommendations = AiAnalysisService.generateRecommendations(
        monthlyData: monthlyData,
        expensesByCategory: expensesByCategory,
        invoices: invoices.map((i) => i.toMap()).toList(),
        outstandingInvoices: currentOutstanding,
        currentRevenue: currentRevenue,
        currentExpenses: currentExpenses,
      );

      final overallHealth = AiAnalysisService.computeOverallHealth(
        profit: currentRevenue - currentExpenses,
        revenue: currentRevenue,
        expenses: currentExpenses,
        predictedNextProfit: profitForecast.predictedProfit,
        averageMonthlyProfit: averageMonthlyProfit,
        outstandingInvoices: currentOutstanding,
        expenseGrowthRate: expenseGrowthRate,
      );

      final summary = AiReportSummary(
        profitForecast: profitForecast,
        insights: insights,
        currentMonthRevenue: currentRevenue,
        currentMonthExpenses: currentExpenses,
        currentMonthProfit: currentRevenue - currentExpenses,
        predictedNextMonthProfit: profitForecast.predictedProfit,
        averageMonthlyProfit: averageMonthlyProfit,
        expenseGrowthRate: expenseGrowthRate,
        revenueGrowthRate: revenueGrowthRate,
        totalTripsThisMonth: currentTripsThisMonth,
        totalTripsLastMonth: currentTripsLastMonth,
        overallHealthAr: overallHealth,
        seasonality: seasonality,
        recommendations: recommendations,
      );

      emit(state.copyWith(
        isLoading: false,
        isAnalyzing: false,
        summary: summary,
        hasData: true,
      ));
    } catch (e) {
      debugPrint('Error running AI analysis: $e');
      emit(state.copyWith(isLoading: false, isAnalyzing: false, errorMessage: e.toString()));
    }
  }

  Future<void> refresh() async {
    await analyze();
  }
}
