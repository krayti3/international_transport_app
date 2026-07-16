import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:decimal/decimal.dart';
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
  List<Map<String, dynamic>> _allInvoices = [];
  bool _isLoading = true;
  String _currentFilter = 'all'; // all, unpaid, partially_paid, paid

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
          .where((inv) => inv['client_id'] == clientId)
          .toList();

      if (!mounted) return;
      setState(() {
        _allInvoices = clientInvoices;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading customer data: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredInvoices {
    if (_currentFilter == 'all') return _allInvoices;
    return _allInvoices.where((inv) => inv['status'] == _currentFilter).toList();
  }

  Decimal get _totalDue {
    Decimal total = Decimal.zero;
    for (final inv in _allInvoices) {
      final totalAmount = Decimal.parse((inv['total_amount'] as num?)?.toString() ?? '0');
      final paidAmount = Decimal.parse((inv['paid_amount'] as num?)?.toString() ?? '0');
      total += totalAmount - paidAmount;
    }
    return total;
  }

  int get _pendingCount {
    return _allInvoices.where((inv) => inv['status'] != 'paid').length;
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
      return DateFormat('yyyy/MM/dd').format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _openAddInvoiceDialog() async {
    final amountController = TextEditingController();
    final inputMode = ValueNotifier<String>('HT');
    final bankAccounts = await _supabaseService.getBankAccounts();
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
                      .map((ba) => DropdownMenuItem(
                            value: ba['id']?.toString(),
                            child: Text(ba['name']?.toString() ?? '—'),
                          ))
                      .toList(),
                  onChanged: (value) => setDialogState(() => selectedBankAccountId = value),
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
                    final picked = await showDatePicker(
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
                    child: Text(issueDate == null ? 'اختر التاريخ' : DateFormat('yyyy/MM/dd').format(issueDate!)),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
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
                    child: Text(dueDate == null ? 'اختر التاريخ' : DateFormat('yyyy/MM/dd').format(dueDate!)),
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
                if (amount == null || amount <= 0 || selectedBankAccountId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى ملء جميع الحقول بشكل صحيح')),
                  );
                  return;
                }
                try {
                  await _supabaseService.createInvoice(
                    clientId: widget.client['id'] as int,
                    amount: amount,
                    inputMode: inputMode.value,
                    bankAccountId: selectedBankAccountId,
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

  Future<void> _openRecordPaymentDialog(Map<String, dynamic> invoice) async {
    final amountController = TextEditingController();
    final methodController = TextEditingController();
    final refController = TextEditingController();

    final remaining = ((invoice['total_amount'] as num?)?.toDouble() ?? 0.0) -
        ((invoice['paid_amount'] as num?)?.toDouble() ?? 0.0);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('تسجيل دفعة - ${invoice['invoice_number']?.toString() ?? ''}'),
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
                TextFormField(
                  controller: methodController,
                  decoration: const InputDecoration(labelText: 'طريقة الدفع'),
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
                  final newPaidAmount = ((invoice['paid_amount'] as num?)?.toDouble() ?? 0.0) + amount;
                  await _supabaseService.updateInvoiceStatus(invoice['id'] as int, newPaidAmount);
                  await _supabaseService.addInvoicePayment({
                    'invoice_id': invoice['id'] as int,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
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
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${totalDue.toStringAsFixed(2)} DH',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: totalDue > Decimal.zero ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: pendingCount > 0 ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: pendingCount > 0 ? Colors.orange.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$pendingCount',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: pendingCount > 0 ? Colors.orange : Colors.green,
                              ),
                            ),
                            Text(
                              'معلقة',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
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
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildFilterTab('الكل', 'all', isDark),
                      _buildFilterTab('غير المدفوعة', 'unpaid', isDark),
                      _buildFilterTab('مدفوعة جزئياً', 'partially_paid', isDark),
                      _buildFilterTab('مدفوعة', 'paid', isDark),
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
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
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
                            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filteredInvoices.length,
                          itemBuilder: (context, index) {
                            final invoice = filteredInvoices[index];
                            final totalAmount = (invoice['total_amount'] as num?)?.toDouble() ?? 0.0;
                            final paidAmount = (invoice['paid_amount'] as num?)?.toDouble() ?? 0.0;
                            final remaining = totalAmount - paidAmount;
                            final status = invoice['status']?.toString() ?? 'unpaid';
                            final statusColor = _statusColor(status);

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                                  invoice['invoice_number']?.toString() ?? '#—',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('الإصدار: ${_formatDate(invoice['issue_date']?.toString())}'),
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
                                        icon: Icon(Icons.payments_rounded, color: Colors.teal[600], size: 20),
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

  Widget _buildFilterTab(String label, String value, bool isDark) {
    final isSelected = _currentFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.teal[700] : Colors.teal)
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
                  ? Colors.white
                  : (isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
          ),
        ),
      ),
    );
  }
}
