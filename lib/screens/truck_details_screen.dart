import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../services/supabase_service.dart';
import '../l10n/app_localizations.dart';
import 'truck_documents_screen.dart';
import 'oil_change_alerts_screen.dart';
import 'truck_maintenance_screen.dart';
import 'trip_orders_screen.dart';
import '../widgets/date_wheel_picker.dart';

// ignore_for_file: use_build_context_synchronously

class TruckDetailsScreen extends StatefulWidget {
  const TruckDetailsScreen({
    super.key,
    required this.truck,
    required this.onDeleted,
    required this.onUpdated,
  });

  final Map<String, dynamic> truck;
  final VoidCallback onDeleted;
  final VoidCallback onUpdated;

  @override
  State<TruckDetailsScreen> createState() => _TruckDetailsScreenState();
}

class _TruckDetailsScreenState extends State<TruckDetailsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isDeleting = false;
  bool _hasLinkedRecords = false;
  int _tripCount = 0;
  int _maintenanceCount = 0;
  int _documentCount = 0;
  int _oilRecordsCount = 0;
  List<Map<String, dynamic>> _allTrailers = [];
  List<Map<String, dynamic>> _allDrivers = [];

  @override
  void initState() {
    super.initState();
    _checkLinkedRecords();
    _checkOilRecords();
    _loadTrailers();
    _loadDrivers();
  }

  Future<void> _checkLinkedRecords() async {
    final truckId = widget.truck['id'] as int?;
    if (truckId == null) return;

    final trips = await _supabaseService.getTripOrders();
    final maintenances = await _supabaseService.getTruckMaintenances();
    final documents = await _supabaseService.getDocuments();
    final truckDocuments = await _supabaseService.getTruckDocuments();

    final normalizedTruckDocs = truckDocuments.map((d) {
      final normalized = Map<String, dynamic>.from(d);
      normalized['vehicle_type'] = 'truck';
      normalized['vehicle_id'] = d['truck_id'];
      return normalized;
    }).toList();

    final allDocs = <Map<String, dynamic>>[];
    for (final d in documents) {
      allDocs.add(Map<String, dynamic>.from(d));
    }
    for (final d in normalizedTruckDocs) {
      allDocs.add(d);
    }

    final truckTrips = trips.where((t) => t['truck_id'] == truckId).toList();
    final truckMaintenances = maintenances.where((m) => m['truck_id'] == truckId).toList();
    final truckLinkedDocs = allDocs.where((d) => d['vehicle_type'] == 'truck' && d['vehicle_id'] == truckId).toList();

    if (mounted) {
      setState(() {
        _tripCount = truckTrips.length;
        _maintenanceCount = truckMaintenances.length;
        _documentCount = truckLinkedDocs.length;
        _hasLinkedRecords = _tripCount > 0 || _maintenanceCount > 0 || _documentCount > 0;
      });
    }
  }

  Future<void> _checkOilRecords() async {
    final truckId = widget.truck['id'] as int?;
    if (truckId == null) return;
    final records = await _supabaseService.getOilChangeRecordsByTruck(truckId);
    if (mounted) {
      setState(() {
        _oilRecordsCount = records.length;
      });
    }
  }

  Future<void> _loadTrailers() async {
    try {
      final trailers = await _supabaseService.getTrailers();
      if (mounted) {
        setState(() {
          _allTrailers = trailers;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allTrailers = [];
        });
      }
    }
  }

  Future<void> _loadDrivers() async {
    try {
      final drivers = await _supabaseService.getDrivers();
      if (mounted) {
        setState(() {
          _allDrivers = drivers;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allDrivers = [];
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    final inUse = await _supabaseService.isTruckInUse(widget.truck['id'] as int);
    if (inUse) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('تأكيد الحذف')),
          content: Text(context.tr('لا يمكن حذف الشاحنة لأنها مرتبطة ببيانات أخرى')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('إلغاء')),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('حذف الشاحنة')),
        content: Text(context.tr('سيتم حذف هذه الشاحنة نهائياً')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('إلغاء')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr('حذف')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await _supabaseService.deleteTruck(widget.truck['id'] as int);
      if (!mounted) return;
      widget.onDeleted();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('تم حذف الشاحنة بنجاح'))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('خطأ في حذف الشاحنة: {0}', [e]))),
      );
    }
  }

  Future<int?> _showAddTrailerDialog() async {
    final plateController = TextEditingController();
    final typeController = TextEditingController();
    String status = 'active';
    int? newTrailerId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.tr('إضافة مقطورة جديدة')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: plateController,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                  decoration: InputDecoration(labelText: context.tr('لوحة الترقيم')),
                ),
                TextFormField(
                  controller: typeController,
                  decoration: InputDecoration(labelText: context.tr('النوع')),
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: InputDecoration(labelText: context.tr('الحالة')),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('نشط')),
                    DropdownMenuItem(value: 'maintenance', child: Text('صيانة')),
                    DropdownMenuItem(value: 'inactive', child: Text('غير نشط')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => status = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('إلغاء')),
            ),
            ElevatedButton(
              onPressed: () async {
                final plate = plateController.text.trim();
                if (plate.isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('يرجى إدخال رقم اللوحة'))),
                  );
                  return;
                }
                final isUnique = await _supabaseService.checkTrailerPlateUnique(plate);
                if (!isUnique) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('رقم اللوحة موجود مسبقاً'))),
                  );
                  return;
                }
                try {
                  newTrailerId = await _supabaseService.addTrailer({
                    'plate_number': plate,
                    'type': typeController.text.trim(),
                    'status': status,
                  });
                  if (!context.mounted) return;
                  Navigator.pop(context);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('خطأ في حفظ المقطورة: {0}', [e]))),
                  );
                }
              },
              child: Text(context.tr('حفظ')),
            ),
          ],
        ),
      ),
    );
    return newTrailerId;
  }

  Future<int?> _showAddDriverDialog() async {
    final nameController = TextEditingController();
    String status = 'active';
    int? newDriverId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.tr('إضافة سائق جديد')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: context.tr('الاسم')),
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: InputDecoration(labelText: context.tr('الحالة')),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('نشط')),
                    DropdownMenuItem(value: 'inactive', child: Text('غير نشط')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => status = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('إلغاء')),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('يرجى إدخال اسم السائق'))),
                  );
                  return;
                }
                try {
                  newDriverId = await _supabaseService.addDriver({
                    'name': name,
                    'status': status,
                  });
                  if (!context.mounted) return;
                  Navigator.pop(context);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('خطأ في حفظ السائق: {0}', [e]))),
                  );
                }
              },
              child: Text(context.tr('حفظ')),
            ),
          ],
        ),
      ),
    );
    return newDriverId;
  }

  Future<void> _openEditDialog() async {
    final plateController = TextEditingController(
      text: widget.truck['plate']?.toString() ?? widget.truck['plate_number']?.toString() ?? '',
    );
    final modelController = TextEditingController(text: widget.truck['model']?.toString() ?? '');
    final brandController = TextEditingController(text: widget.truck['brand']?.toString() ?? '');
    final currentKmController = TextEditingController(
      text: widget.truck['current_km']?.toString() ?? '',
    );
    final oilChangeController = TextEditingController(
      text: widget.truck['oil_change_km']?.toString() ?? '',
    );
    final locationController = TextEditingController(text: widget.truck['current_location']?.toString() ?? '');
    String status = widget.truck['status']?.toString() ?? 'active';
    int? defaultTrailerId =
        int.tryParse(widget.truck['default_trailer_id']?.toString() ?? '');
    int? defaultDriverId =
        int.tryParse(widget.truck['default_driver_id']?.toString() ?? '');
    final fiscalPowerController = TextEditingController(
      text: widget.truck['fiscal_power']?.toString() ?? '',
    );
    final emptyWeightController = TextEditingController(
      text: widget.truck['empty_weight']?.toString() ?? '',
    );
    DateTime? purchaseDate = widget.truck['purchase_date'] != null
        ? DateTime.tryParse(widget.truck['purchase_date'].toString())
        : null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('تعديل الشاحنة')),
          content: SingleChildScrollView(
            child: Form(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: plateController,
                    decoration: InputDecoration(labelText: context.tr('رقم اللوحة')),
                  ),
                  TextFormField(
                    controller: brandController,
                    decoration: InputDecoration(labelText: context.tr('الماركة')),
                  ),
                  TextFormField(
                    controller: modelController,
                    decoration: InputDecoration(labelText: context.tr('الموديل')),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: InputDecoration(labelText: context.tr('الحالة')),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('نشط')),
                      DropdownMenuItem(value: 'maintenance', child: Text('صيانة')),
                      DropdownMenuItem(value: 'inactive', child: Text('غير نشط')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => status = value);
                    },
                  ),
                  TextFormField(
                    controller: currentKmController,
                    decoration: InputDecoration(labelText: context.tr('الكيلومتر الحالي')),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: oilChangeController,
                    decoration: InputDecoration(labelText: context.tr('تغيير الزيت عند')),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: locationController,
                    decoration: InputDecoration(labelText: context.tr('الموقع الحالي')),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: fiscalPowerController,
                          decoration: InputDecoration(labelText: context.tr('القوة الجبائية')),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: emptyWeightController,
                          decoration: InputDecoration(labelText: context.tr('الوزن الفارغ')),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () async {
                      final picked = await showDateWheelPicker(
                        context: context,
                        initialDate: purchaseDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2030),
                      );
                       if (picked != null) {
                         setDialogState(() => purchaseDate = picked);
                       }
                    },
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: context.tr('تاريخ الشراء')),
                        child: Text(
                          purchaseDate == null
                              ? context.tr('اختر التاريخ')
                              : DateFormat('dd/MM/yyyy').format(purchaseDate!),
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<int?>(
                        key: ValueKey(defaultTrailerId),
                        initialValue: defaultTrailerId,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: context.tr('المقطورة الافتراضية')),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('بدون مقطورة افتراضية'),
                              ),
                              ..._allTrailers
                                  .toList()
                                  .sorted((a, b) {
                                    final aPlate = (a['plate_number']?.toString() ?? a['plate']?.toString() ?? '').toLowerCase();
                                    final bPlate = (b['plate_number']?.toString() ?? b['plate']?.toString() ?? '').toLowerCase();
                                    return aPlate.compareTo(bPlate);
                                  })
                                  .map(
                                    (t) => DropdownMenuItem<int?>(
                                      value: t['id'] as int?,
                                      child: Text(
                                        t['plate_number']?.toString() ??
                                            t['plate']?.toString() ??
                                            'بدون لوحة',
                                      ),
                                    ),
                                  ),
                            ],
                            onChanged: (value) {
                              if (value != null) setDialogState(() => defaultTrailerId = value);
                            },
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        tooltip: context.tr('إضافة مقطورة جديدة'),
                        onPressed: () async {
                          final newId = await _showAddTrailerDialog();
                          if (newId != null && mounted) {
                            await _loadTrailers();
                            if (mounted) {
                              setDialogState(() {
                                defaultTrailerId = newId;
                              });
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButtonFormField<int?>(
                            key: ValueKey(defaultDriverId),
                            initialValue: defaultDriverId,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: context.tr('السائق الافتراضي')),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('بدون سائق افتراضي'),
                              ),
                              ..._allDrivers
                                  .toList()
                                  .sorted((a, b) {
                                    final aName = (a['name']?.toString() ?? '').toLowerCase();
                                    final bName = (b['name']?.toString() ?? '').toLowerCase();
                                    return aName.compareTo(bName);
                                  })
                                  .map(
                                    (d) => DropdownMenuItem<int?>(
                                      value: d['id'] as int?,
                                      child: Text(d['name']?.toString() ?? 'بدون اسم'),
                                    ),
                                  ),
                            ],
                            onChanged: (value) {
                              if (value != null) setDialogState(() => defaultDriverId = value);
                            },
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        tooltip: context.tr('إضافة سائق جديد'),
                        onPressed: () async {
                          final newId = await _showAddDriverDialog();
                          if (newId != null && mounted) {
                            await _loadDrivers();
                            if (mounted) {
                              setDialogState(() {
                                defaultDriverId = newId;
                              });
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('إلغاء')),
            ),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'plate_number': plateController.text.trim(),
                  'brand': brandController.text.trim(),
                  'model': modelController.text.trim(),
                  'status': status,
                  'current_km': double.tryParse(currentKmController.text.trim()) ?? 0.0,
                  'oil_change_km': double.tryParse(oilChangeController.text.trim()),
                  'current_location': locationController.text.trim(),
                  'default_trailer_id': defaultTrailerId,
                  'default_driver_id': defaultDriverId,
                  'fiscal_power': double.tryParse(fiscalPowerController.text.trim()),
                  'empty_weight': double.tryParse(emptyWeightController.text.trim()),
                  'purchase_date': purchaseDate?.toIso8601String().split('T').first,
                };
                await _supabaseService.updateTruck(
                  widget.truck['id'] as int,
                  data,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                widget.onUpdated();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('تم تحديث البيانات بنجاح'))),
                  );
                }
              },
              child: Text(context.tr('حفظ')),
            ),
          ],
        ),
      ),
    );
  }

  void _openOilChangeScreen() {
    final truckId = widget.truck['id'] as int?;
    if (truckId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OilChangeAlertsScreen(
          isAdmin: true,
          truckId: truckId,
        ),
      ),
    );
  }

  void _openDocumentsScreen() {
    final truckId = widget.truck['id'] as int?;
    if (truckId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TruckDocumentsScreen(
          isAdmin: true,
          truckId: truckId,
        ),
      ),
    );
  }

  void _openMaintenanceScreen() {
    final truckId = widget.truck['id'] as int?;
    if (truckId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TruckMaintenanceScreen(
          isAdmin: true,
          truckId: truckId,
        ),
      ),
    );
  }

  void _openTripsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripOrdersScreen(isAdmin: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plate = widget.truck['plate']?.toString() ?? widget.truck['plate_number']?.toString() ?? context.tr('بدون لوحة');
    final model = widget.truck['model']?.toString() ?? '';
    final brand = widget.truck['brand']?.toString() ?? '';
    final status = widget.truck['status']?.toString() ?? 'active';
    final currentKm = (widget.truck['current_km'] as num?)?.toDouble() ?? 0.0;
    final oilChangeKm = (widget.truck['oil_change_km'] as num?)?.toDouble();
    final location = widget.truck['current_location']?.toString() ?? '';

    String statusLabel = context.tr('نشط');
    if (status == 'maintenance') statusLabel = context.tr('صيانة');
    if (status == 'inactive') statusLabel = context.tr('غير نشط');

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('تفاصيل الشاحنة')),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _isDeleting ? null : _openEditDialog,
            tooltip: context.tr('تعديل'),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _isDeleting ? null : _confirmDelete,
            tooltip: context.tr('حذف'),
          ),
        ],
      ),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: isDark ? const Color(0xFF1E1E1E) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(context.tr('رقم اللوحة'), plate, isDark),
                        const SizedBox(height: 12),
                        _buildInfoRow(context.tr('الماركة'), brand, isDark),
                        const SizedBox(height: 12),
                        _buildInfoRow(context.tr('الموديل'), model, isDark),
                        const SizedBox(height: 12),
                        _buildInfoRow(context.tr('الحالة'), statusLabel, isDark),
                        const SizedBox(height: 12),
                        _buildInfoRow(context.tr('الكيلومتر الحالي'), '${currentKm.toStringAsFixed(0)} ${context.tr('كم')}', isDark),
                        const SizedBox(height: 12),
                        _buildInfoRow(context.tr('تغيير الزيت عند'), oilChangeKm != null ? '${oilChangeKm.toStringAsFixed(0)} ${context.tr('كم')}' : '-', isDark),
                        const SizedBox(height: 12),
                        _buildInfoRow(context.tr('الموقع الحالي'), location, isDark),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  color: isDark ? const Color(0xFF1E1E1E) : null,
                  child: ListTile(
                    leading: const Icon(Icons.description, color: Colors.blue),
                    title: Text(context.tr('وثائق الشاحنة')),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                    onTap: _openDocumentsScreen,
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  color: isDark ? const Color(0xFF1E1E1E) : null,
                  child: ListTile(
                    leading: const Icon(Icons.build, color: Colors.blue),
                    title: Text(context.tr('صيانة الشاحنة')),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                    onTap: _openMaintenanceScreen,
                  ),
                ),
                const SizedBox(height: 20),
                if (_oilRecordsCount > 0)
                  Card(
                    color: isDark ? const Color(0xFF1E1E1E) : null,
                    child: ListTile(
                      leading: const Icon(Icons.oil_barrel, color: Colors.blue),
                      title: Text(context.tr('سجل تغيير الزيت')),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                      onTap: _openOilChangeScreen,
                    ),
                  ),
                const SizedBox(height: 20),
                Card(
                  color: isDark ? const Color(0xFF1E1E1E) : null,
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping, color: Colors.blue),
                    title: Text(context.tr('رحلات الشاحنة')),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                    onTap: _openTripsScreen,
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  color: isDark ? const Color(0xFF1E1E1E) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('السجل'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _buildStatRow(context.tr('رحلات'), '$_tripCount', Icons.local_shipping, isDark),
                        const SizedBox(height: 8),
                        _buildStatRow(context.tr('صيانة'), '$_maintenanceCount', Icons.build, isDark),
                        const SizedBox(height: 8),
                        _buildStatRow(context.tr('وثائق'), '$_documentCount', Icons.description, isDark),
                        if (!_hasLinkedRecords) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withValues(alpha: isDark ? 0.5 : 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: isDark ? Colors.orange[300] : Colors.orange.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.tr('لا توجد رحلات أو صيانة أو وثائق مسجلة'),
                                    style: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange.shade700, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String count, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? Colors.blue[300] : Colors.blue.shade700),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey.shade700),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.blue[300] : Colors.blue.shade700,
            ),
          ),
        ),
      ],
    );
  }
}
