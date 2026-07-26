import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../services/supabase_service.dart';
import '../l10n/app_localizations.dart';
import 'truck_details_screen.dart';
import '../widgets/date_wheel_picker.dart';

// ignore_for_file: use_build_context_synchronously

class TrucksScreen extends StatefulWidget {
  const TrucksScreen({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  State<TrucksScreen> createState() => _TrucksScreenState();
}

class _TrucksScreenState extends State<TrucksScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _trucks = [];
  List<Map<String, dynamic>> _trailers = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _filteredTrucks = [];
  List<Map<String, dynamic>> _trips = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus = 'active';

  static const _statusOptions = {
    'active': 'نشط',
    'maintenance': 'صيانة',
    'inactive': 'غير نشط',
  };

  @override
  void initState() {
    super.initState();
    _loadTrucks();
    _searchController.addListener(_filterTrucks);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterTrucks);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrucks() async {
    setState(() => _isLoading = true);
    final trucks = await _supabaseService.getTrucks();
    final trailers = await _supabaseService.getTrailers();
    final drivers = await _supabaseService.getDrivers();
    final trips = await _supabaseService.getTripOrders();
    setState(() {
      _trucks = trucks
          .sorted((a, b) {
            final aPlate = (a['plate']?.toString() ?? a['plate_number']?.toString() ?? '').toLowerCase();
            final bPlate = (b['plate']?.toString() ?? b['plate_number']?.toString() ?? '').toLowerCase();
            return aPlate.compareTo(bPlate);
          })
          .toList();
      _trailers = trailers;
      _drivers = drivers;
      _trips = trips;
      _filterTrucks();
      _isLoading = false;
    });
  }

  Future<void> _loadTrailers() async {
    final trailers = await _supabaseService.getTrailers();
    setState(() {
      _trailers = trailers.toList();
    });
  }

  Future<void> _loadDrivers() async {
    final drivers = await _supabaseService.getDrivers();
    setState(() {
      _drivers = drivers.toList();
    });
  }

  void _filterTrucks() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredTrucks = _trucks.where((truck) {
        final plate = (truck['plate']?.toString() ?? truck['plate_number']?.toString() ?? '').toLowerCase();
        final model = truck['model']?.toString().toLowerCase() ?? '';
        final status = truck['status']?.toString().toLowerCase() ?? '';
        final location = truck['current_location']?.toString().toLowerCase() ?? '';
        final matchesSearch = query.isEmpty ||
            plate.contains(query) ||
            model.contains(query) ||
            status.contains(query) ||
            location.contains(query);
        final matchesStatus = _selectedStatus == null ||
            status == _selectedStatus?.toLowerCase();
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Widget _buildStatusFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: Text(context.tr('الكل')),
            selected: _selectedStatus == null,
            onSelected: (_) {
              _selectedStatus = null;
              _filterTrucks();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(context.tr('نشط')),
            selected: _selectedStatus == 'active',
            onSelected: (_) {
              _selectedStatus = 'active';
              _filterTrucks();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(context.tr('صيانة')),
            selected: _selectedStatus == 'maintenance',
            onSelected: (_) {
              _selectedStatus = 'maintenance';
              _filterTrucks();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(context.tr('غير نشط')),
            selected: _selectedStatus == 'inactive',
            onSelected: (_) {
              _selectedStatus = 'inactive';
              _filterTrucks();
            },
          ),
        ],
      ),
    );
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

  Future<void> _openTruckDialog({Map<String, dynamic>? truck}) async {
    final isEdit = truck != null;
    final plateController =
        TextEditingController(text: truck?['plate_number']?.toString() ?? truck?['plate']?.toString() ?? '');
    final modelController =
        TextEditingController(text: truck?['model']?.toString() ?? '');
    final brandController =
        TextEditingController(text: truck?['brand']?.toString() ?? '');
    final currentKmController = TextEditingController(
      text: truck?['current_km'] != null
          ? (truck!['current_km'] as num).toString()
          : '',
    );
    final oilChangeController = TextEditingController(
      text: truck?['oil_change_km'] != null
          ? (truck!['oil_change_km'] as num).toString()
          : '',
    );
    final locationController =
        TextEditingController(text: truck?['current_location']?.toString() ?? '');
    DateTime? purchaseDate;
    if (truck != null && truck['purchase_date'] != null) {
      purchaseDate = DateTime.tryParse(truck['purchase_date'].toString());
    }
    final emptyWeightController = TextEditingController(
      text: truck?['empty_weight']?.toString() ?? '',
    );
    final fiscalPowerController = TextEditingController(
      text: truck?['fiscal_power']?.toString() ?? '',
    );
    String status = truck?['status']?.toString() ?? 'active';
    int? defaultTrailerId =
        int.tryParse(truck?['default_trailer_id']?.toString() ?? '');
    int? defaultDriverId =
        int.tryParse(truck?['default_driver_id']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? context.tr('تعديل الشاحنة') : context.tr('إضافة شاحنة جديدة')),
          content: SingleChildScrollView(
            child: Form(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: plateController,
                    decoration: InputDecoration(labelText: context.tr('رقم اللوحة')),
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                  ),
                  TextFormField(
                    controller: brandController,
                    decoration: InputDecoration(labelText: context.tr('الماركة')),
                  ),
                   TextFormField(
                     controller: modelController,
                     decoration: InputDecoration(labelText: context.tr('الموديل')),
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
                        decoration: const InputDecoration(labelText: 'تاريخ الاقتناء'),
                        child: Text(
                          purchaseDate == null
                              ? 'اختر التاريخ'
                              : DateFormat('dd/MM/yyyy').format(purchaseDate!),
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                   ),
                   TextFormField(
                     controller: emptyWeightController,
                     keyboardType: TextInputType.number,
                     decoration: const InputDecoration(labelText: 'الوزن الفارغ'),
                   ),
                   TextFormField(
                     controller: fiscalPowerController,
                     keyboardType: TextInputType.number,
                     decoration: const InputDecoration(labelText: 'القوة الضريبية'),
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
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: context.tr('المقطورة الافتراضية'),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: DropdownButtonHideUnderline(
                             child: DropdownButtonFormField<int?>(
                               initialValue: defaultTrailerId,
                               isExpanded: true,
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('بدون مقطورة افتراضية'),
                                ),
                                ..._trailers
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
                              onChanged: (value) async {
                                if (value != null) {
                                  final trailer = _trailers.firstWhere(
                                    (t) => t['id'] == value,
                                    orElse: () => <String, dynamic>{},
                                  );
                                  if (trailer['status']?.toString() == 'inactive') {
                                    await _supabaseService.updateTrailer(value, {'status': 'active'});
                                    if (mounted) {
                                      setDialogState(() {
                                        defaultTrailerId = value;
                                      });
                                      await _loadTrailers();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('تم تفعيل المقطورة')),
                                      );
                                    }
                                  } else {
                                    setDialogState(() => defaultTrailerId = value);
                                  }
                                } else {
                                  setDialogState(() => defaultTrailerId = value);
                                }
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
                                  _loadTrailers();
                                }
                              },
                        ),
                      ],
                    ),
                  ),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: context.tr('السائق الافتراضي'),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: DropdownButtonHideUnderline(
                             child: DropdownButtonFormField<int?>(
                               initialValue: defaultDriverId,
                               isExpanded: true,
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('بدون سائق افتراضي'),
                                ),
                                ..._drivers
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
                                setDialogState(() => defaultDriverId = value);
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
                                _loadDrivers();
                              }
                            },
                        ),
                      ],
                    ),
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
                final plate = plateController.text.trim();
                if (plate.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('يرجى إدخال رقم اللوحة'))),
                  );
                  return;
                }
                final isUnique = await _supabaseService.checkTruckPlateUnique(
                  plate,
                  excludeId: isEdit ? truck['id'] as int? : null,
                );
                if (!isUnique) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('رقم اللوحة موجود مسبقاً'))),
                  );
                  return;
                }
                if (defaultTrailerId != null) {
                  final available = await _supabaseService.checkDefaultTrailerAvailable(
                    defaultTrailerId!,
                    excludeTruckId: isEdit ? truck['id'] as int? : null,
                  );
                  if (!available) {
                    if (!mounted) return;
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(context.tr('تأكيد تغيير المقطورة الافتراضية')),
                        content: Text(context.tr('المقطورة المحددة هي مقطورة افتراضية لشاحنة أخرى. هل تريد إزالتها من هناك وتعيينها هنا؟')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(context.tr('إلغاء')),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(context.tr('تأكيد')),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    
                    final clearedTruckId = await _supabaseService.reassignDefaultTrailer(
                      defaultTrailerId!,
                      excludeTruckId: isEdit ? truck['id'] as int? : null,
                    );
                    if (clearedTruckId != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr('تم إزالة المقطورة من الشاحنة #{0} وتعيينها هنا', [clearedTruckId]))),
                      );
                    }
                  }
                }
                if (defaultDriverId != null) {
                  final driverAvailable = await _supabaseService.checkDefaultDriverAvailable(
                    defaultDriverId!,
                    excludeTruckId: isEdit ? truck['id'] as int? : null,
                  );
                  if (!driverAvailable) {
                    if (!mounted) return;
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(context.tr('تأكيد تغيير السائق الافتراضي')),
                        content: Text(context.tr('السائق المحدد هو سائق افتراضي لشاحنة أخرى. هل تريد إزالته من هناك وتعيينه هنا؟')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(context.tr('إلغاء')),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(context.tr('تأكيد')),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;

                    final clearedTruckId = await _supabaseService.reassignDefaultDriver(
                      defaultDriverId!,
                      excludeTruckId: isEdit ? truck['id'] as int? : null,
                    );
                    if (clearedTruckId != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr('تم إزالة السائق من الشاحنة #{0} وتعيينه هنا', [clearedTruckId]))),
                      );
                    }
                  }
                }
                final data = {
                  'plate_number': plate,
                  'brand': brandController.text.trim(),
                  'model': modelController.text.trim(),
                  'status': status,
                  'default_trailer_id': defaultTrailerId,
                  'default_driver_id': defaultDriverId,
                  'current_km': double.tryParse(currentKmController.text.trim()) ?? 0.0,
                   'oil_change_km': double.tryParse(oilChangeController.text.trim()),
                   'current_location': locationController.text.trim(),
                   'purchase_date': purchaseDate?.toIso8601String(),
                   'empty_weight': double.tryParse(emptyWeightController.text.trim()),
                   'fiscal_power': double.tryParse(fiscalPowerController.text.trim()),
                 };
                try {
                  if (isEdit) {
                    await _supabaseService.updateTruck(truck['id'], data);
                  } else {
                    await _supabaseService.addTruck(data);
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  await _loadTrucks();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('خطأ في حفظ الشاحنة: {0}', [e]))),
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

  String _statusLabel(String? status) =>
      _statusOptions[status] ?? status ?? 'نشط';

  Map<String, dynamic>? _lastTripForTruck(int truckId) {
    final truckTrips = _trips
        .where((t) => (t['truck_id'] as num?)?.toInt() == truckId)
        .toList();
    if (truckTrips.isEmpty) return null;
    truckTrips.sort((a, b) {
      final aDate = DateTime.tryParse(a['departure_date']?.toString() ?? '') ?? DateTime(1970);
      final bDate = DateTime.tryParse(b['departure_date']?.toString() ?? '') ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });
    return truckTrips.first;
  }

  String? _formatLastTripDate(Map<String, dynamic> trip) {
    final dateStr = trip['departure_date']?.toString();
    if (dateStr == null) return null;
    final date = DateTime.tryParse(dateStr);
    if (date == null) return null;
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('الشاحنات')),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openTruckDialog(),
              tooltip: 'إضافة شاحنة',
            ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'بحث',
            onPressed: () async {
              final results = await showSearch<String>(
                context: context,
                delegate: _TruckSearchDelegate(
                  trucks: _trucks,
                  trips: _trips,
                  onSearch: (query) {
                    setState(() {
                      _searchController.text = query;
                    });
                  },
                ),
              );
              if (results != null && mounted) {
                setState(() {
                  _searchController.text = results;
                });
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatusFilterChips(),
                Expanded(
                  child: _filteredTrucks.isEmpty
                      ? Center(child: Text(context.tr('لا توجد شاحنات حالياً')))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredTrucks.length,
                          itemBuilder: (context, index) {
                            final truck = _filteredTrucks[index];
                            final subtitleParts = <String>[
                              if (truck['model']?.toString().isNotEmpty ?? false) truck['model'].toString(),
                              _statusLabel(truck['status']?.toString()),
                            ];
                            final defaultTrailerId = truck['default_trailer_id'];
                            final defaultDriverId = truck['default_driver_id'];
                            if (defaultTrailerId != null) {
                              final trailer = _trailers.firstWhere(
                                (t) => t['id'] == defaultTrailerId,
                                orElse: () => <String, dynamic>{},
                              );
                              final trailerPlate = trailer['plate']?.toString() ?? trailer['plate_number']?.toString();
                              if (trailerPlate != null && trailerPlate.isNotEmpty) {
                                subtitleParts.add('مقطورة: $trailerPlate');
                              }
                            }
                            if (defaultDriverId != null) {
                              final driver = _drivers.firstWhere(
                                (d) => d['id'] == defaultDriverId,
                                orElse: () => <String, dynamic>{},
                              );
                              final driverName = driver['name']?.toString();
                              if (driverName != null && driverName.isNotEmpty) {
                                subtitleParts.add('سائق: $driverName');
                              }
                            }
                            if (truck['current_location'] != null && truck['current_location'].toString().isNotEmpty) {
                              subtitleParts.add(truck['current_location'].toString());
                            }
                            final lastTrip = _lastTripForTruck(truck['id'] as int);
                            if (lastTrip != null) {
                              final formatted = _formatLastTripDate(lastTrip);
                              if (formatted != null) {
                                subtitleParts.add('آخر رحلة: $formatted');
                              }
                            }
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TruckDetailsScreen(
                                        truck: truck,
                                        onDeleted: _loadTrucks,
                                        onUpdated: _loadTrucks,
                                      ),
                                    ),
                                  );
                                },
                                child: ListTile(
                                  leading: const Icon(Icons.local_shipping, color: Colors.blue),
                                   title: Text(truck['plate']?.toString() ?? truck['plate_number']?.toString() ?? context.tr('بدون لوحة'), textDirection: TextDirection.ltr, textAlign: TextAlign.left),
                                  subtitle: Text(subtitleParts.join(' • ')),
                                  trailing: widget.isAdmin
                                      ? IconButton(
                                          icon: const Icon(Icons.edit, size: 20),
                                          onPressed: () => _openTruckDialog(truck: truck),
                                        )
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _TruckSearchDelegate extends SearchDelegate<String> {
  final List<Map<String, dynamic>> trucks;
  final List<Map<String, dynamic>> trips;
  final void Function(String) onSearch;

  _TruckSearchDelegate({required this.trucks, required this.trips, required this.onSearch});

  static String _statusLabel(String? status) {
    const options = {
      'active': 'نشط',
      'maintenance': 'صيانة',
      'inactive': 'غير نشط',
    };
    return options[status] ?? status ?? 'نشط';
  }

  Map<String, dynamic>? _lastTripForTruck(int truckId) {
    final truckTrips = trips
        .where((t) => (t['truck_id'] as num?)?.toInt() == truckId)
        .toList();
    if (truckTrips.isEmpty) return null;
    truckTrips.sort((a, b) {
      final aDate = DateTime.tryParse(a['departure_date']?.toString() ?? '') ?? DateTime(1970);
      final bDate = DateTime.tryParse(b['departure_date']?.toString() ?? '') ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });
    return truckTrips.first;
  }

  String? _formatLastTripDate(Map<String, dynamic> trip) {
    final dateStr = trip['departure_date']?.toString();
    if (dateStr == null) return null;
    final date = DateTime.tryParse(dateStr);
    if (date == null) return null;
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));
  }

  @override
  Widget buildResults(BuildContext context) {
    onSearch(query);
    close(context, query);
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final filtered = trucks.where((truck) {
      final plate = (truck['plate']?.toString() ?? truck['plate_number']?.toString() ?? '').toLowerCase();
      final model = truck['model']?.toString().toLowerCase() ?? '';
      final status = truck['status']?.toString().toLowerCase() ?? '';
      final location = truck['current_location']?.toString().toLowerCase() ?? '';
      return plate.contains(query.toLowerCase()) ||
          model.contains(query.toLowerCase()) ||
          status.contains(query.toLowerCase()) ||
          location.contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final truck = filtered[index];
        final lastTrip = _lastTripForTruck(truck['id'] as int);
        final lastTripDate = lastTrip != null ? _formatLastTripDate(lastTrip) : '';
        return ListTile(
           title: Text(truck['plate']?.toString() ?? truck['plate_number']?.toString() ?? 'بدون لوحة', textDirection: TextDirection.ltr, textAlign: TextAlign.left),
           subtitle: Text('${truck['model']?.toString() ?? ''} • ${_TruckSearchDelegate._statusLabel(truck['status']?.toString())}${(lastTripDate ?? '').isNotEmpty ? " • آخر رحلة: $lastTripDate" : ""}'),
           onTap: () {
            query = truck['plate']?.toString() ?? truck['plate_number']?.toString() ?? '';
            buildResults(context);
          },
        );
      },
    );
  }
}
