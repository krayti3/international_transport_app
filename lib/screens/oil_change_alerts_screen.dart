import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:collection/collection.dart';
import '../services/supabase_service.dart';
import 'vehicle_oil_records_screen.dart';
import '../widgets/date_wheel_picker.dart';

// ignore_for_file: use_build_context_synchronously

class OilChangeAlertsScreen extends StatefulWidget {
  const OilChangeAlertsScreen({super.key, required this.isAdmin, this.truckId});

  final bool isAdmin;
  final int? truckId;

  @override
  State<OilChangeAlertsScreen> createState() => _OilChangeAlertsScreenState();
}

class _OilChangeAlertsScreenState extends State<OilChangeAlertsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _trucks = [];
  List<Map<String, dynamic>> _oilRecords = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _cashBoxes = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    final trucks = await _supabaseService.getTrucks();
    final records = await _supabaseService.getOilChangeRecords();
    final cashBoxes = await _supabaseService.getCashBoxes();
    if (!mounted) return;
    setState(() {
      _trucks = widget.truckId != null
          ? trucks.where((t) => (t['id'] as num?)?.toInt() == widget.truckId).toList()
          : trucks;
      _oilRecords = widget.truckId != null
          ? records.where((r) => (r['truck_id'] as num?)?.toInt() == widget.truckId).toList()
          : records;
      _cashBoxes = cashBoxes;
      _isLoading = false;
    });
  }

  Future<void> _addOilChangeRecord() async {
    if (widget.truckId == null && _trucks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد شاحنات مسجلة')),
      );
      return;
    }

    final amountController = TextEditingController();
    final descController = TextEditingController();
    String? selectedProvider;
    String? selectedCashBox;
    final selectedDateController = TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime.now()));
    double? selectedOilInterval;
    bool customOilInterval = false;
    final customOilController = TextEditingController();
    final nextKmController = TextEditingController();
    final nextDateController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    final providers = await _supabaseService.getProviders();
    List<String> providerNames = providers.map((p) => p['name']?.toString() ?? '').toList();

    final trucks = _trucks;
    int? effectiveTruckId = widget.truckId;

    final truck = effectiveTruckId != null
        ? _trucks.firstWhere((t) => (t['id'] as num?)?.toInt() == effectiveTruckId, orElse: () => <String, dynamic>{})
        : (_trucks.isNotEmpty ? _trucks.first : null);
    final currentKm = (truck?['current_km'] as num?)?.toDouble() ?? 0;
    final dailyKmAvg = (truck?['daily_km_average'] as num?)?.toDouble();

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
                if (widget.truckId == null)
                  DropdownButtonFormField<int>(
                    initialValue: effectiveTruckId,
                    decoration: const InputDecoration(labelText: 'الشاحنة'),
                    items: trucks
                        .toList()
                        .sorted((a, b) {
                          final aPlate = (a['plate']?.toString() ?? a['plate_number']?.toString() ?? '').toLowerCase();
                          final bPlate = (b['plate']?.toString() ?? b['plate_number']?.toString() ?? '').toLowerCase();
                          return aPlate.compareTo(bPlate);
                        })
                        .map((t) => DropdownMenuItem<int>(
                              value: (t['id'] as num?)?.toInt(),
                              child: Text(t['plate']?.toString() ?? t['plate_number']?.toString() ?? 'بدون لوحة'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setDialogState(() => effectiveTruckId = v);
                      recalculateNext();
                    },
                  ),
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
                 const SizedBox(height: 12),
                 if (_cashBoxes.isNotEmpty)
                   DropdownButtonFormField<String>(
                     initialValue: selectedCashBox,
                     decoration: const InputDecoration(labelText: 'الصندوق المصدر'),
                     items: _cashBoxes.map((b) {
                       return DropdownMenuItem(
                         value: b['code']?.toString(),
                         child: Text(b['label']?.toString() ?? ''),
                       );
                     }).toList(),
                     onChanged: (v) {
                       if (v != null) {
                         setDialogState(() => selectedCashBox = v);
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
                final truckIdToSave = effectiveTruckId ?? widget.truckId;
                if (truckIdToSave == null) return;
                try {
                  final interval = customOilInterval
                      ? double.tryParse(customOilController.text.trim())
                      : selectedOilInterval;
                  final nextDateParsed = DateFormat('dd/MM/yyyy').tryParse(nextDateController.text.trim());
                  await _supabaseService.addTruckMaintenance({
                    'truck_id': truckIdToSave,
                    'expense_type': 'oil_change',
                    'km_at_time': currentKm,
                    'amount': double.tryParse(amountController.text.trim()) ?? 0.0,
                    'provider_name': (selectedProvider == null || selectedProvider!.isEmpty) ? null : selectedProvider,
                    'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                    'maintenance_date': selectedDate.toIso8601String(),
                    'oil_interval_km': interval,
                    'next_change_km': double.tryParse(nextKmController.text.trim()) ?? 0,
                    'next_change_date': nextDateParsed?.toIso8601String() ?? selectedDate.toIso8601String(),
                    'payment_status': selectedCashBox ?? 'on_credit',
                  });
                  if (!mounted) return;
                  Navigator.pop(context);
                  await _loadAlerts();
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
    String? selectedCashBox;
    final selectedDateController = TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime.now()));
    double? selectedOilInterval;
    bool customOilInterval = false;
    final customOilController = TextEditingController();
    final nextKmController = TextEditingController();
    final nextDateController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    final providers = await _supabaseService.getProviders();
    List<String> providerNames = providers.map((p) => p['name']?.toString() ?? '').toList();
    final truckId = (record['truck_id'] as num?)?.toInt() ?? widget.truckId;

    final truck = _trucks.firstWhere(
      (t) => (t['id'] as num?)?.toInt() == truckId,
      orElse: () => <String, dynamic>{},
    );
    final currentKm = (record['km_at_time'] as num?)?.toDouble() ?? 0;
    final dailyKmAvg = (truck['daily_km_average'] as num?)?.toDouble();
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
    selectedCashBox = record['payment_status']?.toString();
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
                const SizedBox(height: 12),
                if (_cashBoxes.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedCashBox,
                    decoration: const InputDecoration(labelText: 'الصندوق المصدر'),
                    items: _cashBoxes.map((b) {
                      return DropdownMenuItem(
                        value: b['code']?.toString(),
                        child: Text(b['label']?.toString() ?? ''),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => selectedCashBox = v);
                      }
                    },
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
                     'payment_status': selectedCashBox ?? 'on_credit',
                   });
                  if (!mounted) return;
                  Navigator.pop(context);
                  await _loadAlerts();
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
        title: Text(widget.truckId != null ? 'سجل تغيير الزيت' : 'سجلات تغيير الزيت'),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addOilChangeRecord,
              tooltip: 'تسجيل تغيير زيت',
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAlerts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _oilRecords.isEmpty
              ? Center(
                  child: Text(
                    widget.truckId != null ? 'لا توجد سجلات تغيير زيت لهذه الشاحنة' : 'لا توجد سجلات تغيير زيت',
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                )
              : widget.truckId == null
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStat('الشاحنات', '${_trucks.length}'),
                                _buildStat('السجلات', '${_oilRecords.length}'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: _trucks.length,
                            itemBuilder: (context, index) {
                              final truck = _trucks[index];
                              final tId = (truck['id'] as num?)?.toInt() ?? 0;
                              final records = _oilRecords.where((r) => (r['truck_id'] as num?)?.toInt() == tId).toList();
                              final plate = truck['plate']?.toString() ?? truck['plate_number']?.toString() ?? '#$tId';
                              final total = records.fold<double>(
                                0,
                                (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0.0),
                              );

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => VehicleOilRecordsScreen(
                                          isAdmin: widget.isAdmin,
                                          truckId: tId,
                                        ),
                                      ),
                                    );
                                  },
                                  child: ListTile(
                                    leading: const Icon(Icons.local_shipping_rounded, color: Colors.amber),
                                    title: Text(plate, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Text('${records.length} سجل • ${total.toStringAsFixed(2)} DH'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text('${records.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.chevron_left_rounded, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _oilRecords.length,
                      itemBuilder: (context, index) {
                        final record = _oilRecords[index];
                        final truckId = (record['truck_id'] as num?)?.toInt();
                        final truck = _trucks.firstWhere(
                          (t) => (t['id'] as num?)?.toInt() == truckId,
                          orElse: () => <String, dynamic>{},
                        );
                        final plate = truck['plate']?.toString() ?? truck['plate_number']?.toString() ?? '#$truckId';
                        final amount = (record['amount'] as num?)?.toDouble() ?? 0.0;
                        final km = (record['km_at_time'] as num?)?.toDouble();
                        final dateStr = record['maintenance_date']?.toString() ?? record['created_at']?.toString() ?? '';
                        final desc = record['description']?.toString() ?? '';
                        final provider = record['provider_name']?.toString() ?? '';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          color: isDark ? const Color(0xFF1E1E1E) : null,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const Icon(Icons.oil_barrel_rounded, color: Colors.amber),
                            title: Text(
                              plate,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.left,
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
                                if (record['maintenance_date'] != null) Text('تاريخ التغير: ${DateFormat('dd/MM/yyyy').format(DateTime.tryParse(record['maintenance_date']) ?? DateTime.now())}', textDirection: TextDirection.ltr),
                              ],
                            ),
                            trailing: widget.isAdmin
                                ? PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        await _editOilChangeRecord(record);
                                      } else if (value == 'delete') {
                                        final confirm = await showDialog<bool>(
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
                                        );
                                        if (confirm == true) {
                                          await _supabaseService.deleteTruckMaintenance(record['id'] as int);
                                          await _loadAlerts();
                                        }
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

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
