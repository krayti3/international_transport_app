import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../services/excel_service.dart';
import '../services/pdf_service.dart';
import '../widgets/summary_card.dart';
import '../widgets/simple_bar_chart.dart';
import '../widgets/expense_row.dart';
import '../widgets/responsive_layout.dart';
import '../l10n/app_localizations.dart';

// ignore_for_file: use_build_context_synchronously

class CompanyProfitReportScreen extends StatefulWidget {
  const CompanyProfitReportScreen({super.key});

  @override
  State<CompanyProfitReportScreen> createState() => _CompanyProfitReportScreenState();
}

class _CompanyProfitReportScreenState extends State<CompanyProfitReportScreen> {
  final ReportService _reportService = ReportService();
  Map<String, double> _report = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final reportList = await _reportService.getCompanyProfitReport(startDate: DateTime.now().subtract(const Duration(days: 365)), endDate: DateTime.now());
    if (!mounted) return;
    setState(() {
      _report = <String, double>{};
      for (final item in reportList) {
        for (final entry in item.entries) {
          final value = entry.value;
          if (value is num) {
            _report[entry.key] = value.toDouble();
          }
        }
      }
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
            Text('جاري إنشاء ملف Excel...'),
          ],
        ),
      ),
    );

    try {
      final bytes = await ExcelService.instance.exportFinancialReport(
        _report.map((k, v) => MapEntry(k, v.toDouble())),
      );
      await ExcelService.instance.shareExcel(bytes, 'تقرير_الأرباح');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء Excel: $e')),
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
            Text('جاري إنشاء ملف PDF...'),
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
          SnackBar(content: Text('خطأ في إنشاء PDF: $e')),
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
        appBar: AppBar(title: Text(context.tr('تقرير الأرباح'))),
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
        title: Text(context.tr('تقرير الأرباح الصافية')),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير PDF',
            onPressed: _exportPdf,
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'تصدير Excel',
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
                context.tr('تقرير الشهر الحالي ({0})', [monthLabel]),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SummaryCard(
                title: context.tr('إجمالي المداخيل (مع TVA)'),
                value: '${revenueWithTva.toStringAsFixed(2)} DH',
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              SummaryCard(
                title: context.tr('ضريبة TVA'),
                value: '${tvaAmount.toStringAsFixed(2)} DH',
                color: Colors.purple,
              ),
              const SizedBox(height: 12),
              SummaryCard(
                title: context.tr('إجمالي المداخيل (بدون TVA)'),
                value: '${revenue.toStringAsFixed(2)} DH',
                color: Colors.indigo,
              ),
              const SizedBox(height: 12),
              SummaryCard(
                title: context.tr('إجمالي المصاريف'),
                value: '${totalExpenses.toStringAsFixed(2)} DH',
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              SummaryCard(
                title: context.tr('الأرباح الإجمالية'),
                value: '${grossProfit.toStringAsFixed(2)} DH',
                color: Colors.teal,
              ),
              const SizedBox(height: 12),
              SummaryCard(
                title: context.tr('صافي الأرباح'),
                value: '${netProfit.toStringAsFixed(2)} DH',
                color: netProfit >= 0.0 ? Colors.green : Colors.red,
                isLarge: true,
              ),
              const SizedBox(height: 24),
              Text(
                context.tr('نسبة المصاريف مقارنة بالأرباح'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SimpleBarChart(expenses: totalExpenses, netProfit: netProfit),
              const SizedBox(height: 24),
              Text(
                context.tr('تفاصيل المصاريف'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ExpenseRow(title: context.tr('مصاريف تشغيل الرحلات'), amount: tripExpense),
              ExpenseRow(title: context.tr('مصاريف المكتب'), amount: officeExpense),
              ExpenseRow(title: context.tr('الأجور والرواتب'), amount: salary),
              ExpenseRow(title: context.tr('مصاريف صيانة الشاحنات'), amount: truckMaintenance),
            ],
          ),
        ),
      ),
    );
  }
}
