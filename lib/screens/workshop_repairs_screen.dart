import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:international_transport_app/models/repair_invoice.dart';
import '../services/supabase_service.dart';
import '../services/workshop_payment_service.dart';
import 'repair_invoice_form_screen.dart';
import 'workshop_payment_preview_screen.dart';

// ignore_for_file: use_build_context_synchronously

class WorkshopRepairInvoicesScreen extends StatefulWidget {
  final String workshopId;
  final String workshopName;
  final bool isAdmin;

  const WorkshopRepairInvoicesScreen({
    super.key,
    required this.workshopId,
    required this.workshopName,
    this.isAdmin = false,
  });

  @override
  State<WorkshopRepairInvoicesScreen> createState() =>
      _WorkshopRepairInvoicesScreenState();
}

class _WorkshopRepairInvoicesScreenState
    extends State<WorkshopRepairInvoicesScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<RepairInvoice> _invoices = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _expensesOnCredit = [];
  String _filterStatus = 'all';
  String? _selectedWorkshopId;
  List<Map<String, dynamic>> _workshopOptions = [];

  @override
  void initState() {
    super.initState();
    _loadInvoices();
    _loadExpensesOnCredit();
    if (widget.workshopId.isEmpty) {
      _loadWorkshopOptions();
    }
  }

  Future<void> _loadWorkshopOptions() async {
    final providers = await _supabaseService.getProviders();
    if (mounted) {
      setState(() => _workshopOptions = providers);
    }
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    final invoices =
        await _supabaseService.getRepairInvoices(workshopId: _effectiveWorkshopId);
    setState(() {
      _invoices = invoices;
      _isLoading = false;
    });
  }

  Future<void> _loadExpensesOnCredit() async {
    final combined = <Map<String, dynamic>>[];
    final truckExpenses = await _supabaseService.getTruckMaintenancesFiltered(
      paymentStatus: 'on_credit',
    );
    for (final row in truckExpenses) {
      final doc = Map<String, dynamic>.from(row);
      doc['vehicle_type'] = 'شاحنة';
      doc['vehicle_id'] = doc['truck_id'];
      combined.add(doc);
    }
    final trailerExpenses = await _supabaseService.getTrailerMaintenancesFiltered(
      paymentStatus: 'on_credit',
    );
    for (final row in trailerExpenses) {
      final doc = Map<String, dynamic>.from(row);
      doc['vehicle_type'] = 'مقطورة';
      doc['vehicle_id'] = doc['trailer_id'];
      combined.add(doc);
    }
    // Filter to selected workshop only
    if (_effectiveWorkshopName.isNotEmpty) {
      combined.removeWhere(
        (e) => (e['provider_name']?.toString() ?? '') != _effectiveWorkshopName,
      );
    }
    combined.sort((a, b) {
      final aDate = a['maintenance_date']?.toString() ?? '';
      final bDate = b['maintenance_date']?.toString() ?? '';
      return bDate.compareTo(aDate);
    });
    if (mounted) {
      setState(() => _expensesOnCredit = combined);
    }
  }

  String? get _effectiveWorkshopId {
    if (widget.workshopId.isNotEmpty) return widget.workshopId;
    return _selectedWorkshopId;
  }

  String get _effectiveWorkshopName {
    if (widget.workshopId.isNotEmpty) return widget.workshopName;
    if (_selectedWorkshopId != null) {
      return _workshopOptions.firstWhere(
              (p) => (p['id']?.toString() ?? '') == _selectedWorkshopId)
          ['name']
          ?.toString() ??
          widget.workshopName;
    }
    return widget.workshopName;
  }

  List<RepairInvoice> get _filteredInvoices {
    var list = _invoices;
    if (_effectiveWorkshopId != null && widget.workshopId.isEmpty) {
      list = list
          .where((inv) => inv.workshopId == _effectiveWorkshopId)
          .toList();
    }
    if (_filterStatus == 'all') return list;
    return list.where((inv) => inv.status == _filterStatus).toList();
  }

  Decimal get _totalRemaining {
    final invoices = _effectiveWorkshopId != null && widget.workshopId.isEmpty
        ? _invoices.where((i) => i.workshopId == _effectiveWorkshopId).toList()
        : _invoices;
    return WorkshopPaymentService.calculateTotalRemaining(
      invoices.where((i) => i.status != 'paid').toList(),
    );
  }

  Decimal get _totalPaid {
    final invoices = _effectiveWorkshopId != null && widget.workshopId.isEmpty
        ? _invoices.where((i) => i.workshopId == _effectiveWorkshopId).toList()
        : _invoices;
    return WorkshopPaymentService.calculateTotalPaid(invoices);
  }

  Decimal get _totalAmount {
    final invoices = _effectiveWorkshopId != null && widget.workshopId.isEmpty
        ? _invoices.where((i) => i.workshopId == _effectiveWorkshopId).toList()
        : _invoices;
    Decimal sum = Decimal.zero;
    for (final inv in invoices) {
      sum += inv.totalAmount;
    }
    return sum;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'partially_paid':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'مدفوعة';
      case 'partially_paid':
        return 'مدفوعة جزئياً';
      default:
        return 'غير مدفوعة';
    }
  }

  Widget _buildSettleButton() {
    final canSettle = widget.workshopId.isNotEmpty || _selectedWorkshopId != null;
    final hasUnpaid = _filteredInvoices.any((i) => i.status != 'paid');
    return FilledButton.icon(
      onPressed: canSettle && hasUnpaid ? _openSettlePaymentDialog : null,
      icon: const Icon(Icons.payment),
      label: const Text('تسوية دفعة'),
    );
  }

  void _openSettlePaymentDialog() {
    if (_filteredInvoices.isEmpty) return;
    final effectiveWorkshopId = _effectiveWorkshopId ?? widget.workshopId;
    Map<String, dynamic>? workshopOption;
    for (final p in _workshopOptions) {
      if ((p['id']?.toString() ?? '') == effectiveWorkshopId) {
        workshopOption = p;
        break;
      }
    }
    final effectiveWorkshopName = widget.workshopId.isNotEmpty
        ? widget.workshopName
        : (workshopOption != null
            ? workshopOption['name']?.toString() ?? effectiveWorkshopId
            : effectiveWorkshopId);
    final amountController = TextEditingController();
    final methodController = TextEditingController();
    final refController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    int mode = 0;
    final selectedInvoiceIds = <int>{};

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: Text('تسوية ديون "$effectiveWorkshopName"'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إجمالي المتبقي: ${_totalRemaining.toStringAsFixed(2)} DH',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'مبلغ الدفعة (DH)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payments),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'أدخل مبلغ الدفعة';
                        }
                        final val = double.tryParse(v.trim());
                        if (val == null || val <= 0) {
                          return 'المبلغ غير صالح';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: mode,
                      decoration: const InputDecoration(
                        labelText: 'طريقة التوزيع',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 0,
                          child: Text('تلقائي (FIFO - أقدم فاتورة أولاً)'),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text('يدوي (اختيار الفواتير)'),
                        ),
                      ],
                      onChanged: (v) {
                        setStateDialog(() => mode = v!);
                      },
                    ),
                    if (mode == 1) ...[
                      const SizedBox(height: 12),
                      const Text('اختر الفواتير المراد تسوياتها:'),
                      const SizedBox(height: 8),
                      ..._filteredInvoices.map((inv) {
                        return CheckboxListTile(
                          value: selectedInvoiceIds.contains(inv.id!),
                           onChanged: (v) {
                            setStateDialog(() {
                              if (v == true) {
                                selectedInvoiceIds.add(inv.id!);
                              } else {
                                selectedInvoiceIds.remove(inv.id!);
                              }
                            });
                          },
                          title: Text(inv.invoiceNumber),
                          subtitle: Text(
                              'المتبقي: ${inv.remainingAmount.toStringAsFixed(2)} DH • ${inv.status == 'paid' ? 'مدفوعة' : inv.status == 'partially_paid' ? 'مدفوعة جزئياً' : 'غير مدفوعة'}'),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        );
                      }),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: methodController,
                      decoration: const InputDecoration(
                        labelText: 'طريقة الدفع',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payment),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: refController,
                      decoration: const InputDecoration(
                        labelText: 'المرجع (رقم الشيك / وصل)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظة اختيارية',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  if (mode == 1 && selectedInvoiceIds.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content: Text('اختر فاتورة واحدة على الأقل')),
                    );
                    return;
                  }
                  final unpaidInvoices = _filteredInvoices
                      .where((i) => i.status != 'paid')
                      .toList();
                  final previewResult = await Navigator.push<WorkshopPaymentResult>(
                    ctx,
                    MaterialPageRoute(
                      builder: (ctx) => WorkshopPaymentPreviewScreen(
                        workshopName: effectiveWorkshopName,
                        invoices: unpaidInvoices,
                        paymentAmount: double.parse(amountController.text.trim()),
                        method: methodController.text.trim(),
                        ref: refController.text.trim(),
                        note: noteController.text.trim(),
                      ),
                    ),
                  );
                  if (!mounted || previewResult == null) return;
                  await _processPayment(
                    amount: double.parse(amountController.text.trim()),
                    method: methodController.text.trim(),
                    ref: refController.text.trim(),
                    note: noteController.text.trim(),
                    mode: mode,
                    manualInvoiceIds: mode == 1
                        ? selectedInvoiceIds.toList()
                        : null,
                    result: previewResult,
                    workshopId: effectiveWorkshopId,
                    workshopName: effectiveWorkshopName,
                  );
                  if (mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('عرض التوزيع'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _processPayment({
    required double amount,
    required String method,
    required String ref,
    required String note,
    required int mode,
    List<int>? manualInvoiceIds,
    WorkshopPaymentResult? result,
    required String workshopId,
    required String workshopName,
  }) async {
    try {
      await _supabaseService.recordWorkshopPayment(
        workshopId: workshopId,
        amount: amount,
        method: method,
        ref: ref,
        mode: mode,
        manualInvoiceIds: manualInvoiceIds,
        note: note,
      );
      if (!mounted) return;
      setState(() {});
      _loadInvoices();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'تم تسجيل دفعة بمبلغ ${amount.toStringAsFixed(2)} DH بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
  }

  Future<void> _settleExpenseDebt(Map<String, dynamic> expense) async {
    final status = expense['payment_status']?.toString() ?? '';
    final newStatus = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تصفية دين المصروف'),
        content: Text(
            'هل تريد تصفية دين "${expense['expense_type']}" بقيمة ${((expense['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)} DH كـ "${_paymentStatusLabel(status)}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('إلغاء')),
          PopupMenuButton<String>(
            onSelected: (v) => Navigator.pop(ctx, v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'paid_by_owner', child: Text('دفع كاش من صاحب الشركة')),
              const PopupMenuItem(value: 'bank_transfer', child: Text('تحويل بنكي من صاحب الشركة')),
              const PopupMenuItem(value: 'secretary_cash', child: Text('دفع من خزينة السكرتيرة')),
            ],
            child: const Icon(Icons.check_rounded, color: Colors.green),
          ),
        ],
      ),
    );
    if (newStatus == null || newStatus == 'cancel') return;

    final id = expense['id'] as int?;
    final vehicleType = expense['vehicle_type']?.toString() ?? '';
    if (id == null) return;
    try {
      if (vehicleType == 'شاحنة') {
        await _supabaseService.updateTruckMaintenance(id, {'payment_status': newStatus});
      } else {
        await _supabaseService.updateTrailerMaintenance(id, {'payment_status': newStatus});
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تصفية الدين بنجاح')),
      );
      _loadExpensesOnCredit();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  String _paymentStatusLabel(String status) {
    switch (status) {
      case 'bank_transfer': return 'تحويل بنكي';
      case 'on_credit': return 'على الحساب (دَين)';
      case 'secretary_cash': return 'الكاش من خزينة السكرتيرة';
      case 'paid_by_owner': return 'الكاش من صاحب الشركة';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredInvoices;

    return Scaffold(
      appBar: AppBar(
        title: Text('فواتير $_effectiveWorkshopName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _loadInvoices();
              _loadExpensesOnCredit();
            },
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ملخص المبالغ
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E1E)
                        : Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.primary
                            .withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text('الإجمالي',
                                style: TextStyle(fontSize: 12)),
                            Text(
                              '${_totalAmount.toStringAsFixed(2)} DH',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('المدفوع',
                                style: TextStyle(fontSize: 12)),
                            Text(
                              '${_totalPaid.toStringAsFixed(2)} DH',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('المتبقي',
                                style: TextStyle(fontSize: 12)),
                            Text(
                              '${_totalRemaining.toStringAsFixed(2)} DH',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // الفلاتر وزر التسوية
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      if (widget.workshopId.isEmpty)
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedWorkshopId,
                            decoration: const InputDecoration(
                              labelText: 'اختر الورشة',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.business),
                            ),
                            hint: const Text('اختر ورشة'),
                            items: _workshopOptions.map((provider) {
                              return DropdownMenuItem<String>(
                                value: provider['id']?.toString() ?? '',
                                child: Text(provider['name']?.toString() ?? ''),
                              );
                            }).toList(),
                            onChanged: (v) {
                              setState(() => _selectedWorkshopId = v);
                              _loadInvoices();
                            },
                          ),
                        ),
                      if (widget.workshopId.isNotEmpty)
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _filterStatus,
                            decoration: const InputDecoration(
                              labelText: 'الحالة',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('الكل')),
                              DropdownMenuItem(
                                  value: 'unpaid', child: Text('غير مدفوعة')),
                              DropdownMenuItem(
                                  value: 'partially_paid',
                                  child: Text('مدفوعة جزئياً')),
                              DropdownMenuItem(
                                  value: 'paid', child: Text('مدفوعة')),
                            ],
                            onChanged: (v) => setState(() => _filterStatus = v!),
                          ),
                        ),
                      const SizedBox(width: 8),
                      _buildSettleButton(),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // القائمة
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('لا توجد فواتير مطابقة',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final inv = filtered[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      _statusColor(inv.status).withValues(alpha: 0.15),
                                  child: Icon(
                                    inv.status == 'paid'
                                        ? Icons.check_circle_rounded
                                        : inv.status == 'partially_paid'
                                            ? Icons.auto_awesome_mosaic_rounded
                                            : Icons.receipt_rounded,
                                    color: _statusColor(inv.status),
                                  ),
                                ),
                                title: Text(inv.invoiceNumber),
                                subtitle: Text(
                                    '${inv.date != null ? "${inv.date!.day}/${inv.date!.month}/${inv.date!.year}" : ""} • ${inv.totalAmount.toStringAsFixed(2)} DH'),
                                trailing: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${inv.remainingAmount.toStringAsFixed(2)} DH',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _statusColor(inv.status),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: _statusColor(inv.status)
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        border: Border.all(
                                            color:
                                                _statusColor(inv.status)),
                                      ),
                                      child: Text(
                                        _statusLabel(inv.status),
                                        style: TextStyle(
                                          color: _statusColor(inv.status),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                 ),
                 if (_expensesOnCredit.isNotEmpty) ...[
                   const Padding(
                     padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                     child: Row(
                       children: [
                         Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                         SizedBox(width: 8),
                         Text(
                           'ديون المصروفات',
                           style: TextStyle(
                             fontSize: 16,
                             fontWeight: FontWeight.bold,
                             color: Colors.red,
                           ),
                         ),
                       ],
                     ),
                   ),
                   ..._expensesOnCredit.map((expense) {
                     final amount = (expense['amount'] as num?)?.toDouble() ?? 0.0;
                     final expenseType = expense['expense_type']?.toString() ?? '';
                     final vehicleType = expense['vehicle_type']?.toString() ?? '';
                     final vehicleId = expense['vehicle_id'];
                     final dateStr = expense['maintenance_date']?.toString() ?? '';
                     final desc = expense['description']?.toString() ?? '';
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        color: Colors.red.withValues(alpha: 0.05),
                        child: ListTile(
                         leading: const Icon(Icons.build_rounded, color: Colors.red),
                         title: Text(expenseType),
                         subtitle: Text(
                            '$vehicleType #$vehicleId\n$dateStr${desc.isNotEmpty ? " • $desc" : ""}',
                         ),
                         trailing: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Text(
                               '${amount.toStringAsFixed(2)} DH',
                               style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                             ),
                             const SizedBox(width: 4),
                             PopupMenuButton<String>(
                               onSelected: (value) {
                                 _settleExpenseDebt(expense);
                               },
                               itemBuilder: (_) => [
                                 const PopupMenuItem(value: 'paid_by_owner', child: Text('دفع كاش من صاحب الشركة')),
                                 const PopupMenuItem(value: 'bank_transfer', child: Text('تحويل بنكي من صاحب الشركة')),
                                 const PopupMenuItem(value: 'secretary_cash', child: Text('دفع من خزينة السكرتيرة')),
                               ],
                               child: Icon(Icons.payment_rounded, color: Colors.green, size: 20),
                             ),
                           ],
                         ),
                       ),
                     );
                   }),
                   const SizedBox(height: 12),
                 ],
               ],
             ),
       floatingActionButton: FloatingActionButton.extended(
         icon: const Icon(Icons.add_rounded),
         label: const Text('فاتورة جديدة'),
         onPressed: () {
           Navigator.push(
             context,
             MaterialPageRoute(
                   builder: (ctx) => RepairInvoiceFormScreen(
                     workshopId: _effectiveWorkshopId ?? widget.workshopId,
                     workshopName: _effectiveWorkshopName,
                   ),
             ),
           );
         },
       ),
     );
   }
 }
