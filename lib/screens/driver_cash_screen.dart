import 'package:flutter/material.dart';
import '../services/advance_service.dart';

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
  final AdvanceService _advanceService = AdvanceService();
  List<Map<String, dynamic>> _advances = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdvances();
  }

  Future<void> _loadAdvances() async {
    setState(() => _isLoading = true);
    final advances = await _advanceService.getAdvancesByDriver(widget.driverId);
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
    final isSmall = MediaQuery.of(context).size.width < 400;

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
                  _buildSummaryTab(isDark, summary, isSmall: isSmall),
                  _buildDetailsTab(isDark, isSmall: isSmall),
                ],
              ),
      ),
    );
  }

  Widget _buildSummaryTab(bool isDark, Map<String, double> summary, {bool isSmall = false}) {
    final given = summary['given'] ?? 0.0;
    final spent = summary['spent'] ?? 0.0;
    final returned = summary['returned'] ?? 0.0;
    final remaining = summary['remaining'] ?? 0.0;
    final titleFont = isSmall ? 17.0 : 18.0;
    final cardPadding = isSmall ? 16.0 : 20.0;

    return ListView(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSmall ? 14 : 16)),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              children: [
                Text('ملخص العهدة المالية', style: TextStyle(fontSize: titleFont, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                SizedBox(height: isSmall ? 12 : 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryBadge('المبلغ المسلم', given, Colors.blue, isDark, isSmall: isSmall),
                    _buildSummaryBadge('مصروفات الرحلة', spent, Colors.red, isDark, isSmall: isSmall),
                  ],
                ),
                SizedBox(height: isSmall ? 10 : 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryBadge('المرتجع', returned, Colors.green, isDark, isSmall: isSmall),
                    _buildSummaryBadge('الباقي', remaining, remaining > 0 ? Colors.green : Colors.red, isDark, isSmall: isSmall),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: isSmall ? 12 : 16),
        Text('العملات المالية', style: TextStyle(fontSize: isSmall ? 15.0 : 16.0, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        SizedBox(height: isSmall ? 6 : 8),
        Container(
          padding: EdgeInsets.all(isSmall ? 14 : 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
            borderRadius: BorderRadius.circular(isSmall ? 10 : 12),
            border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
          ),
          child: Column(
            children: [
              _buildDetailRow('إجمالي العهود المسلمة', given, Colors.blue, isDark, isSmall: isSmall),
              SizedBox(height: isSmall ? 6 : 8),
              _buildDetailRow('إجمالي المصاريف المسجلة', spent, Colors.red, isDark, isSmall: isSmall),
              SizedBox(height: isSmall ? 6 : 8),
              _buildDetailRow('إجمالي المرتجعات', returned, Colors.green, isDark, isSmall: isSmall),
              Divider(height: isSmall ? 20 : 24),
              _buildDetailRow('الباقي الحسابي (غير مرجع)', remaining, remaining > 0 ? Colors.green : Colors.red, isDark, bold: true, isSmall: isSmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBadge(String title, double amount, Color color, bool isDark, {bool isSmall = false}) {
    final badgePadding = isSmall ? 10.0 : 12.0;
    final titleFont = isSmall ? 11.0 : 12.0;
    final valueFont = isSmall ? 15.0 : 16.0;

    return Expanded(
      child: Container(
        padding: EdgeInsets.all(badgePadding),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(isSmall ? 10 : 12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: titleFont, color: isDark ? Colors.grey[300] : Colors.grey[600])),
            SizedBox(height: isSmall ? 3 : 4),
            Text('${amount.toStringAsFixed(2)} DH', style: TextStyle(fontSize: valueFont, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, double value, Color color, bool isDark, {bool bold = false, bool isSmall = false}) {
    final titleFont = isSmall ? 13.0 : 14.0;
    final valueFont = isSmall ? 14.0 : 15.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: titleFont, color: isDark ? Colors.grey[300] : Colors.grey[700])),
        Text('${value.toStringAsFixed(2)} DH', style: TextStyle(fontSize: valueFont, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _buildDetailsTab(bool isDark, {bool isSmall = false}) {
    final padding = isSmall ? 10.0 : 12.0;
    final cardPadding = isSmall ? 12.0 : 14.0;
    final amountFont = isSmall ? 16.0 : 18.0;
    final statusFont = isSmall ? 11.0 : 12.0;
    final detailFont = isSmall ? 12.0 : 13.0;
    final iconSize = isSmall ? 13.0 : 14.0;

    if (_advances.isEmpty) {
      return Center(child: Text('لا توجد عهود مسجلة', style: TextStyle(fontSize: isSmall ? 14 : null)));
    }

    return ListView.builder(
      padding: EdgeInsets.all(padding),
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
          margin: EdgeInsets.symmetric(vertical: isSmall ? 4 : 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isSmall ? 10 : 12),
            side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
          ),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${given.toStringAsFixed(2)} DH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: amountFont, color: Theme.of(context).colorScheme.primary)),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 10, vertical: isSmall ? 3 : 4),
                      decoration: BoxDecoration(
                        color: status == 'settled' ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(isSmall ? 6 : 8),
                      ),
                      child: Text(status == 'settled' ? 'تم التسوية' : status == 'en_route' ? 'في الطريق' : 'معلق', style: TextStyle(fontSize: statusFont, color: status == 'settled' ? Colors.green : Colors.orange, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                SizedBox(height: isSmall ? 6 : 8),
                Row(children: [Icon(Icons.login, size: iconSize, color: isDark ? Colors.grey[400] : Colors.grey[600]), SizedBox(width: isSmall ? 3 : 4), Text('انطلاق: $dateOut', style: TextStyle(fontSize: detailFont, color: isDark ? Colors.grey[300] : Colors.grey[700]))]),
                if (dateReturn.isNotEmpty) ...[SizedBox(height: isSmall ? 3 : 4), Row(children: [Icon(Icons.exit_to_app, size: iconSize, color: isDark ? Colors.grey[400] : Colors.grey[600]), SizedBox(width: isSmall ? 3 : 4), Text('عودة: $dateReturn', style: TextStyle(fontSize: detailFont, color: isDark ? Colors.grey[300] : Colors.grey[700]))])],
                if (spent > 0) ...[SizedBox(height: isSmall ? 3 : 4), Row(children: [Icon(Icons.receipt_long, size: iconSize, color: isDark ? Colors.grey[400] : Colors.grey[600]), SizedBox(width: isSmall ? 3 : 4), Text('مصروف: ${spent.toStringAsFixed(2)} DH', style: TextStyle(fontSize: detailFont, color: isDark ? Colors.grey[300] : Colors.grey[700]))])],
                if (returned != null) ...[SizedBox(height: isSmall ? 3 : 4), Row(children: [Icon(Icons.money, size: iconSize, color: isDark ? Colors.grey[400] : Colors.grey[600]), SizedBox(width: isSmall ? 3 : 4), Text('مرتجع: ${returned.toDouble().toStringAsFixed(2)} DH', style: TextStyle(fontSize: detailFont, color: isDark ? Colors.grey[300] : Colors.grey[700]))])],
                SizedBox(height: isSmall ? 4 : 6),
                Row(children: [Icon(Icons.account_balance_wallet_rounded, size: iconSize, color: remaining > 0 ? Colors.green : Colors.red), SizedBox(width: isSmall ? 3 : 4), Text('الباقي: ${remaining.toStringAsFixed(2)} DH', style: TextStyle(fontSize: detailFont, color: remaining > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w600))]),
                if (notes.isNotEmpty) ...[SizedBox(height: isSmall ? 4 : 6), Container(padding: EdgeInsets.all(isSmall ? 6 : 8), decoration: BoxDecoration(color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100], borderRadius: BorderRadius.circular(isSmall ? 6 : 8)), child: Text(notes, style: TextStyle(fontSize: detailFont, color: isDark ? Colors.grey[300] : Colors.grey[700])))],
              ],
            ),
          ),
        );
      },
    );
  }
}
