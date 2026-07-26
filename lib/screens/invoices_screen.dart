import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart'; // Decimal
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:international_transport_app/models/invoice.dart';
import 'package:international_transport_app/screens/invoice_form_screen.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';
import '../services/excel_service.dart';
import '../models/client.dart';

// ignore_for_file: use_build_context_synchronously

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Invoice> _allInvoices = [];
  bool _isLoading = true;
  String _currentFilter = 'all'; // all, unpaid, partially_paid, paid
  bool _tvaEnabled = false;
  double _tvaPercentage = 0.0;
  Map<String, String> _clientNames = {};
  List<Map<String, dynamic>> _cashBoxes = [];

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    final invoices = await _supabaseService.getInvoices();
    final clients = await _supabaseService.getClients();
    final settings = await _supabaseService.getAppSettings();
    final cashBoxes = await _supabaseService.getCashBoxes();
    setState(() {
      _allInvoices = invoices;
      _clientNames = {for (final c in clients) c.id.toString(): c.name};
      _tvaEnabled = settings?['is_enabled'] as bool? ?? true;
      _tvaPercentage = (settings?['percentage'] as num?)?.toDouble() ?? 0.0;
      _cashBoxes = cashBoxes;
      _isLoading = false;
    });
  }

  /// يشتق قيمة الـ TVA من إجمالي شامل للضريبة (TTC)، تماشياً مع تقرير الأرباح.
  double _tvaOf(double totalTtc) {
    if (!_tvaEnabled || _tvaPercentage <= 0) return 0.0;
    final base = totalTtc / (1 + _tvaPercentage / 100);
    return totalTtc - base;
  }

  List<Invoice> get _filteredInvoices {
    if (_currentFilter == 'all') return _allInvoices;
    return _allInvoices.where((invoice) => invoice.status == _currentFilter).toList();
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

  Future<void> _openRecordPaymentDialog() async {
    final clients = await _supabaseService.getClients();
    final pendingClientIds = _allInvoices
        .where((invoice) => invoice.status != 'paid')
        .map((invoice) => invoice.clientId)
        .toSet();
    final pendingClients = clients.where((client) => pendingClientIds.contains(client.id.toString())).toList();

    final selectedClientController = ValueNotifier<Client?>(null);
    final amountController = TextEditingController();
    final methodController = TextEditingController();
    final refController = TextEditingController();
    final modeController = ValueNotifier<int>(0); // 0 = تلقائي (FIFO), 1 = يدوي
    final Map<int, TextEditingController> allocControllers = {};
    int? lastAllocClientId;
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    // يبني قسم التوزيع اليدوي لفواتير الزبون المختار
    Widget buildManualSection(Client? selectedClient) {
      if (selectedClient == null) return const SizedBox.shrink();
      final clientId = selectedClient.id;
      final pending = _allInvoices.where((i) =>
        i.clientId == clientId.toString() && i.status != 'paid').toList();

      if (lastAllocClientId != clientId) {
        allocControllers.clear();
        for (final inv in pending) {
          final remaining = inv.totalAmount - (inv.paidAmount ?? Decimal.zero);
          allocControllers[inv.id!] = TextEditingController(text: remaining.toStringAsFixed(2));
        }
        lastAllocClientId = clientId;
      }

      if (pending.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text('لا توجد فواتير معلّقة لهذا الزبون', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        );
      }

      double allocatedSum = 0;
      for (final c in allocControllers.values) {
        allocatedSum += double.tryParse(c.text.trim()) ?? 0;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const Divider(),
          const Text('التوزيع اليدوي على الفواتير', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...pending.map((inv) {
            final id = inv.id!;
            final number = inv.invoiceNumber;
            final remaining = inv.totalAmount - (inv.paidAmount ?? Decimal.zero);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text('$number\nالمتبقي: ${remaining.toStringAsFixed(2)} د.أ',
                        style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: allocControllers[id],
                      decoration: const InputDecoration(labelText: 'المبلغ', isDense: true),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Text('إجمالي المخصص: ${allocatedSum.toStringAsFixed(2)} د.أ',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        ],
      );
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => ValueListenableBuilder<Client?>(
        valueListenable: selectedClientController,
        builder: (context, selectedClient, _) {
          return StatefulBuilder(
            builder: (context, setStateDialog) => AlertDialog(
              title: const Text('تسجيل دفعة على الحساب'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 0, label: Text('توزيع تلقائي')),
                          ButtonSegment(value: 1, label: Text('توزيع يدوي')),
                        ],
                        selected: {modeController.value},
                        onSelectionChanged: (set) {
                          modeController.value = set.first;
                          setStateDialog(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Client>(
                        decoration: const InputDecoration(labelText: 'الزبون'),
                        initialValue: selectedClient,
                        items: pendingClients.isEmpty
                            ? null
                            : pendingClients
                                .toList()
                                .sorted((a, b) => a.name.compareTo(b.name))
                                .map(
                                  (client) => DropdownMenuItem<Client>(
                                    value: client,
                                    child: Text(client.name),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          selectedClientController.value = value;
                          setStateDialog(() {});
                        },
                        validator: (value) => value == null ? 'يرجى اختيار الزبون' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amountController,
                        decoration: const InputDecoration(labelText: 'المبلغ الإجمالي المدفوع'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'يرجى إدخال المبلغ';
                          final parsed = double.tryParse(value.trim());
                          if (parsed == null || parsed <= 0) return 'يرجى إدخال مبلغ صحيح';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                        initialValue: _cashBoxes.isNotEmpty ? _cashBoxes.first['code']?.toString() : null,
                        items: _cashBoxes.isEmpty
                            ? null
                            : _cashBoxes.map((b) {
                                return DropdownMenuItem(
                                  value: b['code']?.toString(),
                                  child: Text(b['label']?.toString() ?? ''),
                                );
                              }).toList(),
                        onChanged: (value) => methodController.text = value ?? '',
                        validator: (value) => value == null || value.isEmpty ? 'يرجى اختيار طريقة الدفع' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: refController,
                        decoration: const InputDecoration(labelText: 'الرقم المرجعي (اختياري)'),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: modeController,
                        builder: (_, mode, _) => mode == 1
                            ? buildManualSection(selectedClient)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final selectedClient = selectedClientController.value;
                          final clientId = selectedClient?.id;
                          final totalAmountPaid = Decimal.tryParse(amountController.text.trim()) ?? Decimal.zero;
                          final method = methodController.text.trim();
                          final ref = refController.text.trim();

                          if (clientId == null || totalAmountPaid <= Decimal.zero || method.isEmpty) return;

                          if (modeController.value == 1) {
                            // توزيع يدوي
                            final allocations = <Map<String, dynamic>>[];
                            Decimal sumAlloc = Decimal.zero;
                            for (final entry in allocControllers.entries) {
                              final amt = Decimal.tryParse(entry.value.text.trim()) ?? Decimal.zero;
                              if (amt > Decimal.zero) {
                                allocations.add({'invoice_id': entry.key, 'amount': amt});
                                sumAlloc += amt;
                              }
                            }
                            if (allocations.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('يرجى تحديد مبالغ للفواتير')),
                              );
                              return;
                            }
                            if ((sumAlloc - totalAmountPaid).abs() > Decimal.parse('0.01')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('مجموع التوزيع يجب أن يساوي المبلغ الإجمالي')),
                              );
                              return;
                            }
                            setStateDialog(() => isSubmitting = true);
                            try {
                              await _supabaseService.recordManualPayment(
                                clientId: clientId,
                                 totalAmountPaid: totalAmountPaid.toDouble(),
                                method: method,
                                ref: ref,
                                allocations: allocations,
                              );
                              if (!mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم تسجيل الدفعة وتوزيعها يدوياً بنجاح')),
                              );
                              await _loadInvoices();
                            } catch (e) {
                              setStateDialog(() => isSubmitting = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('خطأ: $e')),
                                );
                              }
                            }
                            return;
                          }

                          // توزيع تلقائي (FIFO) — السلوك الأصلي كما هو
                          setStateDialog(() => isSubmitting = true);
                          try {
                            await _supabaseService.recordBulkPayment(
                              clientId,
                               totalAmountPaid.toDouble(),
                              method,
                              ref,
                            );
                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم تسجيل الدفعة وتوزيعها بنجاح')),
                            );
                            await _loadInvoices();
                          } catch (e) {
                            setStateDialog(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('خطأ: $e')),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('تأكيد السداد'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openRecordInvoicePaymentDialog(Invoice invoice) async {
    if (!mounted) return;
    final invoiceId = invoice.id;
    if (invoiceId == null) return;

    final invoiceNumber = invoice.invoiceNumber;
    final clientName = _clientNames[invoice.clientId] ?? 'Unknown';
    final totalAmount = invoice.totalAmount;
    final paidAmount = invoice.paidAmount ?? Decimal.zero;
    final remainingAmount = totalAmount - paidAmount;

    final amountController = TextEditingController();
    final methodController = TextEditingController();
    final refController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('تسجيل دفعة - $invoiceNumber'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('الزبون: $clientName', style: const TextStyle(fontWeight: FontWeight.bold)),
                   Text('المتبقي: ${remainingAmount.toStringAsFixed(2)} د.أ',
                       style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'مبلغ الدفعة',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'يرجى إدخال المبلغ';
                      final parsed = Decimal.tryParse(value.trim());
                      if (parsed == null || parsed <= Decimal.zero) return 'يرجى إدخال مبلغ صحيح';
                      if (parsed > remainingAmount) return 'المبلغ يتجاوز المتبقي (${remainingAmount.toStringAsFixed(2)})';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'طريقة الدفع',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _cashBoxes.isNotEmpty ? _cashBoxes.first['code']?.toString() : null,
                    items: _cashBoxes.isEmpty
                        ? null
                        : _cashBoxes.map((b) {
                            return DropdownMenuItem(
                              value: b['code']?.toString(),
                              child: Text(b['label']?.toString() ?? ''),
                            );
                          }).toList(),
                    onChanged: (value) => methodController.text = value ?? '',
                    validator: (value) => value == null || value.isEmpty ? 'يرجى اختيار طريقة الدفع' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: refController,
                    decoration: const InputDecoration(
                      labelText: 'الرقم المرجعي (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setStateDialog(() => isSubmitting = true);

                      try {
                        final amount = Decimal.tryParse(amountController.text.trim()) ?? Decimal.zero;
                        final method = methodController.text.trim();
                        final ref = refController.text.trim();
                        final newPaidAmount = paidAmount + amount;

                        await _supabaseService.addInvoicePayment({
                          'invoice_id': invoiceId,
                          'amount_paid': amount.toString(),
                          'payment_method': method,
                          'receipt_reference': ref,
                        });

                        await _supabaseService.updateInvoiceStatus(invoiceId, newPaidAmount.toDouble());

                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم تسجيل الدفعة بنجاح')),
                        );
                        await _loadInvoices();
                      } catch (e) {
                        setStateDialog(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطأ: $e')),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportInvoicesExcel() async {
    final invoices = _filteredInvoices;
    if (invoices.isEmpty) return;

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
      final bytes = await ExcelService.instance.exportInvoices(invoices.map((e) => e.toMap()).toList());
      await ExcelService.instance.shareExcel(bytes, 'الفواتير');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء Excel: $e')),
        );
      }
    }
    finally {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _exportInvoicePdf(Invoice invoice) async {
    final invoiceId = invoice.id;
    if (invoiceId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري إنشاء الفاتورة...'),
          ],
        ),
      ),
    );

    try {
      final payments = await _supabaseService.getInvoicePayments(invoiceId);
      await PdfService.instance.previewInvoice(
        invoice: invoice,
        payments: payments,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء الفاتورة: $e')),
        );
      }
    }
    finally {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _printInvoice(Invoice invoice) async {
    final invoiceId = invoice.id;
    if (invoiceId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري الطباعة...'),
          ],
        ),
      ),
    );

    try {
      final payments = await _supabaseService.getInvoicePayments(invoiceId);
      final pdfBytes = await PdfService.instance.buildInvoicePdf(
        invoice: invoice,
        payments: payments,
      );
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الطباعة: $e')),
        );
      }
    }
    finally {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الفواتير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InvoiceFormScreen()),
              ).then((_) => _loadInvoices());
            },
            tooltip: 'إنشاء فاتورة',
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            onPressed: _exportInvoicesExcel,
            tooltip: 'تصدير Excel',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final selected = _filteredInvoices;
              if (selected.isEmpty) return;
              if (selected.length == 1) {
                await _exportInvoicePdf(selected.first);
              } else {
                // If multiple invoices selected, just export the first or show a dialog
                await _exportInvoicePdf(selected.first);
              }
            },
            tooltip: 'تصدير PDF',
          ),
          IconButton(
            icon: const Icon(Icons.payment),
            onPressed: _openRecordPaymentDialog,
            tooltip: 'تسجيل دفعة',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: widget.isAdmin ? () async {
              final selected = _filteredInvoices;
              if (selected.isEmpty) return;
              if (selected.length == 1) {
                await _printInvoice(selected.first);
              } else {
                await _printInvoice(selected.first);
              }
            } : null,
            tooltip: 'طباعة',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: widget.isAdmin ? () {
              // Delete logic placeholder
            } : null,
            tooltip: 'حذف',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsHeader(),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'الكل',
                  isSelected: _currentFilter == 'all',
                  onTap: () => setState(() => _currentFilter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'غير مدفوعة',
                  isSelected: _currentFilter == 'unpaid',
                  onTap: () => setState(() => _currentFilter = 'unpaid'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'مدفوعة جزئياً',
                  isSelected: _currentFilter == 'partially_paid',
                  onTap: () => setState(() => _currentFilter = 'partially_paid'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'مدفوعة',
                  isSelected: _currentFilter == 'paid',
                  onTap: () => setState(() => _currentFilter = 'paid'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Invoices List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredInvoices.isEmpty
                    ? const Center(child: Text('لا يوجد فواتير مطابقة للتصفية'))
                    : RefreshIndicator(
                        onRefresh: _loadInvoices,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredInvoices.length,
                          itemBuilder: (context, index) {
                            final invoice = _filteredInvoices[index];
                             final clientName = _clientNames[invoice.clientId] ?? 'Unknown';
                             final totalAmount = invoice.totalAmount.toDouble();
                            final paidAmount = invoice.paidAmount?.toDouble() ?? 0.0;
                            final remainingAmount = totalAmount - paidAmount;
                            final progress = totalAmount > 0 ? paidAmount / totalAmount : 0.0;
                            final status = invoice.status;
                            final invoiceNumber = invoice.invoiceNumber;
                            final dueDate = invoice.dueDate?.toString() ?? '';

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          invoiceNumber,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _statusColor(status).withAlpha(30),
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
                                    const SizedBox(height: 8),
                                    Text('الزبون: $clientName', style: const TextStyle(fontSize: 14)),
                                    const SizedBox(height: 4),
                                    if (dueDate.isNotEmpty)
                                      Text('تاريخ الاستحقاق: $dueDate', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                    const SizedBox(height: 12),

                                    // Progress
                                    Row(
                                      children: [
                                        Expanded(
                                          child: LinearProgressIndicator(
                                            value: progress.clamp(0.0, 1.0),
                                            minHeight: 8,
                                            color: _statusColor(status),
                                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text('${(progress * 100).toStringAsFixed(0)}%'),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Amounts
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('الإجمالي: ${totalAmount.toStringAsFixed(2)}${_tvaEnabled ? '  •  TVA: ${_tvaOf(totalAmount).toStringAsFixed(2)}' : ''}'),
                                         Text(
                                          'المتبقي: ${remainingAmount.toStringAsFixed(2)}',
                                          style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold),
                                        ),
                                       ],
                                     ),
                                     const SizedBox(height: 12),
                                     Row(
                                       children: [
                                         Expanded(
                                           child: TextButton.icon(
                                             onPressed: () => _openRecordInvoicePaymentDialog(invoice),
                                             icon: const Icon(Icons.payments, size: 18),
                                             label: const Text('تسجيل دفعة'),
                                           ),
                                         ),
                                         Expanded(
                                           child: TextButton.icon(
                                             onPressed: () => _exportInvoicePdf(invoice),
                                             icon: const Icon(Icons.picture_as_pdf, size: 18),
                                             label: const Text('PDF'),
                                           ),
                                         ),
                                         Expanded(
                                           child: TextButton.icon(
                                             onPressed: () => _printInvoice(invoice),
                                             icon: const Icon(Icons.print, size: 18),
                                             label: const Text('طباعة'),
                                           ),
                                         ),
                                       ],
                                     ),
                                   ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ملخص مالي علوي بأرقام حقيقية محسوبة من الفواتير المحمّلة.
  Widget _buildStatsHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    double totalReceivable = 0;
    double totalTva = 0;
    int unpaidCount = 0;
    for (final inv in _allInvoices) {
      final total = inv.totalAmount.toDouble();
      final paid = inv.paidAmount?.toDouble() ?? 0.0;
      totalReceivable += (total - paid);
      totalTva += _tvaOf(total);
      if (inv.status != 'paid') unpaidCount++;
    }

    final cards = <Widget>[
      _buildStatCard(
        'إجمالي المستحقات',
        NumberFormat('#,###.00').format(totalReceivable),
        Icons.account_balance_wallet_rounded,
        colorScheme.primary,
      ),
      _buildStatCard(
        'فواتير غير مسددة',
        '$unpaidCount',
        Icons.receipt_long_rounded,
        colorScheme.tertiary,
      ),
      if (_tvaEnabled)
        _buildStatCard(
          'ضريبة TVA (${_tvaPercentage.toStringAsFixed(0)}%)',
          NumberFormat('#,###.00').format(totalTva),
          Icons.account_balance_rounded,
          colorScheme.secondary,
        ),
      _buildStatCard(
        'إجمالي الفواتير',
        '${_allInvoices.length}',
        Icons.analytics_rounded,
        colorScheme.primary,
      ),
    ];

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withAlpha(30),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(context).primaryColor.withAlpha(50),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }
}
