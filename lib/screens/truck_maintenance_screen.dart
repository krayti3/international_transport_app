import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../services/fleet_service.dart';
import '../services/workshop_service.dart';
import '../services/treasury_service.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'expense_categories_screen.dart';
import 'providers_screen.dart';
import '../widgets/date_wheel_picker.dart';

// ignore_for_file: use_build_context_synchronously

/// شاشة مصاريف صيانة الشاحنات — تعرض سجل المصاريف التشغيلية لكل شاحنة
/// مع إمكانية تصفية حسب حالة الدفع والتاريخ.
class TruckMaintenanceScreen extends StatefulWidget {
  const TruckMaintenanceScreen({super.key, required this.isAdmin, this.truckId});
  final bool isAdmin;
  final int? truckId;

  @override
  State<TruckMaintenanceScreen> createState() => _TruckMaintenanceScreenState();
}

class _TruckMaintenanceScreenState extends State<TruckMaintenanceScreen> {
  final FleetService _fleetService = FleetService();
  final WorkshopService _workshopService = WorkshopService();
  final TreasuryService _treasuryService = TreasuryService();
  List<Map<String, dynamic>> _trucks = [];
  List<Map<String, dynamic>> _maintenances = [];
  bool _isLoading = true;
  String? _filterPaymentStatus;
  DateTime? _filterFromDate;
  DateTime? _filterToDate;
  List<Map<String, dynamic>> _expenseTypes = [];
  String? _selectedExpenseType;
  List<Map<String, dynamic>> _cashBoxes = [];

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
    final trucks = await _fleetService.getTrucks();
    final maintenances = await _fleetService.getTruckMaintenancesFiltered(
      paymentStatus: _filterPaymentStatus,
      fromDate: _filterFromDate,
      toDate: _filterToDate,
    );
    final expenseTypes = await _workshopService.getExpenseCategories();
    final cashBoxes = await _treasuryService.getCashBoxes();
    if (mounted) {
      setState(() {
        _trucks = widget.truckId != null
            ? trucks.where((t) => (t['id'] as num?)?.toInt() == widget.truckId).toList()
            : trucks;
        _maintenances = (widget.truckId != null
            ? maintenances.where((m) => (m['truck_id'] as num?)?.toInt() == widget.truckId).toList()
            : maintenances)
            .where((m) => m['expense_type']?.toString() != 'oil_change')
            .toList();
        final seen = <String>{};
        _expenseTypes = expenseTypes.where((c) {
          final name = c['name']?.toString() ?? '';
          if (name.isEmpty || seen.contains(name)) return false;
          seen.add(name);
          return true;
        }).toList();
        _cashBoxes = cashBoxes;
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

  Widget _buildExpenseCard(Map<String, dynamic> m, bool isDark) {
    final actual = (m['amount'] as num?)?.toDouble() ?? 0.0;
    final typeLabel = m['expense_type']?.toString() ?? 'أخرى';
    final km = (m['km_at_time'] as num?)?.toDouble();
    final due = m['due_date']?.toString();
    final dateStr = m['created_at']?.toString() ?? '';
    final dateFormatted = dateStr.isNotEmpty
        ? DateFormat('dd/MM/yyyy').format(
            DateTime.tryParse(dateStr) ?? DateTime.now(),
          )
        : '';
    final paymentStatus = m['payment_status']?.toString() ?? 'owner_cash';
    final isOnCredit = paymentStatus == 'on_credit';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isOnCredit
          ? Colors.red.withValues(alpha: 0.08)
          : (isDark ? const Color(0xFF1E1E1E) : null),
      child: ListTile(
        leading: Icon(
          _typeIcon(m['expense_type']?.toString() ?? 'other'),
          color: isOnCredit ? Colors.red : Colors.blue,
        ),
        title: Text(typeLabel),
        subtitle: Text(
          '${actual.toStringAsFixed(2)} DH • $dateFormatted${km != null ? ' • ${km.toStringAsFixed(0)} كم' : ''}${due != null ? ' • $due' : ''}${m['description'] != null && m['description'].toString().isNotEmpty ? '\n${m['description']}' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _paymentStatusBadge(status: paymentStatus),
            const SizedBox(width: 4),
            if (widget.isAdmin)
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    await _openExpenseDialog(maintenance: m);
                  } else if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('حذف المصروف'),
                        content: const Text('هل أنت متأكد؟'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('حذف'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _fleetService.deleteTruckMaintenance(m['id'] as int);
                      await _loadData();
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  PopupMenuItem(value: 'delete', child: Text('حذف')),
                ],
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  // Open bottom sheet showing trucks and their maintenance records
  Future<void> _openTruckDetail(int truckId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _buildTruckDetailContent(truckId, isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
    await _loadData();
  }

  List<Widget> _buildTruckDetailContent(int truckId, bool isDark) {
    final truckMaints =
        _maintenances.where((m) => m['truck_id'] == truckId).toList();

    return [
      if (widget.isAdmin)
        ElevatedButton.icon(
          onPressed: () async {
            await _openExpenseDialog(truckId: truckId);
          },
          icon: const Icon(Icons.add),
          label: const Text('إضافة مصروف'),
        ),
      if (truckMaints.isEmpty)
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('لا توجد مصاريف مسجلة'),
          ),
        ),
      ...truckMaints.map((m) => _buildExpenseCard(m, isDark)),
    ];
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
        return Icons.receipt_long;
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
        maintenance?['payment_status']?.toString() ?? 'owner_cash';

    final cats = await _workshopService.getExpenseCategories();
    final seen = <String>{};
    _expenseTypes = cats.where((c) {
      final name = c['name']?.toString() ?? '';
      if (name.isEmpty || seen.contains(name)) return false;
      seen.add(name);
      return true;
    }).toList();
    final providers = await _workshopService.getProviders();
    List<String> providerNames = providers.map((p) => p['name']?.toString() ?? '').toList();
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
    String? selectedProvider =
        maintenance?['provider_name']?.toString() ?? '';

    // Pre-fill km with truck current km if available
    if (!isEdit && selectedTruckId != null) {
      final truck = trucks.where((t) => t['id'] == selectedTruckId).firstOrNull;
      if (truck != null && kmController.text.isEmpty) {
        final currentKm = (truck['current_km'] as num?)?.toDouble();
        if (currentKm != null && currentKm > 0) {
          kmController.text = currentKm.toString();
        }
      }
    }

  DateTime? maintenanceDate = isEdit
      ? (maintenance['maintenance_date'] != null
          ? DateTime.tryParse(maintenance['maintenance_date'].toString())
          : null)
      : DateTime.now();

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
                                  .where((t) => (t['id'] as num?)?.toInt() != null)
                                  .toList()
                                  .sorted((a, b) {
                                    final aPlate = (a['plate']?.toString() ?? a['plate_number']?.toString() ?? '').toLowerCase();
                                    final bPlate = (b['plate']?.toString() ?? b['plate_number']?.toString() ?? '').toLowerCase();
                                    return aPlate.compareTo(bPlate);
                                  })
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: (t['id'] as num).toInt(),
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
                          labelText: 'مصدر الدفع',
                        ),
                        items: [
                          ..._cashBoxes.map((b) => DropdownMenuItem(
                            value: b['code']?.toString(),
                            child: Text(b['label']?.toString() ?? ''),
                          )),
                          const DropdownMenuItem(
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
                        initialValue: _expenseTypes.any((c) => c['name']?.toString() == _selectedExpenseType)
                            ? _selectedExpenseType
                            : (expenseType.isEmpty ? null : (_expenseTypes.any((c) => c['name']?.toString() == expenseType) ? expenseType : null)),
                        decoration: InputDecoration(
                          labelText: 'نوع المصروف',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.manage_history, size: 20),
                            tooltip: 'إدارة أنواع المصاريف',
                            onPressed: () async {
                              if (!widget.isAdmin) return;
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ExpenseCategoriesScreen()),
                              );
                              final cats = await _workshopService.getExpenseCategories();
                              if (mounted) {
                                setDialogState(() {
                                  final seen = <String>{};
                                  _expenseTypes = cats.where((c) {
                                    final name = c['name']?.toString() ?? '';
                                    if (name.isEmpty || seen.contains(name)) return false;
                                    seen.add(name);
                                    return true;
                                  }).toList();
                                });
                              }
                            },
                          ),
                        ),
                        items: [
                          ..._expenseTypes.map((c) {
                            final name = c['name']?.toString() ?? '';
                            return DropdownMenuItem(
                              value: name,
                              child: Text(name),
                            );
                          }),
                          if (_expenseTypes.map((c) => c['name']?.toString() ?? '').every((n) => n.isEmpty))
                            const DropdownMenuItem(
                              value: '',
                              child: Text('لا توجد أنواع'),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() {
                              _selectedExpenseType = v;
                              expenseType = v;
                            });
                          }
                        },
                        validator: (v) => v == null || v.isEmpty ? 'يرجى اختيار نوع المصروف' : null,
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
                        DropdownButtonFormField<String>(
                          initialValue: (selectedProvider == null || selectedProvider!.isEmpty) ? null : selectedProvider,
                          decoration: InputDecoration(
                            labelText: 'اسم المزود / الورشة',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.manage_history, size: 20),
                               tooltip: 'قائمة الورشات',
                              onPressed: () async {
                                if (!widget.isAdmin) return;
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ProvidersScreen()),
                                );
                                final providers = await _workshopService.getProviders();
                                if (mounted) {
                                  setDialogState(() {
                                    providerNames = providers.map((p) => p['name']?.toString() ?? '').toList();
                                    if ((selectedProvider == null || selectedProvider!.isEmpty) && providerNames.isNotEmpty) {
                                      selectedProvider = providerNames.first;
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          items: [
                            ...providerNames.map((name) {
                              return DropdownMenuItem(
                                value: name,
                                child: Text(name),
                              );
                            }),
                            if (providerNames.isEmpty)
                              const DropdownMenuItem(
                                value: '',
                                child: Text('لا توجد ورشات'),
                              ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() {
                                selectedProvider = v;
                              });
                            }
                          },
                        ),
                       InkWell(
                         onTap: () async {
                            final picked = await showDateWheelPicker(
                              context: context,
                              initialDate: maintenanceDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setDialogState(() => maintenanceDate = picked);
                            }
                         },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'تاريخ إجراء الإصلاح'),
                            child: Text(
                              maintenanceDate == null
                                  ? 'اختر التاريخ'
                                   : DateFormat('dd/MM/yyyy').format(maintenanceDate!),
                              textDirection: TextDirection.ltr,
                            ),
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
                              (selectedProvider == null || selectedProvider!.isEmpty)
                                  ? null
                                  : selectedProvider,
                           'maintenance_date': maintenanceDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
                             'currency': 'MAD',
                         };
                         int? maintenanceId;
                         if (isEdit) {
                           await _fleetService.updateTruckMaintenance(
                             maintenance['id'] as int,
                             data,
                           );
                           maintenanceId = maintenance['id'] as int?;
                         } else {
                           await _fleetService.addTruckMaintenance(data);
                         }
                          // Create treasury transaction based on payment status
                          final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                          if (amount > 0 && paymentStatus != 'on_credit') {
                          await _treasuryService.recordMaintenanceTreasuryTransaction(
                            amount: amount,
                            paymentStatus: paymentStatus,
                            currency: 'MAD',
                            description: descController.text.trim().isEmpty
                                ? expenseType
                                : descController.text.trim(),
                            maintenanceId: maintenanceId,
                          );
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.truckId != null
            ? 'مصاريف صيانة الشاحنة'
            : 'مصاريف صيانة الشاحنات'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter section - always visible at top
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                  labelText: 'مصدر الدفع',
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('الكل'),
                                  ),
                                  ..._cashBoxes.map((b) => DropdownMenuItem(
                                    value: b['code']?.toString(),
                                    child: Text(b['label']?.toString() ?? ''),
                                  )),
                                  const DropdownMenuItem(
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
                // Trucks summary list - scrollable
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: widget.truckId != null && _trucks.isNotEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(12),
                            children: [
                              Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                color: isDark ? const Color(0xFF1E1E1E) : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.local_shipping, color: Colors.blue),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _trucks.first['plate']?.toString() ?? _trucks.first['plate_number']?.toString() ?? '',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      ..._buildTruckDetailContent(_trucks.first['id'] as int, isDark),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _trucks.length,
                            itemBuilder: (context, index) {
                              final truck = _trucks[index];
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
                                   title: Text('$plate — $model', textDirection: TextDirection.ltr, textAlign: TextAlign.left),
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
                            },
                          ),
                  ),
                ),
              ],
            ),
          );
    }

  Widget _paymentStatusBadge({required String status}) {
    Color color;
    String label;
    switch (status) {
      case 'bank_morocco':
      case 'bank_europe':
        color = Colors.blue;
        label = 'تحويل بنكي';
        break;
      case 'on_credit':
        color = Colors.red;
        label = 'على الحساب';
        break;
      case 'secretary_cash':
        color = Colors.orange;
        label = 'خزينة السكرتيرة';
        break;
      case 'owner_cash':
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
