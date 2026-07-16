import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../l10n/app_localizations.dart';
import 'truck_details_screen.dart';

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
  List<Map<String, dynamic>> _filteredTrucks = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

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
    setState(() {
      _trucks = trucks;
      _filteredTrucks = trucks;
      _isLoading = false;
    });
  }

  void _filterTrucks() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredTrucks = _trucks);
      return;
    }

    setState(() {
      _filteredTrucks = _trucks.where((truck) {
        final plate = (truck['plate']?.toString() ?? truck['plate_number']?.toString() ?? '').toLowerCase();
        final model = truck['model']?.toString().toLowerCase() ?? '';
        final status = truck['status']?.toString().toLowerCase() ?? '';
        final location = truck['current_location']?.toString().toLowerCase() ?? '';
        return plate.contains(query) ||
            model.contains(query) ||
            status.contains(query) ||
            location.contains(query);
      }).toList();
    });
  }

  Future<void> _openTruckDialog({Map<String, dynamic>? truck}) async {
    final isEdit = truck != null;
    final plateController =
        TextEditingController(text: truck?['plate']?.toString() ?? '');
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
    String status = truck?['status']?.toString() ?? 'active';

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
                final data = {
                  'plate': plate,
                  'brand': brandController.text.trim(),
                  'model': modelController.text.trim(),
                  'status': status,
                  'current_km': double.tryParse(currentKmController.text.trim()) ?? 0.0,
                  'oil_change_km': double.tryParse(oilChangeController.text.trim()),
                  'current_location': locationController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('الشاحنات والمقطورات')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.tr('بحث...'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                  ),
                ),
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
                            if (truck['current_location'] != null && truck['current_location'].toString().isNotEmpty) {
                              subtitleParts.add(truck['current_location'].toString());
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
                                   title: Text(truck['plate']?.toString() ?? truck['plate_number']?.toString() ?? context.tr('بدون لوحة')),
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
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton(
              onPressed: () => _openTruckDialog(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
