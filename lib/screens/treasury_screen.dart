import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

// ignore_for_file: use_build_context_synchronously

/// شاشة الخزينة والصندوق المباشر.
///
/// تعرض في الوقت الحقيقي (Realtime) الرصيد الحالي للصندوق وصافي الإيرادات
/// والمصاريف، انطلاقاً من جدول [treasury_transactions] الحقيقي. الرصيد لا
/// يُخزَّن بل يُحسب ديناميكياً: الإيرادات (capital_injection, trip_revenue)
/// تُضاف والمصاريف (باقي الأنواع) تُطرح. جميع عمليات الكتابة تمر عبر
/// [SupabaseService.addTreasuryTransaction] للحفاظ على التخزين المؤقت
/// والمزامنة دون اتصال وتوافق المخطط.
class TreasuryScreen extends StatefulWidget {
  const TreasuryScreen({super.key, required this.isAdmin});

  final bool isAdmin;

  @override
  State<TreasuryScreen> createState() => _TreasuryScreenState();
}

class _TreasuryScreenState extends State<TreasuryScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  // متحكمات الحقول لإدخال حركة مالية يدوية (مصاريف مكتبية، إيراد خارجي...)
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  // الاتجاه المختار في نافذة الإدخال: 'Income' (إيراد) أو 'Expense' (مصروف)
  String _selectedDirection = 'Expense';
  // النوع البرمجي الحقيقي الموافق لمخطط treasury_transactions
  String _selectedType = 'office_expense';

  bool _isLoading = false;
  List<Map<String, dynamic>> _cashBoxes = [];
  Map<int, double> _boxBalances = {};
  bool _isBoxesLoading = false;
  String? _selectedCashBox;

  // خرائط التصنيف: تربط الواجهة العربية بأنواع المخطط الحقيقي (6 قيم فقط)
  static const Map<String, String> _incomeTypes = {
    'trip_revenue': 'تحصيل فواتير الزبائن',
    'capital_injection': 'تزويد رأس مال',
  };
  static const Map<String, String> _expenseTypes = {
    'office_expense': 'مصاريف عمومية وإدارية',
    'salary': 'رواتب وأجور السائقين',
    'trip_expense': 'وقود/مازوت وصيانة الرحلات',
    'owner_withdrawal': 'سحب صاحب المشروع',
  };
  // تسميات العرض لكل نوع حقيقي (تُستخدم في قائمة الحركات)
  static const Map<String, String> _typeLabels = {
    'capital_injection': 'تزويد رأس مال',
    'trip_revenue': 'تحصيل فواتير الزبائن',
    'owner_withdrawal': 'سحب صاحب المشروع',
    'office_expense': 'مصاريف عمومية وإدارية',
    'salary': 'رواتب وأجور السائقين',
    'trip_expense': 'وقود/مازوت وصيانة الرحلات',
  };

  bool _isIncomeType(String type) =>
      type == 'capital_injection' || type == 'trip_revenue';

  Future<void> _loadCashBoxes() async {
    if (!mounted) return;
    setState(() => _isBoxesLoading = true);
    final boxes = await _supabaseService.getCashBoxes();
    final balances = await _supabaseService.getCashBoxBalances();
    if (!mounted) return;
    setState(() {
      _cashBoxes = boxes;
      _boxBalances = balances;
      _isBoxesLoading = false;
    });
  }

  Widget _buildCashBoxSelector() {
    if (_cashBoxes.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'الصندوق الفرعي',
      ),
      initialValue: _selectedCashBox,
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('كل الصناديق'),
        ),
        ..._cashBoxes.map((b) {
          final id = b['id'] as int?;
          final label = b['label']?.toString() ?? b['code']?.toString() ?? '';
          final balance = _boxBalances[id] ?? 0.0;
          return DropdownMenuItem<String>(
            value: id?.toString(),
            child: Text('$label : ${NumberFormat('#,###.00').format(balance)} DH'),
          );
        }),
      ],
      onChanged: (val) {
        setState(() {
          _selectedCashBox = val;
        });
        _loadCashBoxes();
      },
    );
  }

  // جلب دفق البيانات الحي (Realtime Stream) لعمليات الخزينة
  Stream<List<Map<String, dynamic>>> _getTreasuryStream() {
    return Supabase.instance.client
        .from('treasury_transactions')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  // دالة إضافة حركة مالية يدوية إلى الخزينة (عبر الطبقة الحالية SupabaseService)
  Future<void> _addTransaction(GlobalKey<FormState> formKey) async {
    if (!formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText) ?? 0.0;

    setState(() => _isLoading = true);
    try {
      final int? cashBoxId = _selectedCashBox != null ? int.tryParse(_selectedCashBox!) : null;
      await _supabaseService.addTreasuryTransaction(amount, _selectedType, title, cashBoxId: cashBoxId);

      _titleController.clear();
      _amountController.clear();
      _selectedDirection = 'Expense';
      _selectedType = 'office_expense';

      if (mounted) Navigator.pop(context); // إغلاق النافذة

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل العملية المالية بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء الحفظ المالي: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // نافذة منبثقة لتسجيل حركة مالية (إيراد / مصروف) يدوياً
  void _showAddTransactionDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final categoryMap =
              _selectedDirection == 'Income' ? _incomeTypes : _expenseTypes;
          final formKey = GlobalKey<FormState>();

          return AlertDialog(
            title: const Text('تسجيل حركة مالية في الصندوق',
                textAlign: TextAlign.right),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_cashBoxes.isNotEmpty)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'الصندوق'),
                        initialValue: _selectedCashBox,
                        items: _cashBoxes.map((b) {
                          final id = b['id'] as int?;
                          return DropdownMenuItem<String>(
                            value: id?.toString(),
                            child: Text(b['label']?.toString() ?? ''),
                          );
                        }).toList(),
                        onChanged: (val) => setDialogState(() => _selectedCashBox = val),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDirection,
                      decoration:
                          const InputDecoration(labelText: 'نوع العملية المالية'),
                      items: const [
                        DropdownMenuItem(
                            value: 'Expense',
                            child: Text('🔴 مصروف / تدفق خارج')),
                        DropdownMenuItem(
                            value: 'Income',
                            child: Text('🟢 إيراد / تدفق داخل')),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        setDialogState(() {
                          _selectedDirection = val;
                          _selectedType = (val == 'Income'
                                  ? _incomeTypes
                                  : _expenseTypes)
                              .keys
                              .first;
                        });
                      },
                      validator: (v) => v == null ? 'يرجى اختيار نوع العملية' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      decoration:
                          const InputDecoration(labelText: 'تصنيف الحساب'),
                      items: categoryMap.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => _selectedType = val);
                      },
                      validator: (v) => v == null || v.isEmpty ? 'يرجى اختيار التصنيف' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                          labelText: 'البيان / وصف العملية (مثال: شراء قطع غيار)'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'يرجى إدخال البيان';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'المبلغ المالي',
                        suffixText: 'DH',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
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
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : () => _addTransaction(formKey),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedDirection == 'Income'
                      ? Colors.green[700]
                      : Colors.red[700],
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('تثبيت بالصندوق'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showTransferDialog() async {
    if (_cashBoxes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد صناديق متاحة للتحويل')),
      );
      return;
    }

    final amountController = TextEditingController();
    String? fromBoxId;
    String? toBoxId;
    String description = 'تحويل بين الصناديق';

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('تحويل بين الصناديق', textAlign: TextAlign.right),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
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
                  await _loadCashBoxes();
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
  void initState() {
    super.initState();
    _loadCashBoxes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isBoxesLoading) _buildCashBoxSelector(),
            const SizedBox(height: 12),
            // 🔄 دفق الحسابات المباشر لاستخراج الإحصائيات في نفس اللحظة
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getTreasuryStream(),
              builder: (context, snapshot) {
                double totalIncome = 0.0;
                double totalExpense = 0.0;
                final transactions = snapshot.data ?? [];

                // احتساب الإجمالي والملخص المالي من البيانات الحية (حسب المخطط الحقيقي)
                for (final tx in transactions) {
                  final double amt = (tx['amount'] ?? 0.0).toDouble();
                  final String type = (tx['type'] ?? '').toString();
                  if (_isIncomeType(type)) {
                    totalIncome += amt;
                  } else {
                    totalExpense += amt;
                  }
                }
                final double netBalance = totalIncome - totalExpense;

                final bool isWaiting = snapshot.connectionState ==
                        ConnectionState.waiting &&
                    transactions.isEmpty;

                // فحص حجم الشاشة لملاءمة بطاقات العرض
                final bool isDesktop =
                    MediaQuery.of(context).size.width > 700;

                return Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 📊 لوحة المؤشرات المالية الثلاثية (متجاوبة)
                      isDesktop
                          ? Row(
                              children: [
                                _buildFinanceCard(
                                    'رصيد الصندوق الحالي',
                                    '${NumberFormat('#,###.00').format(netBalance)} DH',
                                    Icons.account_balance_rounded,
                                    netBalance >= 0 ? Colors.green : Colors.red),
                                const SizedBox(width: 12),
                                _buildFinanceCard(
                                    'إجمالي الإيرادات (+)',
                                    '${NumberFormat('#,###.00').format(totalIncome)} DH',
                                    Icons.arrow_upward_rounded,
                                    Colors.green),
                                const SizedBox(width: 12),
                                _buildFinanceCard(
                                    'إجمالي المصاريف (-)',
                                    '${NumberFormat('#,###.00').format(totalExpense)} DH',
                                    Icons.arrow_downward_rounded,
                                    Colors.red),
                              ],
                            )
                          : Column(
                              children: [
                                _buildFinanceCard(
                                    'رصيد الصندوق الحالي',
                                    '${NumberFormat('#,###.00').format(netBalance)} DH',
                                    Icons.account_balance_rounded,
                                    netBalance >= 0 ? Colors.green : Colors.red,
                                    fullWidth: true),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _buildFinanceCard(
                                        'الإيرادات',
                                        '${NumberFormat('#,###.00').format(totalIncome)} DH',
                                        Icons.arrow_upward_rounded,
                                        Colors.green),
                                    const SizedBox(width: 10),
                                    _buildFinanceCard(
                                        'المصاريف',
                                        '${NumberFormat('#,###.00').format(totalExpense)} DH',
                                        Icons.arrow_downward_rounded,
                                        Colors.red),
                                  ],
                                ),
                              ],
                            ),

                      const SizedBox(height: 24),
                      Text(
                        'كشف حركة الحسابات اليومية والدفق النقدي',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                             color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(height: 12),

                      // عرض قائمة الحركات المالية التاريخية
                      Expanded(
                        child: transactions.isEmpty
                            ? Center(
                                child: isWaiting
                                    ? const CircularProgressIndicator()
                                    : const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 40.0),
                                        child: Text(
                                            'الصندوق فارغ حالياً، لا توجد أي تدفقات مالية مسجلة.'),
                                      ),
                              )
                            : Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                      color: Theme.of(context).dividerColor,
                                      width: 0.5),
                                ),
                                color: Theme.of(context).colorScheme.surfaceContainer,
                                child: ListView.separated(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: transactions.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final tx = transactions[index];
                                    final String type =
                                        (tx['type'] ?? '').toString();
                                    final bool isIncome = _isIncomeType(type);
                                    final double amt =
                                        (tx['amount'] ?? 0.0).toDouble();
                                    final String desc =
                                        (tx['description'] ?? '')
                                            .toString()
                                            .trim();

                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: (isIncome
                                                ? Colors.green
                                                : Colors.red)
                                            .withValues(alpha: 0.12),
                                        child: Icon(
                                          isIncome
                                              ? Icons.arrow_upward_rounded
                                              : Icons.arrow_downward_rounded,
                                          color: isIncome
                                              ? Colors.green[700]
                                              : Colors.red[700],
                                          size: 18,
                                        ),
                                      ),
                                      title: Text(
                                          desc.isEmpty
                                              ? 'عملية بدون بيان'
                                              : desc,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      subtitle: Text(
                                        'التصنيف: ${_typeLabels[type] ?? type}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500]),
                                      ),
                                      trailing: Text(
                                        '${isIncome ? '+' : '-'} ${NumberFormat('#,###.00').format(amt)} DH',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isIncome
                                              ? Colors.green[600]
                                              : Colors.red[600],
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
              },
            ),
          ],
        ),
      ),

      // ➕ أزرار تسجيل الحركات والتحويل
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: _showAddTransactionDialog,
            icon: const Icon(Icons.account_balance_wallet_rounded),
            label: const Text('تسجيل حركة صندوق'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            onPressed: _showTransferDialog,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('تحويل بين صناديق'),
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }

  // بناء بطاقات المؤشرات المالية الاحترافية والمتطابقة
  Widget _buildFinanceCard(String title, String value, IconData icon,
      Color color,
      {bool fullWidth = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardWidget = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
          border: Border.fromBorderSide(BorderSide(
              color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );

    return fullWidth
        ? SizedBox(width: double.infinity, child: cardWidget)
        : Expanded(child: cardWidget);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}