import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../services/excel_service.dart';

// ignore_for_file: use_build_context_synchronously

/// شاشة إدارة الخزينة — للسكرتيرة والأدمن.
/// تعرض رصيد الخزينة الحالي (محسوب ديناميكياً) وتتيح تسجيل معاملات جديدة
/// (تزويد، سحب، مصروف مكتب، راتب) في جدول [treasury_transactions]، مع إمكانية
/// إرفاق صورة الإيصال (مثل وصل إيجار المكتب أو دفع الراتب) لتتم مراجعتها من الأدمن.
class TreasuryManagementScreen extends StatefulWidget {
  const TreasuryManagementScreen({super.key});

  @override
  State<TreasuryManagementScreen> createState() => _TreasuryManagementScreenState();
}

class _TreasuryManagementScreenState extends State<TreasuryManagementScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _cashBoxes = [];
  double _balance = 0.0;
  bool _isLoading = true;
  String? _selectedCashBoxId;

  static const Map<String, String> _typeLabels = {
    'capital_injection': 'تزويد رأس مال',
    'trip_revenue': 'تحصيل فواتير الزبائن',
    'owner_withdrawal': 'سحب شخصي',
    'office_expense': 'مصروف مكتب',
    'salary': 'دفع راتب',
    'trip_expense': 'مصروف رحلة / عهدة',
  };

  static const List<String> _dropdownTypes = [
    'capital_injection',
    'trip_revenue',
    'owner_withdrawal',
    'office_expense',
    'salary',
    'trip_expense',
    'transfer',
  ];

  @override
  void initState() {
    super.initState();
    _loadData(cashBoxId: _selectedCashBoxId != null ? int.tryParse(_selectedCashBoxId!) : null);
  }

  Future<void> _loadData({int? cashBoxId}) async {
    setState(() => _isLoading = true);
    final transactions = await _supabaseService.getTreasuryTransactions(cashBoxId: cashBoxId);
    final balance = await _supabaseService.getTreasuryBalance(cashBoxId: cashBoxId);
    final cashBoxes = await _supabaseService.getCashBoxes();
    if (!mounted) return;
    setState(() {
      _transactions = transactions;
      _balance = balance;
      _cashBoxes = cashBoxes;
      _isLoading = false;
    });
  }

  bool _isPositiveType(String type) =>
      type == 'capital_injection' || type == 'trip_revenue';

  IconData _getIcon(String type) {
    switch (type) {
      case 'capital_injection':
        return Icons.add_circle_outline;
      case 'trip_revenue':
        return Icons.arrow_upward;
      case 'owner_withdrawal':
        return Icons.person_remove_alt_1;
      case 'office_expense':
        return Icons.store;
      case 'salary':
        return Icons.payments;
      case 'trip_expense':
        return Icons.arrow_downward;
      default:
        return Icons.swap_horiz;
    }
  }

  Color _getColor(String type) => _isPositiveType(type) ? Colors.green : Colors.red;

  Widget _buildCashBoxSelector() {
    if (_cashBoxes.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'الصندوق',
      ),
      isExpanded: true,
      initialValue: _selectedCashBoxId,
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('الكل'),
        ),
        ..._cashBoxes.map((b) {
          final id = b['id'] as int?;
          final label = b['label']?.toString() ?? b['code']?.toString() ?? '';
          return DropdownMenuItem<String>(
            value: id?.toString(),
            child: Text(label),
          );
        }),
      ],
      onChanged: (val) {
        setState(() {
          _selectedCashBoxId = val;
        });
        final cashBoxId = val != null ? int.tryParse(val) : null;
        _loadData(cashBoxId: cashBoxId);
      },
    );
  }

  String _formatAmount(double amount, String type) {
    final prefix = _isPositiveType(type) ? '+' : '-';
    return '$prefix${NumberFormat('#,###.00').format(amount)} DH';
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.tryParse(raw);
      if (dt == null) return raw;
      return DateFormat('dd/MM/yyyy', 'ar_MA').format(dt);
    } catch (_) {
      return raw;
    }
  }

  void _showReceipt(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(
            url,
            errorBuilder: (_, _, _) => const Center(child: Text('تعذّر تحميل الصورة')),
          ),
        ),
      ),
    );
  }

  Future<void> _exportTreasuryExcel() async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 24),
              Text('جاري إنشاء ملف Excel...'),
            ],
          ),
        ),
      ),
    );
    try {
      final bytes = await ExcelService.instance.exportTreasuryTransactions(_transactions);
      if (!mounted) return;
      Navigator.pop(context);
      await ExcelService.instance.shareExcel(bytes, 'سجلات_الخزينة');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تصدير Excel: $e')),
      );
    }
  }

  Future<void> _openAddDialog() async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedType;
    String? receiptUrl;
    Uint8List? receiptPreview;
    bool isUploading = false;
    bool isSubmitting = false;
    String? receiptError;
    final formKey = GlobalKey<FormState>();

    Future<void> pickAndUpload(
      ImageSource source,
      void Function(VoidCallback) setDialog,
    ) async {
      setDialog(() => isUploading = true);
      try {
        final picked = await _picker.pickImage(source: source, imageQuality: 70);
        if (picked == null) {
          setDialog(() => isUploading = false);
          return;
        }
        final bytes = await picked.readAsBytes();
        final url = await _supabaseService.uploadReceipt(picked.name, bytes);
        setDialog(() {
          receiptPreview = bytes;
          receiptUrl = url;
          isUploading = false;
        });
      } catch (e) {
        setDialog(() {
          isUploading = false;
          receiptError = 'فشل رفع الصورة: $e';
        });
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('إضافة معاملة خزينة'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'نوع المعاملة'),
                    initialValue: null,
                    items: _dropdownTypes
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(_typeLabels[t] ?? t),
                            ))
                        .toList(),
                    onChanged: (v) => setDialog(() => selectedType = v),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'يرجى اختيار نوع المعاملة' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: 'المبلغ (DH)',
                      suffixText: 'DH',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'يرجى إدخال المبلغ';
                      final p = double.tryParse(v.trim());
                      if (p == null) return 'يرجى إدخال أرقام فقط';
                      if (p <= 0) return 'يرجى إدخال مبلغ أكبر من صفر';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'التفاصيل'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const Text('صورة الإيصال (اختياري)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (receiptPreview != null)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(receiptPreview!,
                              height: 120, fit: BoxFit.cover),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => setDialog(() {
                            receiptPreview = null;
                            receiptUrl = null;
                          }),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isUploading
                                ? null
                                : () => pickAndUpload(ImageSource.camera, setDialog),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('التقاط صورة'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isUploading
                                ? null
                                : () => pickAndUpload(ImageSource.gallery, setDialog),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('من المعرض'),
                          ),
                        ),
                      ],
                    ),
                  if (isUploading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    ),
                  if (receiptError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(receiptError!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting || isUploading ? null : () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: (isSubmitting || isUploading)
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialog(() => isSubmitting = true);
                      final amount = double.tryParse(amountController.text.trim()) ?? 0;
                      final description = descriptionController.text.trim();
                      if (amount <= 0 || selectedType == null) {
                        setDialog(() => isSubmitting = false);
                        return;
                      }
                      try {
                        await _supabaseService.addTreasuryTransaction(
                          amount,
                          selectedType!,
                          description,
                          receiptUrl: receiptUrl,
                        );
                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم تسجيل المعاملة بنجاح')),
                        );
                         await _loadData(cashBoxId: _selectedCashBoxId != null ? int.tryParse(_selectedCashBoxId!) : null);
                      } catch (e) {
                        if (!mounted) return;
                        setDialog(() => isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('فشل الحفظ: $e')),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTransferDialog() async {
    final amountController = TextEditingController();
    String? fromBoxId;
    String? toBoxId;
    String description = 'تحويل بين الصناديق';
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('تحويل بين الصناديق'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'من صندوق'),
                  initialValue: fromBoxId,
                  items: _cashBoxes.map((b) {
                    final id = b['id'] as int?;
                    return DropdownMenuItem<String>(
                      value: id?.toString(),
                      child: Text(b['label']?.toString() ?? ''),
                    );
                  }).toList(),
                  onChanged: (v) => setDialog(() => fromBoxId = v),
                  validator: (v) => v == null ? 'يرجى اختيار الصندوق المصدر' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'إلى صندوق'),
                  initialValue: toBoxId,
                  items: _cashBoxes.map((b) {
                    final id = b['id'] as int?;
                    return DropdownMenuItem<String>(
                      value: id?.toString(),
                      child: Text(b['label']?.toString() ?? ''),
                    );
                  }).toList(),
                  onChanged: (v) => setDialog(() => toBoxId = v),
                  validator: (v) => v == null ? 'يرجى اختيار الصندوق المستهدف' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ (DH)',
                    suffixText: 'DH',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'يرجى إدخال المبلغ';
                    final p = double.tryParse(v.trim());
                    if (p == null) return 'أرقام فقط';
                    if (p <= 0) return 'المبلغ يجب أن يكون أكبر من صفر';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'البيان'),
                  onChanged: (v) => description = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final amount = double.tryParse(amountController.text.trim()) ?? 0;
                try {
                  await _supabaseService.addTransfer(
                    amount: amount,
                    fromCashBoxId: int.parse(fromBoxId!),
                    toCashBoxId: int.parse(toBoxId!),
                    description: description,
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم التحويل بنجاح'), backgroundColor: Colors.green),
                  );
                   await _loadData(cashBoxId: _selectedCashBoxId != null ? int.tryParse(_selectedCashBoxId!) : null);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('فشل التحويل: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الخزينة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openAddDialog,
            tooltip: 'معاملة جديدة',
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: _cashBoxes.length > 1 ? _openTransferDialog : null,
            tooltip: 'تحويل بين صناديق',
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'تصدير Excel',
            onPressed: _exportTreasuryExcel,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _buildCashBoxSelector(),
                ),
                Card(
                  margin: const EdgeInsets.all(16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          _selectedCashBoxId == null
                              ? 'رصيد الخزينة الحالي'
                              : 'رصيد ${_cashBoxes.firstWhere((b) => b['id'].toString() == _selectedCashBoxId, orElse: () => {})['label'] ?? 'الخزينة'}',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                         Text(
                           '${NumberFormat('#,###.00').format(_balance)} DH',
                           style: TextStyle(
                             fontSize: 36,
                             fontWeight: FontWeight.bold,
                             color: _balance >= 0 ? Colors.green : Colors.red,
                           ),
                         ),
                        const SizedBox(height: 8),
                        Icon(
                          _balance >= 0 ? Icons.trending_up : Icons.trending_down,
                          color: _balance >= 0 ? Colors.green : Colors.red,
                          size: 32,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _transactions.isEmpty
                      ? const Center(child: Text('لا يوجد معاملات حالياً'))
                      : RefreshIndicator(
                          onRefresh: () async {
                            final cashBoxId = _selectedCashBoxId != null ? int.tryParse(_selectedCashBoxId!) : null;
                            await _loadData(cashBoxId: cashBoxId);
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              final t = _transactions[index];
                              final type = t['type']?.toString() ?? '';
                              final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
                              final description = t['description']?.toString() ?? '';
                              final createdAt = _formatDate(t['created_at']?.toString());
                              final receiptUrl = t['receipt_url']?.toString();
                              final color = _getColor(type);
                              return Card(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: color.withValues(alpha: 0.15),
                                    child: Icon(_getIcon(type), color: color),
                                  ),
                                  title: Text(
                                    _formatAmount(amount, type),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_typeLabels[type] ?? type),
                                      if (description.isNotEmpty) Text(description),
                                      if (createdAt.isNotEmpty)
                                        Text(createdAt,
                                            style: const TextStyle(
                                                fontSize: 12, color: Colors.grey)),
                                      if (receiptUrl != null && receiptUrl.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: GestureDetector(
                                            onTap: () => _showReceipt(receiptUrl),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(
                                                receiptUrl,
                                                height: 80,
                                                width: 80,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    const Text('صورة الإيصال'),
                                              ),
                                            ),
                                          ),
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
}
