import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'package:intl/intl.dart';

// ignore_for_file: use_build_context_synchronously

/// شاشة مصاريف صيانة الشاحنات — تعرض سجل المصاريف التشغيلية لكل شاحنة
/// وتنبيهات ذكية (تغيير الزيت، انتهاء التأمين).
class TruckMaintenanceScreen extends StatefulWidget {
  const TruckMaintenanceScreen({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  State<TruckMaintenanceScreen> createState() => _TruckMaintenanceScreenState();
}

class _TruckMaintenanceScreenState extends State<TruckMaintenanceScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _trucks = [];
  List<Map<String, dynamic>> _maintenances = [];
  bool _isLoading = true;
  String? _filterPaymentStatus;
  DateTime? _filterFromDate;
  DateTime? _filterToDate;

  // Smart-alert thresholds (configurable via future settings)
  static const _oilNearKm = 1000; // km
  static const _insuranceWindowDays = 15; // days

  final _expenseTypeOptions = const {
    'oil_change': 'تغيير الزيت',
    'tires': 'إطارات',
    'insurance': 'تأمين',
    'technical_inspection': 'فحص تقني',
    'depreciation': 'إهلاك',
    'other': 'أخرى',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final trucks = await _supabaseService.getTrucks();
    final maintenances = await _supabaseService.getTruckMaintenancesFiltered(
      paymentStatus: _filterPaymentStatus,
      fromDate: _filterFromDate,
      toDate: _filterToDate,
    );
    if (mounted) {
      setState(() {
        _trucks = trucks;
        _maintenances = maintenances;
        _isLoading = false;
      });
    }
  }

  Map<int, List<Map<String, dynamic>>> _byTruck() {
    final map = <int, List<Map<String, dynamic>>>{};
    for (final m in _maintenances) {
      final truckId = (m['truck_id'] as num?)?.toInt() ?? 0;
      map.putIfAbsent(truckId, () => []).add(m);
    }
    return map;
  }

  double _totalForTruck(int truckId) {
    return _byTruck()[truckId]?.fold<double>(
          0,
          (sum, m) => sum + ((m['amount'] as num?)?.toDouble() ?? 0.0),
        ) ??
        0.0;
  }

  Map<int, double> _lastOilKm() {
    final map = <int, double>{};
    for (final m in _maintenances) {
      if (m['expense_type']?.toString() != 'oil_change') continue;
      final truckId = (m['truck_id'] as num?)?.toInt() ?? 0;
      final km = (m['km_at_time'] as num?)?.toDouble();
      if (km == null) continue;
      final existing = map[truckId];
      if (existing == null || km > existing) map[truckId] = km;
    }
    return map;
  }

  List<Widget> _buildAlerts() {
    final items = <Widget>[];
    final now = DateTime.now();
    final lastOil = _lastOilKm();

    for (final truck in _trucks) {
      final truckId = (truck['id'] as num?)?.toInt() ?? 0;
      final plate =
          truck['plate']?.toString() ??
          truck['plate_number']?.toString() ??
          'بدون لوحة';
      final currentKm = (truck['current_km'] as num?)?.toDouble() ?? 0.0;
      final nextOilKm = (truck['oil_change_km'] as num?)?.toDouble();

      // Oil change alert
      if (nextOilKm != null && nextOilKm > 0) {
        final last = lastOil[truckId] ?? 0.0;
        final effectiveKm = last > currentKm ? last : currentKm;
        final diff = nextOilKm - effectiveKm;
        final overdue = effectiveKm >= nextOilKm;
        final near = !overdue && diff <= _oilNearKm;
        if (overdue || near) {
          final color = overdue ? Colors.red : Colors.orange;
          items.add(
            _alertTile(
              Icons.oil_barrel,
              color,
              'تغيير الزيت — $plate',
              'العداد الحالي: ${effectiveKm.toStringAsFixed(0)} كم\nالموعد القادم: ${nextOilKm.toStringAsFixed(0)} كم',
              overdue ? 'تجاوز الموعد' : 'متبقٍ ${diff.toStringAsFixed(0)} كم',
            ),
          );
        }
      }

      // Insurance alert
      final truckMaints =
          _maintenances.where((m) => m['truck_id'] == truckId).toList();
      for (final m in truckMaints) {
        if (m['expense_type']?.toString() != 'insurance') continue;
        final dueStr = m['due_date']?.toString();
        if (dueStr == null) continue;
        final due = DateTime.tryParse(dueStr);
        if (due == null) continue;
        final daysLeft = due.difference(now).inDays;
        if (daysLeft > _insuranceWindowDays) continue;
        final expired = daysLeft <= 0;
        final color = expired ? Colors.red : Colors.orange;
        items.add(
          _alertTile(
            Icons.shield,
            color,
            'انتهاء تأمين $plate',
            'تاريخ الانتهاء: $dueStr\n${expired ? "منتهي" : "متبقٍ $daysLeft يوم"}',
            expired ? 'منتهي' : 'ينتهي خلال $daysLeft يوم',
          ),
        );
      }
    }

    return items;
  }

  Widget _alertTile(
    IconData icon,
    Color color,
    String title,
    String subtitle,
    String badge,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(
            badge,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // Open bottom sheet showing trucks and their maintenance records
  Future<void> _openTruckDetail(int truckId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final truckMaints =
        _maintenances.where((m) => m['truck_id'] == truckId).toList();
    final truck = _trucks.firstWhere(
      (t) => t['id'] == truckId,
      orElse: () => {},
    );
    final plate =
        truck['plate']?.toString() ??
        truck['plate_number']?.toString() ??
        '#$truckId';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setSheetState) => Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? Colors.blueGrey[900]?.withValues(
                                        alpha: 0.3,
                                      ) ??
                                      Colors.blueGrey.shade800
                                  : Colors.blue.shade50,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'مصاريف $plate',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount:
                              truckMaints.length + (widget.isAdmin ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == 0 && widget.isAdmin) {
                              return ElevatedButton.icon(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _openExpenseDialog(truckId: truckId);
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('إضافة مصروف'),
                              );
                            }
                            final m =
                                truckMaints[index - (widget.isAdmin ? 1 : 0)];
                            final actual =
                                (m['amount'] as num?)?.toDouble() ?? 0.0;
                            final typeLabel =
                                _expenseTypeOptions[m['expense_type']
                                    ?.toString()] ??
                                m['expense_type'] ??
                                'أخرى';
                            final km = (m['km_at_time'] as num?)?.toDouble();
                            final due = m['due_date']?.toString();
                            final dateStr = m['created_at']?.toString() ?? '';
                            final dateFormatted =
                                dateStr.isNotEmpty
                                    ? DateFormat('yyyy/MM/dd').format(
                                      DateTime.tryParse(dateStr) ??
                                          DateTime.now(),
                                    )
                                    : '';
                            final paymentStatus =
                                m['payment_status']?.toString() ??
                                'paid_by_owner';
                            final isOnCredit = paymentStatus == 'on_credit';
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color:
                                  isOnCredit
                                      ? Colors.red.withValues(alpha: 0.08)
                                      : (isDark
                                          ? const Color(0xFF1E1E1E)
                                          : null),
                              child: ListTile(
                                leading: Icon(
                                  _typeIcon(
                                    m['expense_type']?.toString() ?? 'other',
                                  ),
                                  color: isOnCredit ? Colors.red : Colors.blue,
                                ),
                                title: Text(typeLabel),
                                subtitle: Text(
                                  '${actual.toStringAsFixed(2)} DH • $dateFormatted${km != null ? ' • ${km.toStringAsFixed(0)} كم' : ''}${due != null ? ' • $due' : ''}${m['description'] != null && m['description'].toString().isNotEmpty ? '\n${m['description']}' : ''}',
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _paymentStatusBadge(status: paymentStatus),
                                    if (widget.isAdmin)
                                      PopupMenuButton<String>(
                                        onSelected: (value) async {
                                          if (value == 'edit') {
                                            Navigator.pop(context);
                                            await _openExpenseDialog(
                                              maintenance: m,
                                            );
                                          } else if (value == 'delete') {
                                            final confirm = await showDialog<
                                              bool
                                            >(
                                              context: context,
                                              builder:
                                                  (ctx) => AlertDialog(
                                                    title: const Text(
                                                      'حذف المصروف',
                                                    ),
                                                    content: const Text(
                                                      'هل أنت متأكد؟',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed:
                                                            () => Navigator.pop(
                                                              ctx,
                                                              false,
                                                            ),
                                                        child: const Text(
                                                          'إلغاء',
                                                        ),
                                                      ),
                                                      ElevatedButton(
                                                        onPressed:
                                                            () => Navigator.pop(
                                                              ctx,
                                                              true,
                                                            ),
                                                        style:
                                                            ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors.red,
                                                            ),
                                                        child: const Text(
                                                          'حذف',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                            );
                                            if (confirm == true) {
                                              await _supabaseService
                                                  .deleteTruckMaintenance(
                                                    m['id'] as int,
                                                  );
                                              await _loadData();
                                            }
                                          }
                                        },
                                        itemBuilder:
                                            (_) => const [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Text('تعديل'),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Text('حذف'),
                                              ),
                                            ],
                                      )
                                    else
                                      const SizedBox.shrink(),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
    await _loadData();
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'oil_change':
        return Icons.oil_barrel;
      case 'tires':
        return Icons.circle;
      case 'insurance':
        return Icons.shield;
      case 'technical_inspection':
        return Icons.check_circle;
      case 'depreciation':
        return Icons.trending_down;
      default:
        return Icons.build;
    }
  }

  Future<void> _openExpenseDialog({
    Map<String, dynamic>? maintenance,
    int? truckId,
  }) async {
    final isEdit = maintenance != null;
    final trucks = _trucks;
    var selectedTruckId =
        (maintenance?['truck_id'] as num?)?.toInt() ??
        truckId ??
        (trucks.isNotEmpty ? (trucks.first['id'] as num?)?.toInt() : null);
    String expenseType =
        maintenance?['expense_type']?.toString() ?? 'oil_change';
    String paymentStatus =
        maintenance?['payment_status']?.toString() ?? 'paid_by_owner';
    TextEditingController amountController = TextEditingController(
      text: maintenance?['amount']?.toString() ?? '',
    );
    TextEditingController kmController = TextEditingController(
      text: (maintenance?['km_at_time'] as num?)?.toDouble().toString() ?? '',
    );
    TextEditingController dueController = TextEditingController(
      text: maintenance?['due_date']?.toString() ?? '',
    );
    TextEditingController descController = TextEditingController(
      text: maintenance?['description']?.toString() ?? '',
    );
    TextEditingController providerController = TextEditingController(
      text: maintenance?['provider_name']?.toString() ?? '',
    );

    // Pre-fill km with truck current km if available
    if (!isEdit && selectedTruckId != null) {
      final truck = trucks.firstWhereOrNull((t) => t['id'] == selectedTruckId);
      if (truck != null && kmController.text.isEmpty) {
        final currentKm = (truck['current_km'] as num?)?.toDouble();
        if (currentKm != null && currentKm > 0) {
          kmController.text = currentKm.toString();
        }
      }
    }

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return AlertDialog(
                backgroundColor: isDark ? const Color(0xFF1E1E1E) : null,
                title: Text(isEdit ? 'تعديل مصروف' : 'إضافة مصروف صيانة'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isEdit)
                        DropdownButtonFormField<int>(
                          initialValue: selectedTruckId,
                          decoration: const InputDecoration(
                            labelText: 'الشاحنة',
                          ),
                          items:
                              trucks
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: (t['id'] as num?)?.toInt(),
                                      child: Text(
                                        '${t['plate']?.toString() ?? t['plate_number']?.toString() ?? ''} — ${t['model']?.toString() ?? ''}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (v) => setDialogState(() {
                                selectedTruckId = v;
                              }),
                        ),
                      DropdownButtonFormField<String>(
                        initialValue: paymentStatus,
                        decoration: const InputDecoration(
                          labelText: 'حالة الدفع',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'paid_by_owner',
                            child: Text('صاحب الشركة (كاش)'),
                          ),
                          DropdownMenuItem(
                            value: 'bank_transfer',
                            child: Text('تحويل بنكي'),
                          ),
                          DropdownMenuItem(
                            value: 'on_credit',
                            child: Text('على الحساب (دَين)'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => paymentStatus = v);
                          }
                        },
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: expenseType,
                        decoration: const InputDecoration(
                          labelText: 'نوع المصروف',
                        ),
                        items:
                            _expenseTypeOptions.entries
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => expenseType = v);
                        },
                      ),
                      if (expenseType == 'insurance')
                        TextFormField(
                          controller: dueController,
                          decoration: const InputDecoration(
                            labelText: 'تاريخ انتهاء التأمين (YYYY-MM-DD)',
                          ),
                        ),
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'المبلغ (DH)',
                        ),
                      ),
                      TextFormField(
                        controller: kmController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'عداد الكيلومترات',
                        ),
                      ),
                      TextFormField(
                        controller: providerController,
                        decoration: const InputDecoration(
                          labelText: 'اسم المزود / الورشة',
                        ),
                      ),
                      TextFormField(
                        controller: descController,
                        decoration: const InputDecoration(labelText: 'ملاحظات'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final truckIdVal =
                          isEdit ? selectedTruckId : (selectedTruckId);
                      if (truckIdVal == null ||
                          amountController.text.trim().isEmpty) {
                        return;
                      }
                      try {
                        final data = {
                          'truck_id': truckIdVal,
                          'expense_type': expenseType,
                          'description':
                              descController.text.trim().isEmpty
                                  ? null
                                  : descController.text.trim(),
                          'amount':
                              double.tryParse(amountController.text.trim()) ??
                              0.0,
                          'km_at_time':
                              kmController.text.trim().isEmpty
                                  ? null
                                  : double.tryParse(kmController.text.trim()),
                          'due_date':
                              dueController.text.trim().isEmpty
                                  ? null
                                  : dueController.text.trim(),
                          'payment_status': paymentStatus,
                          'provider_name':
                              providerController.text.trim().isEmpty
                                  ? null
                                  : providerController.text.trim(),
                          'maintenance_date': DateTime.now().toIso8601String(),
                        };
                        if (isEdit) {
                          await _supabaseService.updateTruckMaintenance(
                            maintenance['id'] as int,
                            data,
                          );
                        } else {
                          await _supabaseService.addTruckMaintenance(data);
                        }
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        await _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEdit
                                    ? 'تم تحديث المصروف'
                                    : 'تم إضافة المصروف',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                      }
                    },
                    child: Text(isEdit ? 'تحديث' : 'حفظ'),
                  ),
                ],
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alerts = _buildAlerts();

    return Scaffold(
      appBar: AppBar(title: const Text('مصاريف صيانة الشاحنات')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    // Smart Alerts section
                    const Text(
                      '🔔 تنبيهات ذكية',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (alerts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('✅ لا توجد تنبيهات عاجلة حالياً'),
                      )
                    else
                      ...alerts,
                    const SizedBox(height: 20),
                    // Filter section
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: isDark ? const Color(0xFF1E1E1E) : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'فلترة المصاريف',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String?>(
                                    initialValue: _filterPaymentStatus,
                                    decoration: const InputDecoration(
                                      labelText: 'حالة الدفع',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text('الكل'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'paid_by_owner',
                                        child: Text('صاحب الشركة (كاش)'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'bank_transfer',
                                        child: Text('تحويل بنكي'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'on_credit',
                                        child: Text('على الحساب (دَين)'),
                                      ),
                                    ],
                                    onChanged: (v) {
                                      setState(() => _filterPaymentStatus = v);
                                      _loadData();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    decoration: const InputDecoration(
                                      labelText: 'من تاريخ (YYYY-MM-DD)',
                                    ),
                                    onChanged: (v) {
                                      _filterFromDate =
                                          v.isNotEmpty
                                              ? DateTime.tryParse(v)
                                              : null;
                                    },
                                    onFieldSubmitted: (_) => _loadData(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    decoration: const InputDecoration(
                                      labelText: 'إلى تاريخ (YYYY-MM-DD)',
                                    ),
                                    onChanged: (v) {
                                      _filterToDate =
                                          v.isNotEmpty
                                              ? DateTime.tryParse(v)
                                              : null;
                                    },
                                    onFieldSubmitted: (_) => _loadData(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _loadData,
                              icon: const Icon(Icons.filter_alt),
                              label: const Text('تطبيق الفلتر'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Trucks summary
                    const Text(
                      '🚛 سجل مصاريف الشاحنات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_trucks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: Text('لا توجد شاحنات')),
                      )
                    else
                      ..._trucks.map((truck) {
                        final truckId = (truck['id'] as num?)?.toInt() ?? 0;
                        final plate =
                            truck['plate']?.toString() ??
                            truck['plate_number']?.toString() ??
                            '#$truckId';
                        final model = truck['model']?.toString() ?? '';
                        final total = _totalForTruck(truckId);
                        final count = _byTruck()[truckId]?.length ?? 0;
                        final status = truck['status']?.toString() ?? '';
                        final hasOnCredit =
                            _byTruck()[truckId]?.any(
                              (m) =>
                                  m['payment_status']?.toString() ==
                                  'on_credit',
                            ) ??
                            false;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          color:
                              hasOnCredit
                                  ? Colors.red.withValues(alpha: 0.08)
                                  : (isDark ? const Color(0xFF1E1E1E) : null),
                          child: ListTile(
                            leading: const Icon(
                              Icons.local_shipping,
                              color: Colors.blue,
                            ),
                            title: Text('$plate — $model'),
                            subtitle: Text(
                              'الإجمالي: ${total.toStringAsFixed(2)} DH • السجلات: $count${status == 'maintenance' ? ' • (قيد الصيانة)' : ''}${hasOnCredit ? ' • ⚠️ على الحساب' : ''}',
                            ),
                            trailing:
                                widget.isAdmin
                                    ? ElevatedButton(
                                      onPressed:
                                          () => _openTruckDetail(truckId),
                                      child: const Text('التفاصيل'),
                                    )
                                    : null,
                          ),
                        );
                      }),
                  ],
                ),
              ),
      floatingActionButton:
          widget.isAdmin
              ? FloatingActionButton.extended(
                onPressed: () => _openExpenseDialog(),
                icon: const Icon(Icons.add),
                label: const Text('إضافة مصروف'),
              )
              : null,
    );
  }

  Widget _paymentStatusBadge({required String status}) {
    Color color;
    String label;
    switch (status) {
      case 'bank_transfer':
        color = Colors.blue;
        label = 'تحويل بنكي';
        break;
      case 'on_credit':
        color = Colors.red;
        label = 'على الحساب';
        break;
      case 'paid_by_owner':
      default:
        color = Colors.green;
        label = 'كاش';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Utility extension to handle firstWhereOrNull safely
extension IterableFirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
