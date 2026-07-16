import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../l10n/app_localizations.dart';
import 'driver_details_screen.dart';

// ignore_for_file: use_build_context_synchronously

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _filteredDrivers = [];
  List<Map<String, dynamic>> _trucks = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  static const _statusOptions = {
    'active': 'نشط',
    'inactive': 'غير نشط',
  };

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _loadTrucks();
    _searchController.addListener(_filterDrivers);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterDrivers);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoading = true);
    final drivers = await _supabaseService.getDrivers();
    setState(() {
      _drivers = drivers;
      _filteredDrivers = drivers;
      _isLoading = false;
    });
  }

  Future<void> _loadTrucks() async {
    try {
      final trucks = await _supabaseService.getTrucks();
      if (mounted) setState(() => _trucks = trucks);
    } catch (e) {
      debugPrint('Error loading trucks: $e');
    }
  }

  void _filterDrivers() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredDrivers = _drivers);
      return;
    }

    setState(() {
      _filteredDrivers = _drivers.where((driver) {
        final name = driver['name']?.toString().toLowerCase() ?? '';
        final phone = driver['phone']?.toString().toLowerCase() ?? '';
        final license = driver['license']?.toString().toLowerCase() ?? '';
        final status = driver['status']?.toString().toLowerCase() ?? '';
        return name.contains(query) ||
            phone.contains(query) ||
            license.contains(query) ||
            status.contains(query);
      }).toList();
    });
  }

  Future<void> _openDriverDialog({Map<String, dynamic>? driver}) async {
    final isEdit = driver != null;
    final nameController =
        TextEditingController(text: driver?['name']?.toString() ?? '');
    final phoneController =
        TextEditingController(text: driver?['phone']?.toString() ?? '');
    final licenseController =
        TextEditingController(text: driver?['license']?.toString() ?? '');
    final baseSalaryController = TextEditingController(
      text: driver?['base_salary'] != null
          ? (driver!['base_salary'] as num).toString()
          : '',
    );
    final bonusController = TextEditingController(
      text: driver?['bonus_percentage'] != null
          ? (driver!['bonus_percentage'] as num).toString()
          : '',
    );
    String status = driver?['status']?.toString() ?? 'active';
    String? defaultTruckId = driver?['default_truck_id']?.toString();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? context.tr('تعديل السائق') : context.tr('إضافة سائق جديد')),
          content: SingleChildScrollView(
            child: Form(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: context.tr('الاسم')),
                  ),
                  TextFormField(
                    controller: phoneController,
                    decoration: InputDecoration(labelText: context.tr('الهاتف')),
                    keyboardType: TextInputType.phone,
                  ),
                  TextFormField(
                    controller: licenseController,
                    decoration: InputDecoration(labelText: context.tr('رقم الرخصة')),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: InputDecoration(labelText: context.tr('الحالة')),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('نشط')),
                      DropdownMenuItem(value: 'inactive', child: Text('غير نشط')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => status = value);
                    },
                  ),
                  TextFormField(
                    controller: baseSalaryController,
                    decoration: InputDecoration(labelText: context.tr('الراتب الأساسي')),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: bonusController,
                    decoration: InputDecoration(labelText: context.tr('نسبة المكافأة (%)')),
                    keyboardType: TextInputType.number,
                  ),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: context.tr('الشاحنة الافتراضية')),
                    initialValue: defaultTruckId,
                    items: _trucks
                        .map((t) => DropdownMenuItem(
                              value: t['id']?.toString(),
                              child: Text(t['plate']?.toString() ?? t['plate_number']?.toString() ?? context.tr('بدون لوحة')),
                            ))
                        .toList(),
                    onChanged: (value) => setDialogState(() => defaultTruckId = value),
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
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('يرجى إدخال اسم السائق'))),
                  );
                  return;
                }
                final data = {
                  'name': name,
                  'phone': phoneController.text.trim(),
                  'license': licenseController.text.trim(),
                  'status': status,
                  'base_salary': double.tryParse(baseSalaryController.text.trim()) ?? 0.0,
                  'bonus_percentage': double.tryParse(bonusController.text.trim()) ?? 0.0,
                  'default_truck_id': defaultTruckId,
                };
                try {
                  if (isEdit) {
                    await _supabaseService.updateDriver(driver['id'], data);
                  } else {
                    await _supabaseService.addDriver(data);
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  await _loadDrivers();
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
  }

  String _statusLabel(String? status) =>
      _statusOptions[status] ?? status ?? 'نشط';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('السائقين')),
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
                  child: _filteredDrivers.isEmpty
                      ? Center(child: Text(context.tr('لا يوجد سائقين حالياً')))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredDrivers.length,
                          itemBuilder: (context, index) {
                            final driver = _filteredDrivers[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DriverDetailsScreen(
                                        driver: driver,
                                        onDeleted: _loadDrivers,
                                        onUpdated: _loadDrivers,
                                      ),
                                    ),
                                  );
                                },
                                child: ListTile(
                                  leading: const Icon(Icons.person, color: Colors.blue),
                                  title: Text(driver['name'] ?? context.tr('بدون اسم')),
                                  subtitle: Text(
                                    '${driver['phone'] ?? ''} • ${_statusLabel(driver['status']?.toString())}',
                                  ),
                                  trailing: widget.isAdmin
                                      ? IconButton(
                                          icon: const Icon(Icons.edit, size: 20),
                                          onPressed: () => _openDriverDialog(driver: driver),
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
              onPressed: () => _openDriverDialog(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
