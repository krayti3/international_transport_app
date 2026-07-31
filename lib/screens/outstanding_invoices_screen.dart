import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:decimal/decimal.dart';
import 'package:collection/collection.dart';
import 'package:international_transport_app/models/client.dart';
import 'package:international_transport_app/models/invoice.dart';
import '../services/client_service.dart';
import '../services/pdf_service.dart';

// ignore_for_file: use_build_context_synchronously

class OutstandingInvoicesScreen extends StatefulWidget {
  const OutstandingInvoicesScreen({super.key});

  @override
  State<OutstandingInvoicesScreen> createState() => _OutstandingInvoicesScreenState();
}

class _OutstandingInvoicesScreenState extends State<OutstandingInvoicesScreen> {
  final ClientService _clientService = ClientService();
  List<Client> _clients = [];
  List<Invoice> _outstandingInvoices = [];
  int? _selectedClientId;
  Client? _selectedClient;
  bool _isLoadingClients = true;
  bool _isLoadingInvoices = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    final clients = await _clientService.getClients();
    if (mounted) {
      setState(() {
        _clients = clients;
        _isLoadingClients = false;
      });
    }
  }

  Future<void> _onClientSelected(int? clientId) async {
    if (clientId == null) {
      setState(() {
        _selectedClientId = null;
        _selectedClient = null;
        _outstandingInvoices = [];
      });
      return;
    }

    setState(() {
      _selectedClientId = clientId;
      _isLoadingInvoices = true;
      _outstandingInvoices = [];
    });

    try {
      final invoices = await _clientService.getOutstandingInvoices(clientId);
      final client = _clients.firstWhere(
        (c) => c.id == clientId,
        orElse: () => invoices.isNotEmpty ? Client.fromMap(invoices.first.toMap()) : Client(name: '', phone: ''),
      );

      if (mounted) {
        setState(() {
          _outstandingInvoices = invoices;
          _selectedClient = client;
          _isLoadingInvoices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingInvoices = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الفواتير: $e')),
        );
      }
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'partially_paid':
        return Colors.orange;
      case 'unpaid':
      default:
        return Colors.red;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'paid':
        return 'مدفوعة';
      case 'partially_paid':
        return 'مدفوعة جزئياً';
      case 'unpaid':
      default:
        return 'غير مدفوعة';
    }
  }

  Future<void> _previewPdf() async {
    if (_selectedClient == null || _outstandingInvoices.isEmpty) return;

    setState(() => _isExporting = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري إنشاء التقرير...'),
          ],
        ),
      ),
    );

    try {
      await PdfService.instance.previewOutstandingStatement(
        client: _selectedClient!.toMap(),
        invoices: _outstandingInvoices.map((e) => e.toMap()).toList(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء التقرير: $e')),
        );
      }
    } finally {
      if (mounted) {
        Navigator.pop(context);
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _sharePdf() async {
    if (_selectedClient == null || _outstandingInvoices.isEmpty) return;

    setState(() => _isExporting = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري إنشاء التقرير...'),
          ],
        ),
      ),
    );

    try {
      await PdfService.instance.shareOutstandingStatement(
        client: _selectedClient!.toMap(),
        invoices: _outstandingInvoices.map((e) => e.toMap()).toList(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في مشاركة التقرير: $e')),
        );
      }
    } finally {
      if (mounted) {
        Navigator.pop(context);
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _copyWhatsAppMessage() async {
    if (_selectedClient == null || _outstandingInvoices.isEmpty) return;

    final clientName = _selectedClient!.name;

    double totalRemaining = 0.0;
    for (final invoice in _outstandingInvoices) {
      final total = invoice.totalAmount.toDouble();
      final paid = (invoice.paidAmount ?? Decimal.zero).toDouble();
      totalRemaining += (total - paid);
    }

    final message =
        'مرحباً $clientName، إليكم بيان بالفواتير المستجدة والمستحقة للدفع فقط: إجمالي المستحق ${totalRemaining.toStringAsFixed(2)} د.أ موزّع على ${_outstandingInvoices.length} فاتورة. نأمل تسويتها في أقرب وقت ممكن. شكراً لتعاملكم مع شركة النقل الدولي.';

    await Clipboard.setData(ClipboardData(text: message));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ الرسالة')),
      );
    }
  }

  double _getTotalRemaining() {
    double total = 0.0;
    for (final invoice in _outstandingInvoices) {
      final totalAmount = invoice.totalAmount.toDouble();
      final paidAmount = (invoice.paidAmount ?? Decimal.zero).toDouble();
      total += (totalAmount - paidAmount);
    }
    return total;
  }

  bool get _canExport =>
      _selectedClientId != null &&
      !_isLoadingInvoices &&
      _outstandingInvoices.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('كشف المستحقات')),
      body: _isLoadingClients
          ? const Center(child: CircularProgressIndicator())
          : _clients.isEmpty
              ? const Center(child: Text('لا يوجد زبائن حالياً'))
              : Form(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'اختر الزبون',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_search),
                          ),
                           items: _clients
                               .toList()
                                .sorted((a, b) => a.name.compareTo(b.name))
                               .map((c) {
                                 return DropdownMenuItem<int>(
                                   value: c.id,
                                   child: Text(c.name),
                                 );
                               }).toList(),
                          onChanged: (v) => _onClientSelected(v),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _selectedClientId == null
                            ? const Center(
                                child: Text(
                                  'يرجى اختيار زبون لعرض التقرير',
                                  style: TextStyle(fontSize: 16),
                                ),
                              )
                            : _isLoadingInvoices
                                ? const Center(child: CircularProgressIndicator())
                                : _outstandingInvoices.isEmpty
                                    ? const Center(
                                        child: Text('لا توجد فواتير مستحقة لهذا الزبون'),
                                      )
                                    : RefreshIndicator(
                                        onRefresh: () => _onClientSelected(_selectedClientId),
                                        child: ListView(
                                          padding: const EdgeInsets.all(16),
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.red.shade200),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    'إجمالي المستحق: ${_getTotalRemaining().toStringAsFixed(2)} د.أ',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.red.shade800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            ..._outstandingInvoices.map((invoice) => _buildInvoiceCard(invoice)),
                                            const SizedBox(height: 80),
                                          ],
                                        ),
                                      ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: _canExport
          ? FloatingActionButton.extended(
              onPressed: _isExporting ? null : _previewPdf,
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: Text(_isExporting ? 'جاري التصدير...' : 'معاينة PDF'),
              backgroundColor: Colors.redAccent,
            )
          : null,
      bottomNavigationBar: _canExport
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isExporting ? null : _sharePdf,
                        icon: const Icon(Icons.share, size: 20),
                        label: const Text('مشاركة عبر واتساب'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 2,
                      ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isExporting ? null : _copyWhatsAppMessage,
                        icon: const Icon(Icons.copy, size: 20),
                        label: const Text('نسخ رسالة واتساب'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 2,
                      ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    final invoiceNumber = invoice.invoiceNumber;
    final issueDate = invoice.issueDate != null ? DateFormat('dd/MM/yyyy').format(invoice.issueDate!) : '';
    final dueDate = invoice.dueDate != null ? DateFormat('dd/MM/yyyy').format(invoice.dueDate!) : '';
    final totalAmount = invoice.totalAmount.toDouble();
    final paidAmount = (invoice.paidAmount ?? Decimal.zero).toDouble();
    final remaining = totalAmount - paidAmount;
    final status = invoice.status;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  invoiceNumber,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _statusColor(status)),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip('رقم الفاتورة', invoiceNumber),
                ),
                Expanded(
                  child: _buildInfoChip('تاريخ الإصدار', issueDate, textDirection: TextDirection.ltr),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip('تاريخ الاستحقاق', dueDate, textDirection: TextDirection.ltr),
                ),
                Expanded(
                  child: _buildInfoChip('الإجمالي', '${totalAmount.toStringAsFixed(2)} د.أ'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip('المدفوع', '${paidAmount.toStringAsFixed(2)} د.أ'),
                ),
                Expanded(
                  child: _buildAmountChip(
                    label: 'المتبقي',
                    value: '${remaining.toStringAsFixed(2)} د.أ',
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, {TextDirection? textDirection}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          textDirection: textDirection,
        ),
      ],
    );
  }

  Widget _buildAmountChip({required String label, required String value, required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
