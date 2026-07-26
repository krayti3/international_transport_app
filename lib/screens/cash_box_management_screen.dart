import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

class CashBoxManagementScreen extends StatefulWidget {
  const CashBoxManagementScreen({super.key});

  @override
  State<CashBoxManagementScreen> createState() => _CashBoxManagementScreenState();
}

class _CashBoxManagementScreenState extends State<CashBoxManagementScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _cashBoxes = [];
  Map<int, double> _balances = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final boxes = await _supabaseService.getCashBoxes();
    final balances = await _supabaseService.getCashBoxBalances();
    if (!mounted) return;
    setState(() {
      _cashBoxes = boxes;
      _balances = balances;
      _isLoading = false;
    });
  }

  Future<void> _openBoxDialog({Map<String, dynamic>? box}) async {
    final isEdit = box != null;
    final nameController = TextEditingController(text: box?['label']?.toString() ?? '');
    final codeController = TextEditingController(text: box?['code']?.toString() ?? '');
    bool isActive = box?['is_active'] ?? true;
    final outerContext = context;

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(isEdit ? 'تعديل الصندوق' : 'إضافة صندوق جديد'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم الصندوق'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'يرجى إدخال الاسم' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'الكود'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'يرجى إدخال الكود' : null,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('نشط'),
                  value: isActive,
                  onChanged: (v) => setDialog(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final data = {
                  'label': nameController.text.trim(),
                  'code': codeController.text.trim(),
                  'is_active': isActive,
                };
                try {
                  if (isEdit) {
                    await _supabaseService.updateCashBox(box['id'] as int, data);
                  } else {
                    await _supabaseService.addCashBox(data);
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  await _loadData();
                  if (!outerContext.mounted) return;
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    SnackBar(content: Text(isEdit ? 'تم تحديث الصندوق' : 'تم إضافة الصندوق')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(outerContext).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
              },
              child: Text(isEdit ? 'تحديث' : 'إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> box) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الصندوق'),
        content: Text('هل أنت متأكد من حذف "${box['label']}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _supabaseService.deleteCashBox(box['id'] as int);
      await _loadData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الصندوق')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
    }
  }

  Future<void> _showTransferDialog() async {
    if (_cashBoxes.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يتطلب تحويل وجود صندوقين على الأقل')),
      );
      return;
    }

    final amountController = TextEditingController();
    String? fromBoxId;
    String? toBoxId;
    String description = 'تحويل بين الصناديق';
    final formKey = GlobalKey<FormState>();
    final outerContext = context;

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
                    final label = b['label']?.toString() ?? '';
                    final balance = _balances[id] ?? 0.0;
                    return DropdownMenuItem<String>(
                      value: id?.toString(),
                      child: Text('$label (${balance.toStringAsFixed(2)} DH)'),
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
                    final label = b['label']?.toString() ?? '';
                    final balance = _balances[id] ?? 0.0;
                    return DropdownMenuItem<String>(
                      value: id?.toString(),
                      child: Text('$label (${balance.toStringAsFixed(2)} DH)'),
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
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  if (!mounted) return;
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    const SnackBar(content: Text('تم التحويل بنجاح'), backgroundColor: Colors.green),
                  );
                  await _loadData();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(outerContext).showSnackBar(
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
          title: const Text('قائمة الخزائن'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: _cashBoxes.length > 1 ? _showTransferDialog : null,
            tooltip: 'تحويل بين صناديق',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _cashBoxes.length,
                itemBuilder: (context, index) {
                  final box = _cashBoxes[index];
                  final id = box['id'] as int?;
                  final label = box['label']?.toString() ?? '';
                  final code = box['code']?.toString() ?? '';
                  final isActive = box['is_active'] ?? true;
                  final balance = _balances[id] ?? 0.0;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: isActive ? Colors.blue.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                            child: Icon(isActive ? Icons.account_balance_wallet_rounded : Icons.lock_outline,
                                color: isActive ? Colors.blue : Colors.grey),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                                const SizedBox(height: 4),
                                Text(code, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${balance.toStringAsFixed(2)} DH',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                                      color: balance >= 0 ? Colors.green : Colors.red)),
                              Text(isActive ? 'نشط' : 'متوقف',
                                  style: TextStyle(fontSize: 12, color: isActive ? Colors.green : Colors.grey)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _openBoxDialog(box: box);
                              } else if (value == 'delete') {
                                _confirmDelete(box);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                              const PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openBoxDialog(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة صندوق'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
}
