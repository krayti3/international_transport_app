import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/advanced_dashboard_cubit.dart';
import '../l10n/app_localizations.dart';
import '../services/excel_service.dart';
import '../services/pdf_service.dart';
import '../widgets/summary_card.dart';

// ignore_for_file: use_build_context_synchronously

class AdvancedDashboardScreen extends StatelessWidget {
  const AdvancedDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AdvancedDashboardCubit(),
      child: _AdvancedDashboardBody(),
    );
  }
}

class _AdvancedDashboardBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdvancedDashboardCubit, AdvancedDashboardState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<AdvancedDashboardCubit>();

        if (state.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('Ù„ÙˆØ­Ø© Ø§Ù„ØªØ­Ù„ÙŠÙ„Ø§Øª Ø§Ù„Ù…ØªÙ‚Ø¯Ù…Ø©')),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: cubit.loadDashboardData,
                tooltip: 'ØªØ­Ø¯ÙŠØ«',
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: () => _exportPdf(context, state),
                tooltip: 'ØªØµØ¯ÙŠØ± PDF',
              ),
              IconButton(
                icon: const Icon(Icons.table_chart),
                onPressed: () => _exportExcel(context, state),
                tooltip: 'ØªØµØ¯ÙŠØ± Excel',
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSummaryCards(state),
                const SizedBox(height: 16),
                _buildMonthlyChart(context, state),
                const SizedBox(height: 16),
                _buildExpenseBreakdown(context, state),
                const SizedBox(height: 16),
                _buildInvoiceStatusTable(context, state),
                const SizedBox(height: 16),
                _buildTripsChart(context, state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCards(AdvancedDashboardState state) {
    return Row(
      children: [
        Expanded(
          child: SummaryCard(
            title: 'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ø¥ÙŠØ±Ø§Ø¯Ø§Øª',
            value: '${state.totalRevenue.toStringAsFixed(2)} DH',
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SummaryCard(
            title: 'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…ØµØ§Ø±ÙŠÙ',
            value: '${state.totalExpenses.toStringAsFixed(2)} DH',
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SummaryCard(
            title: 'ØµØ§ÙÙŠ Ø§Ù„Ø±Ø¨Ø­',
            value: '${state.netProfit.toStringAsFixed(2)} DH',
            color: state.netProfit >= 0 ? Colors.green : Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SummaryCard(
            title: 'Ø§Ù„ÙÙˆØ§ØªÙŠØ± Ø§Ù„Ù…Ø¹Ù„Ù‚Ø©',
            value: '${state.outstandingInvoices.toStringAsFixed(2)} DH',
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyChart(BuildContext context, AdvancedDashboardState state) {
    if (state.monthlyRevenue.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Ù„Ø§ ØªÙˆØ¬Ø¯ Ø¨ÙŠØ§Ù†Ø§Øª Ø´Ù‡Ø±ÙŠØ©'),
        ),
      );
    }

    final chartHeight = MediaQuery.of(context).size.width > 600 ? 300.0 : 200.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ø§Ù„Ø¥ÙŠØ±Ø§Ø¯Ø§Øª ÙˆØ§Ù„Ù…ØµØ§Ø±ÙŠÙ Ø§Ù„Ø´Ù‡Ø±ÙŠØ©',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: chartHeight,
              child: _buildBarChart(state.monthlyRevenue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxValue = data.fold<double>(
      0.0,
      (max, item) => [item['revenue'] as double, item['expenses'] as double]
          .reduce((a, b) => a > b ? a : b)
          .clamp(0.0, double.infinity)
          .clamp(max, double.infinity),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((item) {
        final revenue = (item['revenue'] as num?)?.toDouble() ?? 0.0;
        final expenses = (item['expenses'] as num?)?.toDouble() ?? 0.0;
        final maxH = 150.0;
        final revH = maxValue > 0 ? (revenue / maxValue * maxH) : 0.0;
        final expH = maxValue > 0 ? (expenses / maxValue * maxH) : 0.0;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (revH > 0)
                      Container(
                        width: 12,
                        height: revH.clamp(2, double.infinity),
                        color: Colors.green,
                      ),
                    if (expH > 0)
                      Container(
                        width: 12,
                        height: expH.clamp(2, double.infinity),
                        color: Colors.red,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item['month'] as String? ?? '',
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExpenseBreakdown(BuildContext context, AdvancedDashboardState state) {
    if (state.expensesByCategory.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Ù„Ø§ ØªÙˆØ¬Ø¯ Ø¨ÙŠØ§Ù†Ø§Øª Ù…ØµØ§Ø±ÙŠÙ'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ØªÙˆØ²ÙŠØ¹ Ø§Ù„Ù…ØµØ§Ø±ÙŠÙ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...state.expensesByCategory.map((cat) {
              final amount = (cat['amount'] as num?)?.toDouble() ?? 0.0;
              final total = state.expensesByCategory
                  .fold<double>(0, (sum, c) => sum + ((c['amount'] as num?)?.toDouble() ?? 0.0));
              final pct = total > 0 ? (amount / total * 100) : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(cat['label'] as String? ?? ''),
                    ),
                    Expanded(
                      flex: 3,
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(_categoryColor(cat['category'] as String?)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${amount.toStringAsFixed(2)} DH',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceStatusTable(BuildContext context, AdvancedDashboardState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ø­Ø§Ù„Ø© Ø§Ù„ÙÙˆØ§ØªÙŠØ± (Ø¯Ø±Ù‡Ù… / ÙŠÙˆØ±Ùˆ)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DataTable(
              columns: const [
                DataColumn(label: Text('Ø§Ù„Ø­Ø§Ù„Ø©')),
                DataColumn(label: Text('Ø§Ù„Ø¹Ø¯Ø¯')),
                DataColumn(label: Text('Ø§Ù„Ù…Ø¨Ù„Øº (Ø¯Ø±Ù‡Ù…)')),
                DataColumn(label: Text('Ø§Ù„Ù…Ø¨Ù„Øº (ÙŠÙˆØ±Ùˆ)')),
                DataColumn(label: Text('Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ')),
              ],
              rows: state.invoicesByStatus.map((row) {
                return DataRow(cells: [
                  DataCell(Text(row['label'] as String? ?? '')),
                  DataCell(Text('${row['count']}')),
                  DataCell(Text((row['madAmount'] as num?)?.toStringAsFixed(2) ?? '0.00')),
                  DataCell(Text((row['eurAmount'] as num?)?.toStringAsFixed(2) ?? '0.00')),
                  DataCell(
                    Text(
                      (row['amount'] as num?)?.toStringAsFixed(2) ?? '0.00',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsChart(BuildContext context, AdvancedDashboardState state) {
    if (state.tripsByMonth.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Ù„Ø§ ØªÙˆØ¬Ø¯ Ø¨ÙŠØ§Ù†Ø§Øª Ø±Ø­Ù„Ø§Øª'),
        ),
      );
    }

    final chartHeight = MediaQuery.of(context).size.width > 600 ? 250.0 : 150.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ø§Ù„Ø±Ø­Ù„Ø§Øª Ø§Ù„Ø´Ù‡Ø±ÙŠØ©',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: chartHeight,
              child: _buildTripsBarChart(state.tripsByMonth),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsBarChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxCount = data.fold<int>(
      0,
      (max, item) => ((item['count'] as int?) ?? 0).clamp(0, max),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((item) {
        final count = (item['count'] as int?) ?? 0;
        final revenue = (item['revenue'] as num?)?.toDouble() ?? 0.0;
        final maxH = 120.0;
        final h = maxCount > 0 ? (count / maxCount * maxH) : 0.0;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: h.clamp(2, double.infinity),
                  color: Colors.blue,
                ),
                const SizedBox(height: 4),
                Text(
                  item['month'] as String? ?? '',
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '$count Ø±Ø­Ù„Ø©',
                  style: const TextStyle(fontSize: 9),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '${revenue.toStringAsFixed(0)} DH',
                  style: const TextStyle(fontSize: 9, color: Colors.green),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _categoryColor(String? category) {
    switch (category) {
      case 'maintenance':
        return Colors.orange;
      case 'fuel':
        return Colors.blue;
      case 'salary':
        return Colors.purple;
      case 'office':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}

Future<void> _exportExcel(
  BuildContext context,
  AdvancedDashboardState state,
) async {
  try {
    await ExcelService.instance.exportFinancialReport({
      'total_revenue': state.totalRevenue,
      'total_expenses': state.totalExpenses,
      'net_profit': state.netProfit,
      'outstanding_invoices': state.outstandingInvoices,
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ØªÙ… ØªØµØ¯ÙŠØ± Excel Ø¨Ù†Ø¬Ø§Ø­')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ø®Ø·Ø£ ÙÙŠ ØªØµØ¯ÙŠØ± Excel: $e')),
      );
    }
  }
}

Future<void> _exportPdf(
  BuildContext context,
  AdvancedDashboardState state,
) async {
  try {
    await PdfService.instance.shareDashboardPdf(
      totalRevenue: state.totalRevenue,
      totalExpenses: state.totalExpenses,
      netProfit: state.netProfit,
      outstandingInvoices: state.outstandingInvoices,
      monthlyRevenue: state.monthlyRevenue,
      expensesByCategory: state.expensesByCategory,
      invoicesByStatus: state.invoicesByStatus,
      tripsByMonth: state.tripsByMonth,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ØªÙ… ØªØµØ¯ÙŠØ± PDF Ø¨Ù†Ø¬Ø§Ø­')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ø®Ø·Ø£ ÙÙŠ ØªØµØ¯ÙŠØ± PDF: $e')),
      );
    }
  }
}
