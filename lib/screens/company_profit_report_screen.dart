import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/excel_service.dart';
import '../services/pdf_service.dart';
import '../widgets/summary_card.dart';
import '../widgets/simple_bar_chart.dart';
import '../widgets/expense_row.dart';
import '../widgets/responsive_layout.dart';
import '../l10n/app_localizations.dart';

// ignore_for_file: use_build_context_synchronously

/// ØªÙ‚Ø±ÙŠØ± Ø§Ù„Ø£Ø±Ø¨Ø§Ø­ Ø§Ù„ØµØ§ÙÙŠØ© Ù„Ù„Ø´Ø±ÙƒØ© â€” Ù„Ù„Ø£Ø¯Ù…Ù† ÙÙ‚Ø·.
/// ÙŠØ¹Ø±Ø¶ ãØ§Ø±Ø¯ÙŠÙ„ Ø§Ù„ÙÙˆØ§ØªÙŠØ± (Ø¨Ø¯ÙˆÙ† TVA) ÙˆØ§Ù„Ù…ØµØ§Ø±ÙŠÙ ÙˆØ£Ø±Ø¨Ø§Ø­ Ø§Ù„Ø´Ø±ÙƒØ© Ù„Ù€ **Ø§Ù„Ø´Ù‡Ø± Ø§Ù„Ø­Ø§Ù„ÙŠ**
/// Ù…Ø±Ø³Ù… Ø¨ÙŠØ§Ù†ÙŠ ÙŠÙˆØ¶Ø­ Ù†Ø³Ø¨Ø© Ø§Ù„Ù…ØµØ§Ø±ÙŠÙ Ù…Ù‚Ø§Ø±Ù†Ø© Ø¨Ø§Ù„Ø£Ø±Ø¨Ø§Ø­.
class CompanyProfitReportScreen extends StatefulWidget {
  const CompanyProfitReportScreen({super.key});

  @override
  State<CompanyProfitReportScreen> createState() => _CompanyProfitReportScreenState();
}

class _CompanyProfitReportScreenState extends State<CompanyProfitReportScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  Map<String, double> _report = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final report = await _supabaseService.getCompanyProfitReport();
    if (!mounted) return;
    setState(() {
      _report = report.map((k, v) => MapEntry(k, (v as num).toDouble()));
      _isLoading = false;
    });
  }

  Future<void> _exportExcel() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Ø¬Ø§Ø±ÙŠ Ø¥Ù†Ø´Ø§Ø¡ Ù…Ù„Ù Excel...'),
          ],
        ),
      ),
    );

    try {
      final bytes = await ExcelService.instance.exportFinancialReport(
        _report.map((k, v) => MapEntry(k, v.toDouble())),
      );
      await ExcelService.instance.shareExcel(bytes, 'ØªÙ‚Ø±ÙŠØ±_Ø§Ù„Ø£Ø±Ø¨Ø§Ø­');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ø®Ø·Ø£ ÙÙŠ Ø¥Ù†Ø´Ø§Ø¡ Excel: $e')),
        );
      }
    } finally {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _exportPdf() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Ø¬Ø§Ø±ÙŠ Ø¥Ù†Ø´Ø§Ø¡ Ù…Ù„Ù PDF...'),
          ],
        ),
      ),
    );

    try {
      final totalRevenue = _report['total_revenue'] ?? 0.0;
      final totalExpenses = _report['total_expenses'] ?? 0.0;
    
      await PdfService.instance.shareDashboardPdf(
        totalRevenue: totalRevenue,
        totalExpenses: totalExpenses,
        netProfit: _report['net_profit'] ?? 0.0,
        outstandingInvoices: 0.0,
        monthlyRevenue: [],
        expensesByCategory: [],
        invoicesByStatus: [],
        tripsByMonth: [],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ø®Ø·Ø£ ÙÙŠ Ø¥Ù†Ø´Ø§Ø¡ PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('ØªÙ‚Ø±ÙŠØ± Ø§Ù„Ø£Ø±Ø¨Ø§Ø­'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

      final revenueWithTva = _report['total_revenue_with_tva'] ?? 0.0;
      final tvaAmount = _report['tva_amount'] ?? 0.0;
      final revenue = _report['total_revenue'] ?? 0.0;
      final tripExpense = _report['trip_expense'] ?? 0.0;
      final officeExpense = _report['office_expense'] ?? 0.0;
      final salary = _report['salary'] ?? 0.0;
      final truckMaintenance = _report['truck_maintenance'] ?? 0.0;
      final totalExpenses = _report['total_expenses'] ?? 0.0;
      final grossProfit = _report['gross_profit'] ?? 0.0;
      final netProfit = _report['net_profit'] ?? 0.0;

    final monthLabel = '${DateTime.now().month}/${DateTime.now().year}';

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('ØªÙ‚Ø±ÙŠØ± Ø§Ù„Ø£Ø±Ø¨Ø§Ø­ Ø§Ù„ØµØ§ÙÙŠØ©')),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'ØªØµØ¯ÙŠØ± PDF',
            onPressed: _exportPdf,
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'ØªØµØ¯ÙŠØ± Excel',
            onPressed: _exportExcel,
          ),
        ],
      ),
      body: AppConstrained(
        child: RefreshIndicator(
          onRefresh: _loadReport,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                context.tr('ØªÙ‚Ø±ÙŠØ± Ø§Ù„Ø´Ù‡Ø± Ø§Ù„Ø­Ø§Ù„ÙŠ ({0})', [monthLabel]),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SummaryCard(
                title: context.tr('Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…Ø¯Ø§Ø®ÙŠÙ„ (Ù…Ø¹ TVA)'),
                value: '${revenueWithTva.toStringAsFixed(2)} DH',
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              SummaryCard(
                title: context.tr('Ø¶Ø±ÙŠØ¨Ø© TVA'),
                value: '${tvaAmount.toStringAsFixed(2)} DH',
                color: Colors.purple,
              ),
              const SizedBox(height: 12),
              SummaryCard(
                title: context.tr('Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…Ø¯Ø§Ø®ÙŠÙ„ (Ø¨Ø¯ÙˆÙ† TVA)'),
                value: '${revenue.toStringAsFixed(2)} DH',
                color: Colors.indigo,
              ),
              const SizedBox(height: 12),
              SummaryCard(
                title: context.tr('Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…ØµØ§Ø±ÙŠÙ'),
                value: '${totalExpenses.toStringAsFixed(2)} DH',
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              SummaryCard(
                title: context.tr('Ø§Ù„Ø£Ø±Ø¨Ø§Ø­ Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠØ©'),
                value: '${grossProfit.toStringAsFixed(2)} DH',
                color: Colors.teal,
              ),
              const SizedBox(height: 12),
              SummaryCard(
                title: context.tr('ØµØ§ÙÙŠ Ø§Ù„Ø£Ø±Ø¨Ø§Ø­'),
                value: '${netProfit.toStringAsFixed(2)} DH',
                color: netProfit >= 0.0 ? Colors.green : Colors.red,
                isLarge: true,
              ),
              const SizedBox(height: 24),
              Text(
                context.tr('Ù†Ø³Ø¨Ø© Ø§Ù„Ù…ØµØ§Ø±ÙŠÙ Ù…Ù‚Ø§Ø¨Ù„ Ø§Ù„Ø£Ø±Ø¨Ø§Ø­'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SimpleBarChart(expenses: totalExpenses, netProfit: netProfit),
              const SizedBox(height: 24),
              Text(
                context.tr('ØªÙØ§ØµÙŠÙ„ Ø§Ù„Ù…ØµØ§Ø±ÙŠÙ'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ExpenseRow(title: context.tr('Ù…ØµØ§Ø±ÙŠÙ ØªØ´ØºÙŠÙ„ Ø§Ù„Ø±Ø­Ù„Ø§Øª'), amount: tripExpense),
              ExpenseRow(title: context.tr('Ù…ØµØ§Ø±ÙŠÙ Ø§Ù„Ù…ÙƒØªØ¨'), amount: officeExpense),
              ExpenseRow(title: context.tr('Ø§Ù„Ø£Ø¬ÙˆØ± ÙˆØ§Ù„Ø±ÙˆØ§ØªØ¨'), amount: salary),
              ExpenseRow(title: context.tr('Ù…ØµØ§Ø±ÙŠÙ ØµÙŠØ§Ù†Ø© Ø§Ù„Ø´Ø§Ø­Ù†Ø§Øª'), amount: truckMaintenance),
            ],
          ),
        ),
      ),
    );
  }
}

