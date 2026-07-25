import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../services/supabase_service.dart';
import '../l10n/app_localizations.dart';
import 'driver_trips_screen.dart';
import 'driver_advances_screen.dart';

// ignore_for_file: use_build_context_synchronously

class DriverDetailsScreen extends StatefulWidget {
  const DriverDetailsScreen({
    super.key,
    required this.driver,
    required this.onDeleted,
    required this.onUpdated,
  });

  final Map<String, dynamic> driver;
  final VoidCallback onDeleted;
  final VoidCallback onUpdated;

  @override
  State<DriverDetailsScreen> createState() => _DriverDetailsScreenState();
}

class _DriverDetailsScreenState extends State<DriverDetailsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isDeleting = false;
  int _tripCount = 0;
  int _advanceCount = 0;
  List<Map<String, dynamic>> _trucks = [];

  @override
  void initState() {
    super.initState();
    _checkLinkedRecords();
    _loadTrucks();
  }

  Future<void> _loadTrucks() async {
    final trucks = await _supabaseService.getTrucks();
    if (mounted) {
      setState(() => _trucks = trucks);
    }
  }

  Future<void> _checkLinkedRecords() async {
    final driverId = widget.driver['id'] as int?;
    if (driverId == null) return;

    final trips = await _supabaseService.getTripOrders();
    final advances = await _supabaseService.getAdvances();

    final driverTrips = trips.where((t) => t['driver_id'] == driverId).toList();
    final driverAdvances = advances.where((a) => a['driver_id'] == driverId).toList();

    if (mounted) {
      setState(() {
        _tripCount = driverTrips.length;
        _advanceCount = driverAdvances.length;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final inUse = await _supabaseService.isDriverInUse(widget.driver['id'] as int);
    if (inUse) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('تأكيد الحذف')),
          content: Text(context.tr('لا يمكن حذف السائق لأنه مرتبط ببيانات أخرى')),
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
        title: Text(context.tr('حذف السائق')),
        content: Text(context.tr('سيتم حذف هذا السائق نهائياً')),
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
      await _supabaseService.deleteDriver(widget.driver['id'] as int);
      if (!mounted) return;
      widget.onDeleted();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('تم حذف السائق بنجاح'))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('خطأ في حذف السائق: {0}', [e]))),
      );
    }
  }

  Future<void> _openEditDialog() async {
    final nameController = TextEditingController(text: widget.driver['name']?.toString() ?? '');
    final phoneController = TextEditingController(text: widget.driver['phone']?.toString() ?? '');
    final licenseController = TextEditingController(text: widget.driver['license']?.toString() ?? '');
    final baseSalaryController = TextEditingController(
      text: widget.driver['base_salary'] != null
          ? (widget.driver['base_salary'] as num).toString()
          : '',
    );
    final bonusController = TextEditingController(
      text: widget.driver['bonus_percentage'] != null
          ? (widget.driver['bonus_percentage'] as num).toString()
          : '',
    );
    String status = widget.driver['status']?.toString() ?? 'active';
    String? defaultTruckId = widget.driver['default_truck_id']?.toString();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('تعديل السائق')),
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
                        .toList()
                        .sorted((a, b) {
                          final aPlate = (a['plate']?.toString() ?? a['plate_number']?.toString() ?? '').toLowerCase();
                          final bPlate = (b['plate']?.toString() ?? b['plate_number']?.toString() ?? '').toLowerCase();
                          return aPlate.compareTo(bPlate);
                        })
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
                final data = {
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'license': licenseController.text.trim(),
                  'status': status,
                  'base_salary': double.tryParse(baseSalaryController.text.trim()) ?? 0.0,
                  'bonus_percentage': double.tryParse(bonusController.text.trim()) ?? 0.0,
                  'default_truck_id': defaultTruckId,
                };
                await _supabaseService.updateDriver(
                  widget.driver['id'] as int,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = widget.driver['name']?.toString() ?? context.tr('بدون اسم');
    final phone = widget.driver['phone']?.toString() ?? '';
    final license = widget.driver['license']?.toString() ?? '';
    final status = widget.driver['status']?.toString() ?? 'active';
    final baseSalary = (widget.driver['base_salary'] as num?)?.toDouble() ?? 0.0;
    final bonus = (widget.driver['bonus_percentage'] as num?)?.toDouble() ?? 0.0;
    final defaultTruckId = widget.driver['default_truck_id']?.toString();

    String truckLabel = context.tr('بدون شاحنة');
    if (defaultTruckId != null) {
      final truck = _trucks.firstWhere(
        (t) => t['id']?.toString() == defaultTruckId,
        orElse: () => <String, dynamic>{},
      );
      if (truck.isNotEmpty) {
        truckLabel = truck['plate']?.toString() ?? truck['plate_number']?.toString() ?? context.tr('بدون لوحة');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('تفاصيل السائق')),
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
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(context.tr('الاسم'), name),
                        const SizedBox(height: 12),
                        _buildInfoRow(context.tr('الهاتف'), phone),
                        const SizedBox(height: 12),
                        _buildInfoRow(context.tr('رقم الرخصة'), license),
                        const SizedBox(height: 12),
                        _buildInfoRow(context.tr('الحالة'), status == 'active' ? context.tr('نشط') : context.tr('غير نشط')),
                        const SizedBox(height: 12),
                        _buildInfoRow(context.tr('الراتب الأساسي'), '$baseSalary DH'),
                        const SizedBox(height: 12),
                        _buildInfoRow(context.tr('نسبة المكافأة (%)'), '$bonus %'),
                        const SizedBox(height: 12),
                        _buildInfoRow(context.tr('الشاحنة الافتراضية'), truckLabel),
                      ],
                    ),
                  ),
                ),
                 const SizedBox(height: 20),
                 Column(
                   children: [
                     Card(
                       color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                       shape: RoundedRectangleBorder(
                         borderRadius: BorderRadius.circular(12),
                         side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
                       ),
                       child: InkWell(
                         borderRadius: BorderRadius.circular(12),
                         onTap: () {
                           Navigator.push(
                             context,
                             MaterialPageRoute(
                               builder: (_) => DriverTripsScreen(
                                 isAdmin: true,
                                 driverId: widget.driver['id'] as int,
                               ),
                             ),
                           );
                         },
                         child: ListTile(
                           leading: Icon(Icons.local_shipping_rounded, color: Colors.blue.shade700, size: 28),
                           title: Text('رحلات', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                           subtitle: Text('$_tripCount رحلة مسجلة'),
                           trailing: Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                 decoration: BoxDecoration(
                                   color: Colors.blue.withValues(alpha: 0.1),
                                   borderRadius: BorderRadius.circular(12),
                                 ),
                                 child: Text('$_tripCount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                               ),
                               const SizedBox(width: 4),
                               Icon(Icons.chevron_left_rounded, color: Colors.grey.shade600),
                             ],
                           ),
                         ),
                       ),
                     ),
                     const SizedBox(height: 10),
                     Card(
                       color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                       shape: RoundedRectangleBorder(
                         borderRadius: BorderRadius.circular(12),
                         side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
                       ),
                       child: InkWell(
                         borderRadius: BorderRadius.circular(12),
                         onTap: () {
                           Navigator.push(
                             context,
                             MaterialPageRoute(
                               builder: (_) => DriverAdvancesScreen(
                                 isAdmin: true,
                                 driverId: widget.driver['id'] as int,
                               ),
                             ),
                           );
                         },
                         child: ListTile(
                           leading: Icon(Icons.account_balance_wallet_rounded, color: Colors.teal.shade700, size: 28),
                           title: Text('عهد', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                           subtitle: Text('$_advanceCount عهدة مسجلة'),
                           trailing: Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                 decoration: BoxDecoration(
                                   color: Colors.teal.withValues(alpha: 0.1),
                                   borderRadius: BorderRadius.circular(12),
                                 ),
                                 child: Text('$_advanceCount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
                               ),
                               const SizedBox(width: 4),
                               Icon(Icons.chevron_left_rounded, color: Colors.grey.shade600),
                             ],
                           ),
                         ),
                       ),
                     ),
                   ],
                 ),
              ],
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
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
}
