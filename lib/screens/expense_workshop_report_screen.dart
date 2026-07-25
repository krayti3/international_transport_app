import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'workshop_repairs_screen.dart';

// ignore_for_file: use_build_context_synchronously

class ExpenseWorkshopReportScreen extends StatefulWidget {
  const ExpenseWorkshopReportScreen({super.key});

  @override
  State<ExpenseWorkshopReportScreen> createState() => _ExpenseWorkshopReportScreenState();
}

class _ExpenseWorkshopReportScreenState extends State<ExpenseWorkshopReportScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _allExpenses = [];
  List<Map<String, dynamic>> _debts = [];
  bool _isLoading = true;
  String? _filterPaymentStatus;
  String? _filterWorkshop;
  List<String> _workshopNames = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final truckMaintenances = await _supabaseService.getTruckMaintenances();
    final trailerMaintenances = await _supabaseService.getTrailerMaintenances();

    final combined = <Map<String, dynamic>>[];
    for (final row in truckMaintenances) {
      final doc = Map<String, dynamic>.from(row);
      doc['vehicle_type'] = 'شاحنة';
      doc['vehicle_id'] = doc['truck_id'];
      combined.add(doc);
    }
    for (final row in trailerMaintenances) {
      final doc = Map<String, dynamic>.from(row);
      doc['vehicle_type'] = 'مقطورة';
      doc['vehicle_id'] = doc['trailer_id'];
      combined.add(doc);
    }

    final workshops = combined
        .map((e) => e['provider_name']?.toString() ?? 'بدون ورشة')
        .toSet()
        .toList()
      ..sort();

    if (mounted) {
      setState(() {
        _allExpenses = combined;
        _debts = combined.where((e) => e['payment_status']?.toString() == 'on_credit').toList();
        _workshopNames = workshops;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredExpenses {
    var result = _allExpenses;
    if (_filterPaymentStatus != null) {
      result = result.where((e) => e['payment_status']?.toString() == _filterPaymentStatus).toList();
    }
    if (_filterWorkshop != null) {
      result = result.where((e) => (e['provider_name']?.toString() ?? 'بدون ورشة') == _filterWorkshop).toList();
    }
    return result;
  }

  List<Map<String, dynamic>> get _groupedByWorkshop {
    final filtered = _filteredExpenses;
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final expense in filtered) {
      final workshop = expense['provider_name']?.toString() ?? 'بدون ورشة';
      groups.putIfAbsent(workshop, () => []).add(expense);
    }
    final entries = groups.entries.toList();
    entries.sort((a, b) {
      final sumA = a.value.fold<double>(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0.0));
      final sumB = b.value.fold<double>(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0.0));
      return sumB.compareTo(sumA);
    });
    return entries.map((e) => {'workshop': e.key, 'expenses': e.value}).toList();
  }

  double get _totalFilteredAmount {
    return _filteredExpenses.fold<double>(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0.0));
  }

  double get _totalDebtAmount {
    return _debts.fold<double>(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0.0));
  }

  List<Map<String, dynamic>> get _groupedDebtsByWorkshop {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final debt in _debts) {
      final workshop = debt['provider_name']?.toString() ?? 'بدون ورشة';
      groups.putIfAbsent(workshop, () => []).add(debt);
    }
    final entries = groups.entries.toList();
    entries.sort((a, b) {
      final sumA = a.value.fold<double>(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0.0));
      final sumB = b.value.fold<double>(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0.0));
      return sumB.compareTo(sumA);
    });
    return entries.map((e) => {'workshop': e.key, 'debts': e.value}).toList();
  }

  Future<void> _settleWorkshopDebt(String workshop, List<Map<String, dynamic>> debts, String newStatus) async {
    final total = debts.fold<double>(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0.0));
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تصفية ديون الورشة'),
        content: Text('هل تريد تصفية جميع ديون ورشة "$workshop" بقيمة ${total.toStringAsFixed(2)} DH كـ "${_paymentStatusLabel(newStatus)}"؟\n\nعدد المصاريف: ${debts.length}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('تأكيد التصفية'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    int successCount = 0;
    for (final debt in debts) {
      try {
        final vehicleType = debt['vehicle_type']?.toString() ?? '';
        final id = debt['id'] as int?;
        if (id == null) continue;

        if (vehicleType == 'شاحنة') {
          await _supabaseService.updateTruckMaintenance(id, {'payment_status': newStatus});
        } else {
          await _supabaseService.updateTrailerMaintenance(id, {'payment_status': newStatus});
        }
        successCount++;
      } catch (e) {
        debugPrint('Error settling debt for id $id: $e');
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تصفية $successCount من ${debts.length} دين بنجاح')),
    );
    await _loadData();
  }

  Future<void> _settleDebt(Map<String, dynamic> debt, String newStatus) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تصفية الدين'),
        content: Text('هل تريد تصفية دين "${debt['expense_type']?.toString() ?? ''}" بقيمة ${((debt['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)} DH كـ "${_paymentStatusLabel(newStatus)}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('تأكيد التصفية'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final vehicleType = debt['vehicle_type']?.toString() ?? '';
      final id = debt['id'] as int?;
      if (id == null) return;

      if (vehicleType == 'شاحنة') {
        await _supabaseService.updateTruckMaintenance(id, {'payment_status': newStatus});
      } else {
        await _supabaseService.updateTrailerMaintenance(id, {'payment_status': newStatus});
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تصفية الدين بنجاح')),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  String _paymentStatusLabel(String status) {
    switch (status) {
      case 'bank_transfer':
        return 'تحويل بنكي من صاحب الشركة';
      case 'on_credit':
        return 'على الحساب (دَين)';
      case 'secretary_cash':
        return 'الكاش من خزينة السكرتيرة';
      case 'paid_by_owner':
        return 'الكاش من صاحب الشركة';
      default:
        return status;
    }
  }

  Color _paymentStatusColor(String status) {
    switch (status) {
      case 'bank_transfer':
        return Colors.blue;
      case 'on_credit':
        return Colors.red;
      case 'secretary_cash':
        return Colors.orange;
      case 'paid_by_owner':
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير المصاريف حسب الورشة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_rounded),
            onPressed: () {
              final workshopName = _filterWorkshop ?? '';
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WorkshopRepairInvoicesScreen(
                    workshopId: '',
                    workshopName: workshopName,
                  ),
                ),
              );
            },
            tooltip: _filterWorkshop != null ? 'فواتير الورشة' : 'جميع فواتير الورش',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _filterPaymentStatus,
                          decoration: const InputDecoration(
                            labelText: 'حالة الدفع',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('الكل')),
                            DropdownMenuItem(value: 'paid_by_owner', child: Text('الكاش من صاحب الشركة')),
                            DropdownMenuItem(value: 'bank_transfer', child: Text('تحويل بنكي من صاحب الشركة')),
                            DropdownMenuItem(value: 'secretary_cash', child: Text('الكاش من خزينة السكرتيرة')),
                            DropdownMenuItem(value: 'on_credit', child: Text('على الحساب (دَين)')),
                          ],
                          onChanged: (v) => setState(() => _filterPaymentStatus = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _filterWorkshop,
                          decoration: const InputDecoration(
                            labelText: 'الورشة',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('الكل')),
                            ..._workshopNames.map((name) => DropdownMenuItem(value: name, child: Text(name))),
                          ],
                          onChanged: (v) => setState(() => _filterWorkshop = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.blue.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_rounded, color: Colors.blue),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'إجمالي المصاريف المصفاة: ${_totalFilteredAmount.toStringAsFixed(2)} DH',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('إجمالي الديون', style: TextStyle(fontSize: 12, color: Colors.red)),
                              const SizedBox(height: 4),
                              Text(
                                '${_totalDebtAmount.toStringAsFixed(2)} DH',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_debts.isNotEmpty) ...[
                    const Text(
                      'قسم الديون — المصاريف على الحساب حسب الورشة',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    ..._groupedDebtsByWorkshop.map((group) {
                      final workshop = group['workshop'] as String;
                      final debts = group['debts'] as List<Map<String, dynamic>>;
                      final workshopDebtTotal = debts.fold<double>(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0.0));

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: Colors.red.withValues(alpha: 0.05),
                        child: ExpansionTile(
                          leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                          title: Text(workshop, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${debts.length} مصروف على الحساب • الإجمالي: ${workshopDebtTotal.toStringAsFixed(2)} DH'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              _settleWorkshopDebt(workshop, debts, value);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'paid_by_owner', child: Text('دفع كاش من صاحب الشركة')),
                              const PopupMenuItem(value: 'bank_transfer', child: Text('تحويل بنكي من صاحب الشركة')),
                              const PopupMenuItem(value: 'secretary_cash', child: Text('دفع من خزينة السكرتيرة')),
                            ],
                            child: const Icon(Icons.payment_rounded, color: Colors.green),
                          ),
                          children: debts.map((debt) {
                            final amount = (debt['amount'] as num?)?.toDouble() ?? 0.0;
                            final expenseType = debt['expense_type']?.toString() ?? '';
                            final vehicleType = debt['vehicle_type']?.toString() ?? '';
                            final vehicleId = debt['vehicle_id'];
                            final dateStr = debt['maintenance_date']?.toString() ?? debt['created_at']?.toString() ?? '';

                            return ListTile(
                              dense: true,
                              title: Text(expenseType),
                              subtitle: Text('$vehicleType #$vehicleId\n$dateStr'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${amount.toStringAsFixed(2)} DH',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      _settleDebt(debt, value);
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(value: 'paid_by_owner', child: Text('دفع كاش من صاحب الشركة')),
                                      const PopupMenuItem(value: 'bank_transfer', child: Text('تحويل بنكي من صاحب الشركة')),
                                      const PopupMenuItem(value: 'secretary_cash', child: Text('دفع من خزينة السكرتيرة')),
                                    ],
                                    child: const Icon(Icons.payments_rounded, color: Colors.green),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    const Divider(thickness: 2),
                    const SizedBox(height: 12),
                  ],

                  const Text(
                    'المصاريف حسب الورشة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (_groupedByWorkshop.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(child: Text('لا توجد مصاريف مطابقة للفلتر', style: TextStyle(color: Colors.grey))),
                    )
                  else
                    ..._groupedByWorkshop.map((group) {
                      final workshop = group['workshop'] as String;
                      final expenses = group['expenses'] as List<Map<String, dynamic>>;
                      final workshopTotal = expenses.fold<double>(0.0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0.0));

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple.withValues(alpha: 0.15),
                            child: const Icon(Icons.build_rounded, color: Colors.purple),
                          ),
                          title: Text(workshop, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${expenses.length} مصروف • الإجمالي: ${workshopTotal.toStringAsFixed(2)} DH'),
                          children: expenses.map((expense) {
                            final amount = (expense['amount'] as num?)?.toDouble() ?? 0.0;
                            final expenseType = expense['expense_type']?.toString() ?? '';
                            final vehicleType = expense['vehicle_type']?.toString() ?? '';
                            final vehicleId = expense['vehicle_id'];
                            final paymentStatus = expense['payment_status']?.toString() ?? 'paid_by_owner';
                            final dateStr = expense['maintenance_date']?.toString() ?? expense['created_at']?.toString() ?? '';
                            final desc = expense['description']?.toString() ?? '';

                            return ListTile(
                              dense: true,
                              title: Text(expenseType),
                              subtitle: Text('$vehicleType #$vehicleId\n$dateStr${desc.isNotEmpty ? " • $desc" : ""}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${amount.toStringAsFixed(2)} DH',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _paymentStatusColor(paymentStatus).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: _paymentStatusColor(paymentStatus)),
                                    ),
                                    child: Text(
                                      _paymentStatusLabel(paymentStatus),
                                      style: TextStyle(
                                        color: _paymentStatusColor(paymentStatus),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
