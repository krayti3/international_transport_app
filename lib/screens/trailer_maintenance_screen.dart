import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../services/fleet_service.dart';
import '../services/treasury_service.dart';
import '../services/workshop_service.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'providers_screen.dart';

// ignore_for_file: use_build_context_synchronously

class TrailerMaintenanceScreen extends StatefulWidget {
  const TrailerMaintenanceScreen({super.key, required this.isAdmin, this.trailerId});
  final bool isAdmin;
  final int? trailerId;

  @override
  State<TrailerMaintenanceScreen> createState() => _TrailerMaintenanceScreenState();
}

class _TrailerMaintenanceScreenState extends State<TrailerMaintenanceScreen> {
  final FleetService _fleetService = FleetService();
  final TreasuryService _treasuryService = TreasuryService();
  final WorkshopService _workshopService = WorkshopService();
  List<Map<String, dynamic>> _trailers = [];
  List<Map<String, dynamic>> _maintenances = [];
  bool _isLoading = true;
  String? _filterPaymentStatus;
  DateTime? _filterFromDate;
  DateTime? _filterToDate;
  List<String> _expenseTypes = [];
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
    final trailers = await _fleetService.getTrailers();
    final maintenances = widget.trailerId != null
        ? await _fleetService.getTrailerMaintenancesByTrailer(widget.trailerId!)
        : await _fleetService.getTrailerMaintenances();
    final expenseTypes = await _workshopService.getExpenseTypes();
    final cashBoxes = await _treasuryService.getCashBoxes();
    if (mounted) {
      setState(() {
        _trailers = widget.trailerId != null
            ? trailers.where((t) => (t['id'] as num?)?.toInt() == widget.trailerId).toList()
            : trailers;
        _maintenances = (widget.trailerId != null
            ? maintenances.where((m) => (m['trailer_id'] as num?)?.toInt() == widget.trailerId).toList()
            : maintenances)
            .where((m) {
              if (_filterPaymentStatus != null && m['payment_status']?.toString() != _filterPaymentStatus) {
                return false;
              }
              final dateStr = m['maintenance_date']?.toString() ?? m['created_at']?.toString() ?? '';
              if (dateStr.isEmpty) return true;
              final date = DateTime.tryParse(dateStr);
              if (date == null) return true;
              if (_filterFromDate != null && date.isBefore(_filterFromDate!)) {
                return false;
              }
              if (_filterToDate != null && date.isAfter(_filterToDate!)) {
                return false;
              }
              return true;
            })
            .toList();
        _expenseTypes = expenseTypes;
        _cashBoxes = cashBoxes;
        _isLoading = false;
      });
    }
  }

  Map<int, List<Map<String, dynamic>>> _byTrailer() {
    final map = <int, List<Map<String, dynamic>>>{};
    for (final m in _maintenances) {
      final trailerId = (m['trailer_id'] as num?)?.toInt() ?? 0;
      map.putIfAbsent(trailerId, () => []).add(m);
    }
    return map;
  }

  double _totalForTrailer(int trailerId) {
    return _byTrailer()[trailerId]?.fold<double>(
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
    final dateStr = m['maintenance_date']?.toString() ?? m['created_at']?.toString() ?? '';
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
          '${actual.toStringAsFixed(2)} DH • $dateFormatted${km != null ? ' • ${km.toStringAsFixed(0)} كم' : ''}${due != null && due.isNotEmpty ? ' • $due' : ''}${m['description'] != null && m['description'].toString().isNotEmpty ? '\n${m['description']}' : ''}',
          textDirection: TextDirection.ltr,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _paymentStatusBadge(status: paymentStatus),
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
                      await _fleetService.deleteTrailerMaintenance(m['id'] as int);
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

  Future<void> _openTrailerDetail(int trailerId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trailer = _trailers.firstWhere(
      (t) => t['id'] == trailerId,
      orElse: () => {},
    );
    final plate =
        trailer['plate']?.toString() ??
        trailer['plate_number']?.toString() ??
        '#$trailerId';

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
                    borderRadius: const BorderRadius.vertical(
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
                            children: _buildTrailerDetailContent(trailerId, isDark),
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

  List<Widget> _buildTrailerDetailContent(int trailerId, bool isDark) {
    final trailerMaints =
        _maintenances.where((m) => m['trailer_id'] == trailerId).toList();

    return [
      if (widget.isAdmin)
        ElevatedButton.icon(
          onPressed: () async {
            await _openExpenseDialog(trailerId: trailerId);
          },
          icon: const Icon(Icons.add),
          label: const Text('إضافة مصروف'),
        ),
      if (trailerMaints.isEmpty)
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('لا توجد مصاريف مسجلة'),
          ),
        ),
      ...trailerMaints.map((m) => _buildExpenseCard(m, isDark)),
    ];
  }

  IconData _typeIcon(String type) {
    switch (type) {
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
    int? trailerId,
  }) async {
    final isEdit = maintenance != null;
    final trailers = _trailers;
    var selectedTrailerId =
        (maintenance?['trailer_id'] as num?)?.toInt() ??
        trailerId ??
        (trailers.isNotEmpty ? (trailers.first['id'] as num?)?.toInt() : null);
    String expenseType =
        maintenance?['expense_type']?.toString() ?? (_expenseTypes.isNotEmpty ? _expenseTypes.first : '');
    String paymentStatus =
        maintenance?['payment_status']?.toString() ?? 'owner_cash';
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

    final providers = await _workshopService.getProviders();
    if (!mounted) return;
    List<String> providerNames = providers.map((p) => p['name']?.toString() ?? '').toList();

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
                          initialValue: selectedTrailerId,
                          decoration: const InputDecoration(
                            labelText: 'المقطورة',
                          ),
                          items:
                              trailers
                                  .toList()
                                  .sorted((a, b) {
                                    final aPlate = (a['plate']?.toString() ?? a['plate_number']?.toString() ?? '').toLowerCase();
                                    final bPlate = (b['plate']?.toString() ?? b['plate_number']?.toString() ?? '').toLowerCase();
                                    return aPlate.compareTo(bPlate);
                                  })
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
                                selectedTrailerId = v;
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
                        initialValue: _selectedExpenseType ?? (expenseType.isEmpty ? null : expenseType),
                        decoration: InputDecoration(
                          labelText: 'نوع المصروف',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            tooltip: 'إضافة نوع جديد',
                            onPressed: () async {
                              final controller = TextEditingController();
                              final newType = await showDialog<String>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('نوع مصروف جديد'),
                                  content: TextField(
                                    controller: controller,
                                    decoration: const InputDecoration(labelText: 'اسم النوع'),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                                    ElevatedButton(
                                      onPressed: () {
                                        final value = controller.text.trim();
                                        if (value.isNotEmpty) Navigator.pop(context, value);
                                      },
                                      child: const Text('إضافة'),
                                    ),
                                  ],
                                ),
                              );
                              if (newType != null && newType.isNotEmpty) {
                                setDialogState(() {
                                  _expenseTypes.add(newType);
                                  _selectedExpenseType = newType;
                                  expenseType = newType;
                                });
                              }
                            },
                          ),
                        ),
                        items: [
                          ..._expenseTypes.map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          )),
                          if (_expenseTypes.isEmpty)
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
                      TextFormField(
                        controller: dueController,
                        decoration: const InputDecoration(
                          labelText: 'تاريخ الاستحقاق / الانتهاء (YYYY-MM-DD)',
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
                      final trailerIdVal =
                          isEdit ? selectedTrailerId : (selectedTrailerId);
                      if (trailerIdVal == null ||
                          amountController.text.trim().isEmpty) {
                        return;
                      }
                      try {
                        final data = {
                          'trailer_id': trailerIdVal,
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
                          'maintenance_date': DateTime.now().toIso8601String(),
                        };
                        if (isEdit) {
                          await _fleetService.updateTrailerMaintenance(
                            maintenance['id'] as int,
                            data,
                          );
                        } else {
                          await _fleetService.addTrailerMaintenance(data);
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
        title: Text(widget.trailerId != null
            ? 'مصاريف صيانة المقطورة'
            : 'مصاريف صيانة المقطورات'),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openExpenseDialog(),
              tooltip: 'إضافة مصروف',
            ),
        ],
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
                // Trailers summary list - scrollable
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: widget.trailerId != null && _trailers.isNotEmpty
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
                                              _trailers.first['plate']?.toString() ?? _trailers.first['plate_number']?.toString() ?? '',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      ..._buildTrailerDetailContent(_trailers.first['id'] as int, isDark),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _trailers.length,
                            itemBuilder: (context, index) {
                              final trailer = _trailers[index];
                              final trailerId = (trailer['id'] as num?)?.toInt() ?? 0;
                              final plate =
                                  trailer['plate']?.toString() ??
                                  trailer['plate_number']?.toString() ??
                                  '#$trailerId';
                              final model = trailer['model']?.toString() ?? '';
                              final total = _totalForTrailer(trailerId);
                              final count = _byTrailer()[trailerId]?.length ?? 0;
                              final status = trailer['status']?.toString() ?? '';
                              final hasOnCredit =
                                  _byTrailer()[trailerId]?.any(
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
                                                () => _openTrailerDetail(trailerId),
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
