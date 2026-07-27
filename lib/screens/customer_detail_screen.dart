import 'package:international_transport_app/widgets/date_wheel_picker.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:decimal/decimal.dart';
import 'package:international_transport_app/models/bank_account.dart';
import 'package:international_transport_app/models/invoice.dart';
import '../services/supabase_service.dart';

// ignore_for_file: use_build_context_synchronously

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({
    super.key,
    required this.client,
    required this.onDeleted,
    required this.onUpdated,
  });

  final Map<String, dynamic> client;
  final VoidCallback onDeleted;
  final VoidCallback onUpdated;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Invoice> _allInvoices = [];
  List<BankAccount> _bankAccounts = [];
  bool _isLoading = true;
  String _currentFilter = 'all'; // all, unpaid, partially_paid, paid
  List<Map<String, dynamic>> _cashBoxes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final clientId = widget.client['id'] as int?;
      if (clientId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final allInvoices = await _supabaseService.getInvoices();
      final clientInvoices = allInvoices
          .where((inv) => inv.clientId == clientId.toString())
          .toList();

      if (!mounted) return;
      final bankAccounts = await _supabaseService.getBankAccounts();
      final cashBoxes = await _supabaseService.getCashBoxes();
      setState(() {
        _allInvoices = clientInvoices;
        _bankAccounts = bankAccounts;
        _cashBoxes = cashBoxes;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading customer data: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Invoice> get _filteredInvoices {
    if (_currentFilter == 'all') return _allInvoices;
    return _allInvoices.where((inv) => inv.status == _currentFilter).toList();
  }

  Decimal get _totalDue {
    Decimal total = Decimal.zero;
    for (final inv in _allInvoices) {
      total += inv.totalAmount - (inv.paidAmount ?? Decimal.zero);
    }
    return total;
  }

  int get _pendingCount {
    return _allInvoices.where((inv) => inv.status != 'paid').length;
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

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final parsed = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  String _getBankAccountName(String? bankAccountId) {
    if (bankAccountId == null || bankAccountId.isEmpty) return '—';
    try {
      final account = _bankAccounts.firstWhere((a) => a.id == bankAccountId);
      return account.displayName;
    } on StateError {
      return '—';
    }
  }

  Future<void> _openAddInvoiceDialog() async {
    final amountController = TextEditingController();
    final inputMode = ValueNotifier<String>('HT');
    final bankAccounts = await _supabaseService.getBankAccounts();
    String? selectedBankAccountType = widget.client['default_bank_account']?.toString();
    if (selectedBankAccountType == null || (selectedBankAccountType != 'moroccan' && selectedBankAccountType != 'european')) {
      final fallbackId = widget.client['default_bank_account_id']?.toString();
      if (fallbackId == 'moroccan' || fallbackId == 'european') {
        selectedBankAccountType = fallbackId;
      } else {
        selectedBankAccountType = 'moroccan';
      }
    }
    String? selectedBankAccountId = widget.client['default_bank_account_id']?.toString();
    DateTime? issueDate = DateTime.now();
    DateTime? dueDate = DateTime.now().add(const Duration(days: 30));

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة فاتورة جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'الحساب البنكي'),
                  initialValue: selectedBankAccountId,
                  items: bankAccounts
                      .toList()
                      .sorted((a, b) => a.displayName.compareTo(b.displayName))
                      .map((ba) => DropdownMenuItem(
                                value: ba.id,
                                child: Text(ba.displayName),
                          ))
                      .toList(),
                  onChanged: (value) => setDialogState(() => selectedBankAccountId = value),
                ),
                 DropdownButtonFormField<String>(
                   decoration: const InputDecoration(labelText: 'نوع الحساب البنكي', border: OutlineInputBorder()),
                   initialValue: selectedBankAccountType,
                   items: const [
                     DropdownMenuItem(value: 'moroccan', child: Text('🇲🇦 الحساب المغربي (MAD)')),
                     DropdownMenuItem(value: 'european', child: Text('🇪🇺 الحساب الأوروبي (EUR)')),
                   ],
                   onChanged: (value) => setDialogState(() => selectedBankAccountType = value),
                 ),
                 const SizedBox(height: 12),
                 Builder(
                   builder: (context) {
                     final selectedAccount = selectedBankAccountId != null
                         ? bankAccounts.firstWhereOrNull((ba) => ba.id == selectedBankAccountId)
                         : null;
                     final typeLabel = selectedBankAccountType == 'moroccan'
                         ? 'الحساب المغربي (MAD)'
                         : selectedBankAccountType == 'european'
                             ? 'الحساب الأوروبي (EUR)'
                             : null;
                     final displayText = selectedAccount != null
                         ? 'الحساب البنكي المحدد: ${selectedAccount.displayName}'
                         : typeLabel != null
                             ? 'نوع الحساب: $typeLabel'
                             : null;
                     if (displayText == null) return const SizedBox.shrink();
                     return Container(
                       padding: const EdgeInsets.all(10),
                       decoration: BoxDecoration(
                         color: Colors.green.withValues(alpha: 0.1),
                         borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: Colors.green),
                       ),
                       child: Row(
                         children: [
                           const Icon(Icons.payment, color: Colors.green, size: 18),
                           const SizedBox(width: 8),
                           Expanded(
                             child: Text(
                               displayText,
                               style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                             ),
                           ),
                         ],
                       ),
                     );
                   },
                 ),
                 const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'HT', label: Text('HT')),
                    ButtonSegment(value: 'TTC', label: Text('TTC')),
                  ],
                  selected: {inputMode.value},
                  onSelectionChanged: (selected) {
                    inputMode.value = selected.first;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'المبلغ'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                     final picked = await showDateWheelPicker(
                       context: context,
                       initialDate: issueDate ?? DateTime.now(),
                       firstDate: DateTime(2020),
                       lastDate: DateTime(2030),
                     );
                     if (picked != null) {
                       setDialogState(() => issueDate = picked);
                     }
                   },
                   child: InputDecorator(
                     decoration: const InputDecoration(labelText: 'تاريخ الإصدار'),
                    child: Text(issueDate == null ? 'اختر التاريخ' : DateFormat('dd/MM/yyyy').format(issueDate!), textDirection: TextDirection.ltr),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDateWheelPicker(
                      context: context,
                      initialDate: dueDate ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                     if (picked != null) {
                       setDialogState(() => dueDate = picked);
                     }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'تاريخ الاستحقاق'),
                    child: Text(dueDate == null ? 'اختر التاريخ' : DateFormat('dd/MM/yyyy').format(dueDate!), textDirection: TextDirection.ltr),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0 || selectedBankAccountType == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى ملء جميع الحقول بشكل صحيح')),
                  );
                  return;
                }
                try {
                  await _supabaseService.createInvoice(
                    clientId: widget.client['id'] as int,
                    amount: Decimal.parse(amount.toString()),
                    inputMode: inputMode.value,
                    bankAccountId: selectedBankAccountId,
                    bankAccountType: selectedBankAccountType,
                    bankInfoText: null,
                    issueDate: issueDate,
                    dueDate: dueDate,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إنشاء الفاتورة بنجاح')),
                  );
                  await _loadData();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e')),
                  );
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRecordPaymentDialog(Invoice invoice) async {
    final amountController = TextEditingController();
    final methodController = TextEditingController();
    final refController = TextEditingController();

    final remaining = invoice.totalAmount.toDouble() - (invoice.paidAmount?.toDouble() ?? 0.0);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('تسجيل دفعة - ${invoice.invoiceNumber}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Text('المتبقي: ${remaining.toStringAsFixed(2)} DH'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  decoration: InputDecoration(labelText: 'المبلغ المدفوع'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                  initialValue: methodController.text.trim().isEmpty ? null : methodController.text.trim(),
                  items: _cashBoxes.isEmpty
                      ? null
                      : _cashBoxes.map((b) {
                          return DropdownMenuItem(
                            value: b['code']?.toString(),
                            child: Text(b['label']?.toString() ?? ''),
                          );
                        }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      methodController.text = v;
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: refController,
                  decoration: const InputDecoration(labelText: 'المرجع (اختياري)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال مبلغ صحيح')),
                  );
                  return;
                }
                try {
                  final newPaidAmount = (invoice.paidAmount ?? Decimal.zero).toDouble() + amount;
                  await _supabaseService.updateInvoiceStatus((invoice.id ?? 0), newPaidAmount);
                  await _supabaseService.addInvoicePayment({
                    'invoice_id': (invoice.id ?? 0),
                    'amount_paid': amount,
                    'payment_method': methodController.text.trim(),
                    'receipt_reference': refController.text.trim(),
                  });
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل الدفعة بنجاح')),
                  );
                  await _loadData();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e')),
                  );
                }
              },
              child: const Text('تسجيل'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final clientName = widget.client['name']?.toString() ?? 'بدون اسم';
    final totalDue = _totalDue;
    final pendingCount = _pendingCount;
    final filteredInvoices = _filteredInvoices;

    return Scaffold(
      appBar: AppBar(
        title: Text(clientName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Card
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إجمالي المستحقات',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${totalDue.toDouble().toStringAsFixed(2)} DH',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: totalDue > Decimal.zero ? colorScheme.error : colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: pendingCount > 0 ? colorScheme.secondary.withValues(alpha: 0.1) : colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: pendingCount > 0 ? colorScheme.secondary.withValues(alpha: 0.3) : colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$pendingCount',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: pendingCount > 0 ? colorScheme.secondary : colorScheme.primary,
                              ),
                            ),
                            Text(
                              'معلقة',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Filter Tabs
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildFilterTab('الكل', 'all'),
                      _buildFilterTab('غير المدفوعة', 'unpaid'),
                      _buildFilterTab('مدفوعة جزئياً', 'partially_paid'),
                      _buildFilterTab('مدفوعة', 'paid'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Add Invoice Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openAddInvoiceDialog,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('إضافة فاتورة جديدة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Invoices List
                Expanded(
                  child: filteredInvoices.isEmpty
                      ? Center(
                          child: Text(
                            _currentFilter == 'all' ? 'لا توجد فواتير' : 'لا توجد فواتير في هذه الفئة',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filteredInvoices.length,
                          itemBuilder: (context, index) {
                            final invoice = filteredInvoices[index];
                            final totalAmount = invoice.totalAmount.toDouble();
                            final paidAmount = (invoice.paidAmount ?? Decimal.zero).toDouble();
                            final remaining = totalAmount - paidAmount;
                            final status = invoice.status;
                            final statusColor = _statusColor(status);

                             return Card(
                               margin: const EdgeInsets.symmetric(vertical: 6),
                               color: Theme.of(context).colorScheme.surfaceContainer,
                               shape: RoundedRectangleBorder(
                                 borderRadius: BorderRadius.circular(12),
                                 side: BorderSide(
                                   color: statusColor.withValues(alpha: 0.4),
                                   width: 1.5,
                                 ),
                               ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                leading: CircleAvatar(
                                  backgroundColor: statusColor.withValues(alpha: 0.15),
                                  child: Icon(
                                    status == 'paid' ? Icons.check_circle_rounded : Icons.pending_rounded,
                                    color: statusColor,
                                  ),
                                ),
                                title: Text(
                                  invoice.invoiceNumber,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('الإصدار: ${_formatDate(invoice.issueDate?.toIso8601String())}', textDirection: TextDirection.ltr),
                                    const SizedBox(height: 4),
                                    Text('الحساب: ${_getBankAccountName(invoice.bankAccountId)}'),
                                    const SizedBox(height: 4),
                                    Text(
                                      'المتبقي: ${remaining.toStringAsFixed(2)} DH',
                                      style: TextStyle(
                                        color: remaining > 0 ? Colors.orange : Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Chip(
                                      label: Text(
                                        _statusLabel(status),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      backgroundColor: statusColor.withValues(alpha: 0.15),
                                      side: BorderSide(color: statusColor.withValues(alpha: 0.4)),
                                    ),
                                    if (status != 'paid')
                                      IconButton(
                                        icon: Icon(Icons.payments_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                                        tooltip: 'تسجيل دفعة',
                                        onPressed: () => _openRecordPaymentDialog(invoice),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterTab(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _currentFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
