import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class DriverCashScreen extends StatefulWidget {
  final int driverId;
  final String driverName;

  const DriverCashScreen({
    super.key,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<DriverCashScreen> createState() => _DriverCashScreenState();
}

class _DriverCashScreenState extends State<DriverCashScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _advances = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdvances();
  }

  Future<void> _loadAdvances() async {
    setState(() => _isLoading = true);
    final advances = await _supabaseService.getAdvancesByDriver(widget.driverId);
    if (!mounted) return;
    setState(() {
      _advances = advances;
      _isLoading = false;
    });
  }

  Map<String, double> _computeSummary() {
    double givenTotal = 0.0;
    double spentTotal = 0.0;
    double returnedTotal = 0.0;
    for (final a in _advances) {
      final given = (a['amount_given'] as num?)?.toDouble() ?? 0.0;
      final spent = (a['amount_spent'] as num?)?.toDouble() ?? 0.0;
      final returned = (a['amount_returned'] as num?)?.toDouble() ?? 0.0;
      givenTotal += given;
      spentTotal += spent;
      returnedTotal += returned;
    }
    return {
      'given': givenTotal,
      'spent': spentTotal,
      'returned': returnedTotal,
      'remaining': givenTotal - spentTotal - returnedTotal,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = _computeSummary();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('شاشة السائق: ${widget.driverName}'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'الملخص المالي'),
              Tab(text: 'تفاصيل العهود'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildSummaryTab(isDark, summary),
                  _buildDetailsTab(isDark),
                ],
              ),
      ),
    );
  }

  Widget _buildSummaryTab(bool isDark, Map<String, double> summary) {
    final given = summary['given'] ?? 0.0;
    final spent = summary['spent'] ?? 0.0;
    final returned = summary['returned'] ?? 0.0;
    final remaining = summary['remaining'] ?? 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text('ملخص العهدة المالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryBadge('المبلغ المسلم', given, Colors.blue, isDark),
                    _buildSummaryBadge('مصروفات الرحلة', spent, Colors.red, isDark),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryBadge('المرتجع', returned, Colors.green, isDark),
                    _buildSummaryBadge('الباقي', remaining, remaining > 0 ? Colors.green : Colors.red, isDark),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('العملات المالية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
          ),
          child: Column(
            children: [
              _buildDetailRow('إجمالي العهود المسلمة', given, Colors.blue, isDark),
              const SizedBox(height: 8),
              _buildDetailRow('إجمالي المصاريف المسجلة', spent, Colors.red, isDark),
              const SizedBox(height: 8),
              _buildDetailRow('إجمالي المرتجعات', returned, Colors.green, isDark),
              const Divider(height: 24),
              _buildDetailRow('الباقي الحسابي (غير مرجع)', remaining, remaining > 0 ? Colors.green : Colors.red, isDark, bold: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBadge(String title, double amount, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[600])),
            const SizedBox(height: 4),
            Text('${amount.toStringAsFixed(2)} DH', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, double value, Color color, bool isDark, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[700])),
        Text('${value.toStringAsFixed(2)} DH', style: TextStyle(fontSize: 15, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _buildDetailsTab(bool isDark) {
    if (_advances.isEmpty) {
      return const Center(child: Text('لا توجد عهود مسجلة'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _advances.length,
      itemBuilder: (context, index) {
        final advance = _advances[index];
        final given = (advance['amount_given'] as num?)?.toDouble() ?? 0.0;
        final spent = (advance['amount_spent'] as num?)?.toDouble() ?? 0.0;
        final dateOut = advance['date_out']?.toString() ?? '';
        final dateReturn = advance['date_return']?.toString() ?? '';
        final status = advance['status']?.toString() ?? 'pending';
        final notes = advance['notes']?.toString() ?? '';
        final returned = advance['amount_returned'] as num?;

        final remaining = given - spent - (returned ?? 0.0);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${given.toStringAsFixed(2)} DH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.primary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'settled' ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(status == 'settled' ? 'تم التسوية' : status == 'en_route' ? 'في الطريق' : 'معلق', style: TextStyle(fontSize: 12, color: status == 'settled' ? Colors.green : Colors.orange, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(children: [Icon(Icons.login, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]), const SizedBox(width: 4), Text('انطلاق: $dateOut', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700]))]),
                if (dateReturn.isNotEmpty) ...[const SizedBox(height: 4), Row(children: [Icon(Icons.exit_to_app, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]), const SizedBox(width: 4), Text('عودة: $dateReturn', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700]))])],
                if (spent > 0) ...[const SizedBox(height: 4), Row(children: [Icon(Icons.receipt_long, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]), const SizedBox(width: 4), Text('مصروف: ${spent.toStringAsFixed(2)} DH', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700]))])],
                if (returned != null) ...[const SizedBox(height: 4), Row(children: [Icon(Icons.money, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]), const SizedBox(width: 4), Text('مرتجع: ${returned.toDouble().toStringAsFixed(2)} DH', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700]))])],
                const SizedBox(height: 6),
                Row(children: [Icon(Icons.account_balance_wallet_rounded, size: 14, color: remaining > 0 ? Colors.green : Colors.red), const SizedBox(width: 4), Text('الباقي: ${remaining.toStringAsFixed(2)} DH', style: TextStyle(fontSize: 13, color: remaining > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w600))]),
                if (notes.isNotEmpty) ...[const SizedBox(height: 6), Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: Text(notes, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700])))],
              ],
            ),
          ),
        );
      },
    );
  }
}
