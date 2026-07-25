import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../l10n/app_localizations.dart';

// ignore_for_file: use_build_context_synchronously

/// كشف حساب تفصيلي للزبون — يعرض الجدول الزمني الكامل للفواتير والدفعات
/// مع الرصيد المتراكم بصيغة المحاسبة القياسية.
class ClientStatementScreen extends StatefulWidget {
  const ClientStatementScreen({super.key, required this.clientId, required this.clientName});
  final int clientId;
  final String clientName;

  @override
  State<ClientStatementScreen> createState() => _ClientStatementScreenState();
}

class _ClientStatementScreenState extends State<ClientStatementScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _statement = [];
  bool _isLoading = true;
  double _currentBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStatement();
  }

  Future<void> _loadStatement() async {
    setState(() => _isLoading = true);
    final items = await _supabaseService.getClientStatement(widget.clientId);
    if (mounted) {
      setState(() {
        _statement = items;
        _currentBalance = items.isNotEmpty ? (items.last['balance'] as double?) ?? 0.0 : 0.0;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    if (!mounted) return;
    final clientData = {'name': widget.clientName, 'id': widget.clientId};
    try {
      await PdfService.instance.shareClientStatement(
        client: clientData,
        statementItems: _statement,
        currentBalance: _currentBalance,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('خطأ في تصدير كشف الحساب: {0}', [e]))),
      );
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return context.tr('غير محدد');
    try {
      final dt = DateTime.tryParse(dateStr);
      if (dt == null) return dateStr;
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('كشف حساب — {0}', [widget.clientName])),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: context.tr('تصدير PDF'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatement,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // Summary Card
                  Card(
                    color: _currentBalance > 0
                        ? Colors.orange.withValues(alpha: 0.1)
                        : _currentBalance < 0
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentBalance > 0
                                    ? 'الرصيد المستحق للشركة'
                                    : _currentBalance < 0
                                        ? 'الرصيد المستحق للزبون'
                                        : 'الرصيد',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_currentBalance.abs().toStringAsFixed(2)} DH',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _currentBalance > 0
                                      ? Colors.orange
                                      : _currentBalance < 0
                                          ? Colors.green
                                          : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            _currentBalance > 0
                                ? Icons.arrow_upward
                                : _currentBalance < 0
                                    ? Icons.arrow_downward
                                    : Icons.remove,
                            size: 40,
                            color: _currentBalance > 0
                                ? Colors.orange
                                : _currentBalance < 0
                                    ? Colors.green
                                    : Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Statement header
                  const Text(
                    'الجدول الزمني للحساب',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  if (_statement.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('لا توجد معاملات لهذا الزبون')),
                    )
                  else
                    ..._statement.map((item) {
                      final date = _formatDate(item['date']?.toString());
                      final description = item['description']?.toString() ?? '';
                       final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
                      final isDebit = item['isDebit'] == true;
                      final balance = (item['balance'] as num?)?.toDouble() ?? 0.0;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDebit
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isDebit ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isDebit ? Colors.red : Colors.green,
                            ),
                          ),
                          title: Text(
                            description,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(date, textDirection: TextDirection.ltr),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isDebit
                                    ? '-${amount.toStringAsFixed(2)} DH'
                                    : '+${amount.toStringAsFixed(2)} DH',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDebit ? Colors.red : Colors.green,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isDebit ? Colors.red : Colors.green).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'الرصيد: ${balance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDebit ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
