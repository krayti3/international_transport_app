import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cash_box_ledger_screen.dart';
import '../services/treasury_service.dart';

class CashBoxManagementScreen extends StatefulWidget {
  const CashBoxManagementScreen({super.key});

  @override
  State<CashBoxManagementScreen> createState() => _CashBoxManagementScreenState();
}

class _CashBoxManagementScreenState extends State<CashBoxManagementScreen> {
  final TreasuryService _treasuryService = TreasuryService();
  List<Map<String, dynamic>> _cashBoxes = [];
  Map<int, Map<String, double>> _balances = {};
  Map<int, List<String>> _operationsCache = {};
  bool _isLoading = true;

  static const _operations = <String, String>{
    'all': 'الكل',
    'income': 'إيرادات',
    'expense': 'مصاريف',
    'transfer': 'تحويل',
    'advance': 'عهَد',
    'fuel': 'وقود',
    'maintenance': 'صيانة',
    'invoice_payment': 'دفعات فواتير',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final boxes = await _treasuryService.getCashBoxes();
    final balances = await _treasuryService.getCashBoxBalances();
    if (!mounted) return;
    final opsCache = <int, List<String>>{};
    for (final box in boxes) {
      final id = box['id'] as int?;
      if (id != null) {
        opsCache[id] = await _treasuryService.getAllowedOperations(id);
      }
    }
    setState(() {
      _cashBoxes = boxes;
      _balances = balances;
      _operationsCache = opsCache;
      _isLoading = false;
    });
  }

  Future<void> _openOperationsDialog(Map<String, dynamic> box) async {
    final boxId = box['id'] as int?;
    if (boxId == null) return;
    final label = box['label']?.toString() ?? '';
    final allowed = await _treasuryService.getAllowedOperations(boxId);
    final selected = <String>{...allowed};
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('العمليات المسموحة: $label'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _operations.entries.map((entry) {
                final code = entry.key;
                final title = entry.value;
                return CheckboxListTile(
                  title: Text(title),
                  value: selected.contains(code),
                  onChanged: (v) {
                    if (v == true) {
                      selected.add(code);
                    } else {
                      selected.remove(code);
                    }
                    setDialog(() {});
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _treasuryService.setAllowedOperations(boxId, selected.toList());
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم تحديث العمليات المسموحة لـ "$label"')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
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
                     await _treasuryService.updateCashBox(box['id'] as int, data);
                   } else {
                     await _treasuryService.addCashBox(data);
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
      await _treasuryService.deleteCashBox(box['id'] as int);
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
    String transferCurrency = 'MAD';
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
                    final currencyBalances = _balances[id] ?? {'MAD': 0.0, 'EUR': 0.0};
                    return DropdownMenuItem<String>(
                      value: id?.toString(),
                      child: Text('$label (${currencyBalances['MAD']!.toStringAsFixed(2)} DH | ${currencyBalances['EUR']!.toStringAsFixed(2)} €)'),
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
                    final currencyBalances = _balances[id] ?? {'MAD': 0.0, 'EUR': 0.0};
                    return DropdownMenuItem<String>(
                      value: id?.toString(),
                      child: Text('$label (${currencyBalances['MAD']!.toStringAsFixed(2)} DH | ${currencyBalances['EUR']!.toStringAsFixed(2)} €)'),
                    );
                  }).toList(),
                  onChanged: (v) => setDialog(() => toBoxId = v),
                  validator: (v) => v == null ? 'يرجى اختيار الصندوق المستهدف' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: amountController,
                        decoration: const InputDecoration(
                          labelText: 'المبلغ',
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
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'العملة'),
                        initialValue: transferCurrency,
                        items: const [
                          DropdownMenuItem(value: 'MAD', child: Text('درهم DH')),
                          DropdownMenuItem(value: 'EUR', child: Text('يورو €')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setDialog(() => transferCurrency = v);
                          }
                        },
                      ),
                    ),
                  ],
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
                   await _treasuryService.addTransfer(
                     amount: amount,
                     fromCashBoxId: int.parse(fromBoxId!),
                     toCashBoxId: int.parse(toBoxId!),
                     description: description,
                     currency: transferCurrency,
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
                  final balance = _balances[id] ?? {'MAD': 0.0, 'EUR': 0.0};

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
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: _operationsCache[id]?.map((op) {
                                        final title = _operations[op] ?? op;
                                        final isAll = op == 'all';
                                        return Chip(
                                          label: Text(title, style: const TextStyle(fontSize: 11)),
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: isAll
                                              ? Theme.of(context).colorScheme.primaryContainer
                                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        );
                                      }).toList() ??
                                      [],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${(balance['MAD'] ?? 0.0).toStringAsFixed(2)} DH',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                                    color: (balance['MAD'] ?? 0.0) >= 0 ? Colors.green : Colors.red)),
                              const SizedBox(height: 2),
                              Text(
                                '${(balance['EUR'] ?? 0.0).toStringAsFixed(2)} €',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                    color: (balance['EUR'] ?? 0.0) >= 0 ? Colors.green : Colors.red)),
                              Text(isActive ? 'نشط' : 'متوقف',
                                  style: TextStyle(fontSize: 12, color: isActive ? Colors.green : Colors.grey)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _openBoxDialog(box: box);
                              } else if (value == 'operations') {
                                _openOperationsDialog(box);
                              } else if (value == 'delete') {
                                _confirmDelete(box);
                              } else if (value == 'ledger') {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CashBoxLedgerScreen(isAdmin: true),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                              const PopupMenuItem(value: 'operations', child: Text('العمليات المسموحة')),
                              const PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: Colors.red))),
                              const PopupMenuItem(value: 'ledger', child: Text('كشف الحركات')),
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
