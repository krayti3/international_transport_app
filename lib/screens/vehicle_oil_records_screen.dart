import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../services/supabase_service.dart';
import '../widgets/date_wheel_picker.dart';

// ignore_for_file: use_build_context_synchronously

class VehicleOilRecordsScreen extends StatefulWidget {
  final bool isAdmin;
  final int truckId;

  const VehicleOilRecordsScreen({
    super.key,
    required this.isAdmin,
    required this.truckId,
  });

  @override
  State<VehicleOilRecordsScreen> createState() => _VehicleOilRecordsScreenState();
}

class _VehicleOilRecordsScreenState extends State<VehicleOilRecordsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _records = [];
  String? _truckPlate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final trucksList = await _supabaseService.getTrucks();
      final truck = trucksList.firstWhere((t) => (t['id'] as num?)?.toInt() == widget.truckId, orElse: () => <String, dynamic>{'id': widget.truckId});
      final records = await _supabaseService.getOilChangeRecordsByTruck(widget.truckId);
      if (!mounted) return;
      setState(() {
        _truckPlate = (truck['plate']?.toString() ?? truck['plate_number']?.toString()) ?? '#${widget.truckId}';
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading oil records: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addOilChangeRecord() async {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    final selectedDateController = TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime.now()));
    double? selectedOilInterval;
    bool customOilInterval = false;
    final customOilController = TextEditingController();
    final nextKmController = TextEditingController();
    final nextDateController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String? selectedProvider;

    final kmResult = (await _supabaseService.getTrucks()).firstWhere(
      (t) => (t['id'] as num?)?.toInt() == widget.truckId,
      orElse: () => <String, dynamic>{},
    );
    final currentKm = (kmResult['current_km'] as num?)?.toDouble() ?? 0;
    final dailyKmAvg = (kmResult['daily_km_average'] as num?)?.toDouble();

    final providers = await _supabaseService.getProviders();
    List<String> providerNames = providers.map((p) => p['name']?.toString() ?? '').toList();

    void recalculateNext() {
      final interval = customOilInterval
          ? double.tryParse(customOilController.text.trim())
          : selectedOilInterval;
      final nextKm = currentKm + (interval ?? 0);
      nextKmController.text = nextKm.toStringAsFixed(0);

      if (dailyKmAvg != null && dailyKmAvg > 0 && interval != null && interval > 0) {
        final daysToAdd = (interval / dailyKmAvg).round();
        final nextDate = selectedDate.add(Duration(days: daysToAdd));
        nextDateController.text = DateFormat('dd/MM/yyyy').format(nextDate);
      } else {
        nextDateController.text = DateFormat('dd/MM/yyyy').format(selectedDate);
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تسجيل تغيير زيت'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الشاحنة: $_truckPlate', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: selectedDateController,
                  textDirection: TextDirection.ltr,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'تاريخ التغير',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final picked = await showDateWheelPicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      selectedDate = picked;
                      selectedDateController.text = DateFormat('dd/MM/yyyy').format(picked);
                      recalculateNext();
                      setDialogState(() {});
                    }
                  },
                ),
                DropdownButtonFormField<double>(
                  initialValue: selectedOilInterval,
                  decoration: const InputDecoration(labelText: 'كلمتراج نوع الزيت'),
                  items: const [
                    DropdownMenuItem(value: 7000.0, child: Text('7000 كم')),
                    DropdownMenuItem(value: 10000.0, child: Text('10000 كم')),
                    DropdownMenuItem(value: 15000.0, child: Text('15000 كم')),
                    DropdownMenuItem(value: 20000.0, child: Text('20000 كم')),
                    DropdownMenuItem(value: 25000.0, child: Text('25000 كم')),
                    DropdownMenuItem(value: 30000.0, child: Text('30000 كم')),
                    DropdownMenuItem(value: null, child: Text('أخرى')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      customOilInterval = true;
                    } else {
                      customOilInterval = false;
                      selectedOilInterval = value;
                      recalculateNext();
                    }
                    setDialogState(() {});
                  },
                ),
                if (customOilInterval)
                  TextFormField(
                    controller: customOilController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'أدخل الكيلومترات المخصصة'),
                    onChanged: (_) => recalculateNext(),
                  ),
                TextFormField(
                  controller: TextEditingController(text: currentKm.toStringAsFixed(0)),
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'عداد الكيلومترات الحالي'),
                ),
                TextFormField(
                  controller: nextKmController,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'الكيلومتر القادم'),
                ),
                if (dailyKmAvg != null && dailyKmAvg > 0)
                  TextFormField(
                    controller: TextEditingController(text: dailyKmAvg.toStringAsFixed(0)),
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'المعدل اليومي للكيلومترات'),
                  ),
                TextFormField(
                  controller: nextDateController,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'التاريخ القادم',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                ),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ (DH)'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: (selectedProvider == null || selectedProvider!.isEmpty) ? null : selectedProvider,
                  decoration: const InputDecoration(labelText: 'اسم المزود / الورشة'),
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
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (amountController.text.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة')),
                  );
                  return;
                }
                try {
                  final interval = customOilInterval
                      ? double.tryParse(customOilController.text.trim())
                      : selectedOilInterval;
                  final nextDateParsed = DateFormat('dd/MM/yyyy').tryParse(nextDateController.text.trim());
                  await _supabaseService.addTruckMaintenance({
                    'truck_id': widget.truckId,
                    'expense_type': 'oil_change',
                    'km_at_time': currentKm,
                    'amount': double.tryParse(amountController.text.trim()) ?? 0.0,
                     'provider_name': (selectedProvider == null || selectedProvider!.isEmpty) ? null : selectedProvider,
                    'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                    'maintenance_date': selectedDate.toIso8601String(),
                    'oil_interval_km': interval,
                    'next_change_km': double.tryParse(nextKmController.text.trim()) ?? 0,
                    'next_change_date': nextDateParsed?.toIso8601String() ?? selectedDate.toIso8601String(),
                  });
                  if (!mounted) return;
                  Navigator.pop(context);
                  await _loadData();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل تغيير الزيت')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editOilChangeRecord(Map<String, dynamic> record) async {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String? selectedProvider;
    final selectedDateController = TextEditingController();
    double? selectedOilInterval;
    bool customOilInterval = false;
    final customOilController = TextEditingController();
    final nextKmController = TextEditingController();
    final nextDateController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    final truckId = widget.truckId;
    final currentKm = (record['km_at_time'] as num?)?.toDouble() ?? 0;
    final kmResult = (await _supabaseService.getTrucks()).firstWhere(
      (t) => (t['id'] as num?)?.toInt() == truckId,
      orElse: () => <String, dynamic>{},
    );
    final dailyKmAvg = (kmResult['daily_km_average'] as num?)?.toDouble();

    final providers = await _supabaseService.getProviders();
    List<String> providerNames = providers.map((p) => p['name']?.toString() ?? '').toList();
    final presetIntervals = <double>[7000.0, 10000.0, 15000.0, 20000.0, 25000.0, 30000.0];
    final oilIntervalVal = (record['oil_interval_km'] as num?)?.toDouble();
    if (oilIntervalVal != null && presetIntervals.contains(oilIntervalVal)) {
      selectedOilInterval = oilIntervalVal;
    } else if (oilIntervalVal != null) {
      customOilInterval = true;
      customOilController.text = oilIntervalVal.toString();
    }

    amountController.text = (record['amount'] as num?)?.toDouble().toString() ?? '';
    selectedProvider = record['provider_name']?.toString() ?? '';
    descController.text = record['description']?.toString() ?? '';

    final maintenanceDate = record['maintenance_date']?.toString() ?? record['created_at']?.toString();
    if (maintenanceDate != null) {
      final parsedDate = DateTime.tryParse(maintenanceDate);
      if (parsedDate != null) {
        selectedDate = parsedDate;
        selectedDateController.text = DateFormat('dd/MM/yyyy').format(parsedDate);
      }
    }

    nextKmController.text = (record['next_change_km'] as num?)?.toInt().toString() ?? '';

    final nextChangeDate = record['next_change_date']?.toString();
    if (nextChangeDate != null) {
      final parsedNextDate = DateTime.tryParse(nextChangeDate);
      if (parsedNextDate != null) {
        nextDateController.text = DateFormat('dd/MM/yyyy').format(parsedNextDate);
      }
    }

    void recalculateNext() {
      final interval = customOilInterval
          ? double.tryParse(customOilController.text.trim())
          : selectedOilInterval;
      final nextKm = currentKm + (interval ?? 0);
      nextKmController.text = nextKm.toStringAsFixed(0);

      if (dailyKmAvg != null && dailyKmAvg > 0 && interval != null && interval > 0) {
        final daysToAdd = (interval / dailyKmAvg).round();
        final nextDate = selectedDate.add(Duration(days: daysToAdd));
        nextDateController.text = DateFormat('dd/MM/yyyy').format(nextDate);
      } else {
        nextDateController.text = DateFormat('dd/MM/yyyy').format(selectedDate);
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تعديل سجل تغيير زيت'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: selectedDateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'تاريخ التغير',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final picked = await showDateWheelPicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      selectedDate = picked;
                      selectedDateController.text = DateFormat('dd/MM/yyyy').format(picked);
                      recalculateNext();
                      setDialogState(() {});
                    }
                  },
                ),
                DropdownButtonFormField<double>(
                  initialValue: selectedOilInterval,
                  decoration: const InputDecoration(labelText: 'كلمتراج نوع الزيت'),
                  items: const [
                    DropdownMenuItem(value: 7000.0, child: Text('7000 كم')),
                    DropdownMenuItem(value: 10000.0, child: Text('10000 كم')),
                    DropdownMenuItem(value: 15000.0, child: Text('15000 كم')),
                    DropdownMenuItem(value: 20000.0, child: Text('20000 كم')),
                    DropdownMenuItem(value: 25000.0, child: Text('25000 كم')),
                    DropdownMenuItem(value: 30000.0, child: Text('30000 كم')),
                    DropdownMenuItem(value: null, child: Text('أخرى')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      customOilInterval = true;
                    } else {
                      customOilInterval = false;
                      selectedOilInterval = value;
                      recalculateNext();
                    }
                    setDialogState(() {});
                  },
                ),
                if (customOilInterval)
                  TextFormField(
                    controller: customOilController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'أدخل الكيلومترات المخصصة'),
                    onChanged: (_) => recalculateNext(),
                  ),
                TextFormField(
                  controller: TextEditingController(text: currentKm.toStringAsFixed(0)),
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'عداد الكيلومترات الحالي'),
                ),
                TextFormField(
                  controller: nextKmController,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'الكيلومتر القادم'),
                ),
                if (dailyKmAvg != null && dailyKmAvg > 0)
                  TextFormField(
                    controller: TextEditingController(text: dailyKmAvg.toStringAsFixed(0)),
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'المعدل اليومي للكيلومترات'),
                  ),
                TextFormField(
                  controller: nextDateController,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'التاريخ القادم',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                ),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ (DH)'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: (selectedProvider == null || selectedProvider!.isEmpty) ? null : selectedProvider,
                  decoration: const InputDecoration(labelText: 'اسم المزود / الورشة'),
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
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (amountController.text.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة')),
                  );
                  return;
                }
                try {
                  final interval = customOilInterval
                      ? double.tryParse(customOilController.text.trim())
                      : selectedOilInterval;
                  final nextDateParsed = DateFormat('dd/MM/yyyy').tryParse(nextDateController.text.trim());
                  await _supabaseService.updateTruckMaintenance(record['id'] as int, {
                    'truck_id': truckId,
                    'expense_type': 'oil_change',
                    'km_at_time': currentKm,
                    'amount': double.tryParse(amountController.text.trim()) ?? 0.0,
                     'provider_name': (selectedProvider == null || selectedProvider!.isEmpty) ? null : selectedProvider,
                    'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                    'maintenance_date': selectedDate.toIso8601String(),
                    'oil_interval_km': interval,
                    'next_change_km': double.tryParse(nextKmController.text.trim()) ?? 0,
                    'next_change_date': nextDateParsed?.toIso8601String() ?? selectedDate.toIso8601String(),
                  });
                  if (!mounted) return;
                  Navigator.pop(context);
                  await _loadData();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تحديث سجل تغيير الزيت')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('سجل الزيت - $_truckPlate'),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addOilChangeRecord,
              tooltip: 'تسجيل تغيير زيت',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(child: Text('لا توجد سجلات تغيير زيت', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final record = _records[index];
                    final amount = (record['amount'] as num?)?.toDouble() ?? 0.0;
                    final dateStr = record['maintenance_date']?.toString() ?? record['created_at']?.toString() ?? '';
                    final km = (record['km_at_time'] as num?)?.toDouble();
                    final provider = record['provider_name']?.toString() ?? '';
                    final desc = record['description']?.toString() ?? '';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: isDark ? const Color(0xFF1E1E1E) : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.oil_barrel_rounded, color: Colors.amber),
                        title: Text(
                          _truckPlate ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (km != null) Text('العداد: ${km.toStringAsFixed(0)} كم'),
                            Text('${amount.toStringAsFixed(2)} DH • ${dateStr.isNotEmpty ? DateFormat('dd/MM/yyyy').format(DateTime.tryParse(dateStr) ?? DateTime.now()) : ''}', textDirection: TextDirection.ltr),
                            if (provider.isNotEmpty) Text('المزود: $provider'),
                            if (desc.isNotEmpty) Text('ملاحظات: $desc'),
                            if (record['oil_interval_km'] != null) Text('كلمتراج نوع الزيت: ${(record['oil_interval_km'] as num).toInt()} كم'),
                            if (record['next_change_km'] != null) Text('الكيلومتر القادم: ${(record['next_change_km'] as num).toInt()} كم'),
                            if (record['next_change_date'] != null) Text('التاريخ القادم: ${DateFormat('dd/MM/yyyy').format(DateTime.tryParse(record['next_change_date']) ?? DateTime.now())}', textDirection: TextDirection.ltr),
                          ],
                        ),
                        trailing: widget.isAdmin
                            ? PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editOilChangeRecord(record);
                                  } else if (value == 'delete') {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('حذف السجل'),
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
                                    ).then((confirm) {
                                      if (confirm == true) {
                                        _supabaseService.deleteTruckMaintenance(record['id'] as int).then((_) {
                                          _loadData();
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف السجل')));
                                        });
                                      }
                                    });
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                  PopupMenuItem(value: 'delete', child: Text('حذف')),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
                ),
    );
  }
}
