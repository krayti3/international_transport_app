import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/client_service.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/summary_card.dart';

// ignore_for_file: use_build_context_synchronously

class AgingReportScreen extends StatefulWidget {
  const AgingReportScreen({super.key});

  @override
  State<AgingReportScreen> createState() => _AgingReportScreenState();
}

class _AgingReportScreenState extends State<AgingReportScreen> {
  final ClientService _clientService = ClientService();
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final invoices = await _clientService.getInvoices();
    final clients = await _clientService.getClients();

    if (mounted) {
      setState(() {
        _invoices = invoices.map((inv) => inv.toMap()).toList();
        _clients = clients.map((c) => c.toMap()).toList();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _outstandingInvoices {
    return _invoices
        .where((inv) {
          final status = inv['status']?.toString() ?? '';
          return status == 'unpaid' || status == 'partially_paid';
        })
        .map((inv) {
          final total = (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
          final paid = (inv['paid_amount'] as num?)?.toDouble() ?? 0.0;
          final remaining = total - paid;
          final dueDateStr = inv['due_date']?.toString() ?? '';
          DateTime? dueDate;
          if (dueDateStr.isNotEmpty) {
            dueDate = DateTime.tryParse(dueDateStr);
          }
          int? daysOverdue;
          if (dueDate != null && remaining > 0) {
            final today = DateTime.now();
            if (today.isAfter(dueDate)) {
              daysOverdue = today.difference(dueDate).inDays;
            }
          }
          return {
            ...inv,
            'remaining': remaining,
            'dueDate': dueDate,
            'daysOverdue': daysOverdue,
          };
        })
        .where((inv) => (inv['remaining'] as double) > 0.01)
        .toList();
  }

  double get _totalOutstanding {
    return _outstandingInvoices.fold(0.0, (sum, inv) => sum + (inv['remaining'] as double));
  }

  List<Map<String, dynamic>> get _overdueInvoices {
    return _outstandingInvoices.where((inv) => inv['daysOverdue'] != null && inv['daysOverdue']! > 0).toList();
  }

  List<Map<String, dynamic>> get _topLateClients {
    final clientMap = <int, Map<String, dynamic>>{};
    for (final client in _clients) {
      final id = client['id'] as int?;
      if (id != null) {
        clientMap[id] = client;
      }
    }

    final clientDebts = <int, double>{};
    for (final inv in _outstandingInvoices) {
      final clientId = inv['client_id'] as int?;
      if (clientId != null) {
        clientDebts[clientId] = (clientDebts[clientId] ?? 0.0) + (inv['remaining'] as double);
      }
    }

    final sorted = clientDebts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((e) {
      final client = clientMap[e.key];
      return {
        'client_id': e.key,
        'client_name': client?['name']?.toString() ?? 'غير معروف',
        'remaining': e.value,
      };
    }).toList();
  }

  Color _overdueColor(int? days) {
    if (days == null) return Colors.grey;
    if (days > 60) return Colors.red;
    if (days > 30) return Colors.orange;
    return Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
    final totalOutstanding = _totalOutstanding;
    final overdueInvoices = _overdueInvoices;
    final topLateClients = _topLateClients;

    return Scaffold(
      appBar: AppBar(title: const Text('تقرير الديون والفواتير المتبقية')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: AppConstrained(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SummaryCard(
                      title: 'إجمالي المبالغ المتبقية',
                      value: '${totalOutstanding.toStringAsFixed(2)} د.أ',
                      color: Colors.red,
                      isLarge: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'فواتير متأخرة: ${overdueInvoices.length}',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),

                    if (overdueInvoices.isNotEmpty) ...[
                      const Text(
                        'الفواتير المتأخرة عن الاستحقاق',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...overdueInvoices.map((inv) {
                        final days = inv['daysOverdue'] as int? ?? 0;
                        final invoiceNumber = inv['invoice_number']?.toString() ?? '#${inv['id'] ?? '?'}';
                        final clientName = inv['clients']?['name']?.toString() ?? 'بدون اسم';
                        final remaining = inv['remaining'] as double;
                        final dueDate = inv['dueDate'] as DateTime?;
                        final formattedDue = dueDate != null
                             ? DateFormat('dd/MM/yyyy').format(dueDate)
                            : 'غير محدد';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: Icon(Icons.warning_amber_rounded, color: _overdueColor(days)),
                            title: Text(invoiceNumber),
                            subtitle: Text(
                              '$clientName\nتاريخ الاستحقاق: $formattedDue',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${remaining.toStringAsFixed(2)} د.أ',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                ),
                                Text(
                                  '$days يوم تأخير',
                                  style: TextStyle(fontSize: 12, color: _overdueColor(days)),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],

                    if (topLateClients.isNotEmpty) ...[
                      const Text(
                        'الزبائن الأكثر تأخراً في الدفع',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...topLateClients.take(20).map((c) {
                        final remaining = c['remaining'] as double;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.person, color: Colors.blue),
                            title: Text(c['client_name']?.toString() ?? 'غير معروف'),
                            trailing: Text(
                              '${remaining.toStringAsFixed(2)} د.أ',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                          ),
                        );
                      }),
                    ],

                    if (overdueInvoices.isEmpty && topLateClients.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(
                          child: Text(
                            '✅ لا توجد فواتير متأخرة',
                            style: TextStyle(color: Colors.green, fontSize: 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}