import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../services/ai_analysis_service.dart';
import '../../cubits/ai_reports_cubit.dart';
import '../../services/excel_service.dart';
import '../../services/pdf_service.dart';
import '../../widgets/summary_card.dart';

class AiReportsScreen extends StatelessWidget {
  const AiReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AiReportsCubit(),
      child: const _AiReportsBody(),
    );
  }
}

class _AiReportsBody extends StatefulWidget {
  const _AiReportsBody();

  @override
  State<_AiReportsBody> createState() => _AiReportsBodyState();
}

class _AiReportsBodyState extends State<_AiReportsBody> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _exportPdf(AiReportSummary summary) async {
    try {
      await PdfService.instance.shareDashboardPdf(
        totalRevenue: summary.currentMonthRevenue,
        totalExpenses: summary.currentMonthExpenses,
        netProfit: summary.currentMonthProfit,
        outstandingInvoices: 0.0,
        monthlyRevenue: summary.profitForecast.monthlyHistory,
        expensesByCategory: const [],
        invoicesByStatus: const [],
        tripsByMonth: const [],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تصدير PDF بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تصدير PDF: $e')),
      );
    }
  }

  Future<void> _exportExcel(AiReportSummary summary) async {
    try {
      await ExcelService.instance.exportFinancialReport({
        'total_revenue': summary.currentMonthRevenue,
        'total_expenses': summary.currentMonthExpenses,
        'net_profit': summary.currentMonthProfit,
        'predicted_next_month': summary.predictedNextMonthProfit,
        'average_monthly_profit': summary.averageMonthlyProfit,
        'outstanding_invoices': 0.0,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تصدير Excel بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تصدير Excel: $e')),
      );
    }
  }

  Color _healthColor(String health) {
    switch (health) {
      case 'ممتاز':
        return Colors.green;
      case 'جيد':
        return Colors.lightGreen;
      case 'مقبول':
        return Colors.orange;
      case 'يحتاج مراقبة':
        return Colors.deepOrange;
      case 'حرج':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _severityIcon(String severity) {
    switch (severity) {
      case 'success':
        return Icons.check_circle_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'alert':
        return Icons.error_rounded;
      case 'info':
      default:
        return Icons.info_rounded;
    }
  }

  Color _severityColor(String severity, ColorScheme cs) {
    switch (severity) {
      case 'success':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'alert':
        return cs.error;
      case 'info':
      default:
        return cs.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير ذكية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundColor: colorScheme.onSurface,
        centerTitle: true,
        actions: [
          BlocBuilder<AiReportsCubit, AiReportsState>(
            buildWhen: (p, c) => p.isLoading != c.isLoading,
            builder: (context, state) {
              return IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'تحديث التحليل',
                onPressed: state.isLoading ? null : () => context.read<AiReportsCubit>().refresh(),
              );
            },
          ),
          BlocBuilder<AiReportsCubit, AiReportsState>(
            buildWhen: (p, c) => p.hasData != c.hasData,
            builder: (context, state) {
              if (!state.hasData || state.summary == null) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                tooltip: 'تصدير',
                onSelected: (value) {
                  if (value == 'pdf') {
                    _exportPdf(state.summary!);
                  } else if (value == 'excel') {
                    _exportExcel(state.summary!);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'pdf', child: Text('تصدير PDF')),
                  const PopupMenuItem(value: 'excel', child: Text('تصدير Excel')),
                ],
                icon: const Icon(Icons.download_rounded),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<AiReportsCubit, AiReportsState>(
        listener: (context, state) {
          if (state.errorMessage != null && !state.hasData) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                action: SnackBarAction(
                  label: 'إعادة المحاولة',
                  onPressed: () => context.read<AiReportsCubit>().analyze(),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAiHeader(context, colorScheme),
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
                const Center(child: Text('جاري تحليل البيانات...')),
              ],
            );
          }

          final summary = state.summary;
          if (summary == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 64, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد بيانات كافية للتحليل',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.read<AiReportsCubit>().analyze(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<AiReportsCubit>().refresh(),
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                const SizedBox(height: 8),
                _buildAiHeader(context, colorScheme),
                const SizedBox(height: 16),
                _buildHealthCard(context, summary, colorScheme),
                const SizedBox(height: 12),
                _buildCurrentMonthSummary(context, summary, colorScheme),
                const SizedBox(height: 12),
                _buildPredictionCard(context, summary, colorScheme),
                const SizedBox(height: 12),
                _buildTrendChartCard(context, summary, colorScheme),
                const SizedBox(height: 12),
                if (summary.seasonality != null) _buildSeasonalityCard(context, summary.seasonality!, colorScheme),
                const SizedBox(height: 12),
                _buildInsightsCard(context, summary, colorScheme),
                if (summary.recommendations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildRecommendationsCard(context, summary.recommendations, colorScheme),
                ],
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAiHeader(BuildContext context, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.secondaryContainer],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.auto_graph_rounded, color: cs.onPrimary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('التحليل الذكي للبيانات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                const SizedBox(height: 4),
                Text('تحليل تلقائي مع تنبؤات بالأرباح', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCard(BuildContext context, AiReportSummary summary, ColorScheme cs) {
    final health = summary.overallHealthAr;
    final healthColor = _healthColor(health);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [healthColor.withValues(alpha: 0.2), healthColor.withValues(alpha: 0.05)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: healthColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: summary.currentMonthProfit > 0 ? 0.85 : 0.3,
                  strokeWidth: 6,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                ),
              ),
              Icon(
                summary.currentMonthProfit > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: healthColor,
                size: 28,
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الصحة المالية', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                Text(health, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: healthColor)),
                const SizedBox(height: 4),
                Text(
                  summary.currentMonthProfit > 0 ? 'أرباح هذا الشهر: ${_formatCurrency(summary.currentMonthProfit)}' : 'لا توجد أرباح حالياً',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.health_and_safety_rounded, size: 36, color: healthColor.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  Widget _buildCurrentMonthSummary(BuildContext context, AiReportSummary summary, ColorScheme cs) {
    final numberFormat = NumberFormat('#,###.00');
    final items = [
      {'label': 'الإيرادات', 'value': '${numberFormat.format(summary.currentMonthRevenue)} DH', 'icon': Icons.arrow_downward_rounded, 'color': Colors.green},
      {'label': 'المصاريف', 'value': '${numberFormat.format(summary.currentMonthExpenses)} DH', 'icon': Icons.arrow_upward_rounded, 'color': Colors.red},
      {'label': 'صافي الربح', 'value': '${numberFormat.format(summary.currentMonthProfit)} DH', 'icon': Icons.account_balance_wallet_rounded, 'color': summary.currentMonthProfit >= 0 ? Colors.green : Colors.red},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ملخص الشهر الحالي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
        const SizedBox(height: 10),
        Row(
          children: items.expand((item) {
            final label = item['label'] as String;
            final value = item['value'] as String;
            final color = item['color'] as Color;

            return [
              Expanded(
                child: SummaryCard(
                  title: label,
                  value: value,
                  color: color,
                  isLarge: label == 'صافي الربح',
                ),
              ),
              const SizedBox(width: 8),
            ];
          }).toList()..removeLast(),
        ),
      ],
    );
  }

  Widget _buildPredictionCard(BuildContext context, AiReportSummary summary, ColorScheme cs) {
    final prediction = summary.profitForecast;
    final numberFormat = NumberFormat('#,###.00');
    final trendColor = prediction.trendAr == 'تصاعدي' ? Colors.green : prediction.trendAr == 'تنازلي' ? Colors.red : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: trendColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.precision_manufacturing_rounded, color: trendColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text('تنبؤ الأرباح للشهر القادم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cs.onSurface)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: trendColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(prediction.trendAr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: trendColor)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPredictionItem('الأرباح المتوقعة', '${numberFormat.format(prediction.predictedProfit)} DH', Colors.purple, cs),
              _buildPredictionItem('مستوى الثقة', '${(prediction.confidence * 100).toInt()}%', Colors.blue, cs),
              _buildPredictionItem('المعدل الشهري', '${numberFormat.format(summary.averageMonthlyProfit)} DH', Colors.teal, cs),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'الفرق المتوقع: ${prediction.predictedProfit >= summary.averageMonthlyProfit ? '+' : ''}${numberFormat.format(prediction.predictedProfit - summary.averageMonthlyProfit)} DH عن المعدل',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionItem(String label, String value, Color color, ColorScheme cs) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildSeasonalityCard(BuildContext context, SeasonalityResult seasonality, ColorScheme cs) {
    final numberFormat = NumberFormat('#,###.00');
    final trendColor = seasonality.trend == 'تصاعدي'
        ? Colors.green
        : seasonality.trend == 'تنازلي'
            ? Colors.red
            : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: trendColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: trendColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text('التحليل الموسمي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cs.onSurface)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: trendColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(seasonality.trend, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: trendColor)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildSeasonalityItem(
                  'أفضل شهر',
                  seasonality.bestMonth['month']?.toString() ?? 'غير متاح',
                  '${numberFormat.format((seasonality.bestMonth['profit'] as double?) ?? 0.0)} DH',
                  Colors.green,
                  cs,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSeasonalityItem(
                  'أسوأ شهر',
                  seasonality.worstMonth['month']?.toString() ?? 'غير متاح',
                  '${numberFormat.format((seasonality.worstMonth['profit'] as double?) ?? 0.0)} DH',
                  Colors.red,
                  cs,
                ),
              ),
            ],
          ),
          if (seasonality.forecast.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text('التوقعات القادمة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: seasonality.forecast.map((f) {
                final confidence = (f['confidence'] as double?) ?? 0.5;
                final profit = (f['profit'] as double?) ?? 0.0;
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text('${numberFormat.format(profit)} DH', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.purple)),
                          Text('${(confidence * 100).toInt()}%', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(f['month']?.toString() ?? '', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSeasonalityItem(String label, String month, String profit, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(month, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 2),
          Text(profit, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard(BuildContext context, List<String> recommendations, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.psychology_rounded, color: cs.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text('التوصيات الذكية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Text('${recommendations.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...recommendations.map((rec) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.secondaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_rounded, color: cs.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(rec, style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.5)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTrendChartCard(BuildContext context, AiReportSummary summary, ColorScheme cs) {
    final history = summary.profitForecast.monthlyHistory;
    final prediction = summary.profitForecast.monthlyPrediction;

    if (history.isEmpty && prediction.isEmpty) return const SizedBox.shrink();

    final allValues = [
      ...history.map((m) => (m['revenue'] as double?) ?? 0.0),
      ...history.map((m) => (m['expenses'] as double?) ?? 0.0),
      if (prediction.isNotEmpty) prediction.first['profit'] as double? ?? 0.0,
    ];
    final maxVal = allValues.fold<double>(0.0, (a, b) => a > b ? a : b);
    final safeMax = maxVal <= 0 ? 1.0 : maxVal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('الاتجاهات الشهرية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: history.length + prediction.length,
                  itemBuilder: (context, index) {
                    final isPrediction = index >= history.length;
                    final data = isPrediction ? prediction.first : history[index];
                    final revenue = (data['revenue'] as double?) ?? 0.0;
                    final expenses = (data['expenses'] as double?) ?? 0.0;
                    final profit = data['profit'] as double? ?? 0.0;
                    final month = data['month'] as String? ?? '';

                    final revH = safeMax > 0 ? (revenue / safeMax * 150).clamp(2.0, 150.0) : 0.0;
                    final expH = safeMax > 0 ? (expenses / safeMax * 150).clamp(2.0, 150.0) : 0.0;
                    final profH = safeMax > 0 ? (profit / safeMax * 150).clamp(2.0, 150.0) : 0.0;

                    return Container(
                      width: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (revH > 0.5)
                            Container(width: 10, height: revH, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(3))),
                          if (expH > 0.5)
                            Container(width: 10, height: expH, decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(3))),
                          if (profH > 0.5)
                            Container(width: 10, height: profH, decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(3))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPrediction ? Colors.purple.withValues(alpha: 0.15) : null,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              month,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: isPrediction ? FontWeight.bold : FontWeight.normal,
                                color: isPrediction ? Colors.purple : cs.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem('إيرادات', Colors.green, cs),
                  const SizedBox(width: 16),
                  _buildLegendItem('مصاريف', Colors.red, cs),
                  const SizedBox(width: 16),
                  _buildLegendItem('أرباح', Colors.purple, cs),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, ColorScheme cs) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildInsightsCard(BuildContext context, AiReportSummary summary, ColorScheme cs) {
    final insights = summary.insights;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb_rounded, color: cs.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text('الرؤى والتوصيات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Text('${insights.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...insights.map((insight) {
          final severityColor = _severityColor(insight.severity, cs);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: severityColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_severityIcon(insight.severity), color: severityColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(insight.titleAr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: severityColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(insight.descriptionAr, style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.5)),
                if (insight.suggestionAr != null && insight.suggestionAr!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.tips_and_updates_rounded, color: cs.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            insight.suggestionAr!,
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: cs.onSurfaceVariant, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  String _formatCurrency(double value) {
    final fmt = NumberFormat('#,###.00');
    return '${fmt.format(value)} DH';
  }
}
