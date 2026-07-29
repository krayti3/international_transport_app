import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:collection/collection.dart';
import '../services/supabase_service.dart';
import '../widgets/date_wheel_picker.dart';

// ignore_for_file: use_build_context_synchronously

class DriverTripsScreen extends StatefulWidget {
  final bool isAdmin;
  final int driverId;

  const DriverTripsScreen({super.key, required this.isAdmin, required this.driverId});

  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _trips = [];
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _trucks = [];
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = true;

  static const kPending = 'قيد الانتظار';
  static const kActive = 'قيد التنفيذ';
  static const kCompleted = 'مكتملة';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final trips = await _supabaseService.getTripOrdersByDriver(widget.driverId);
    final clients = await _supabaseService.getClients();
    final trucks = await _supabaseService.getTrucks();
    final drivers = await _supabaseService.getDrivers();
    if (!mounted) return;
    trips.sort((a, b) {
      final ai = (a['id'] as int?) ?? 0;
      final bi = (b['id'] as int?) ?? 0;
      return bi.compareTo(ai);
    });
    setState(() {
      _trips = trips;
      _clients = clients.map((c) => c.toMap()).toList();
      _trucks = trucks;
      _drivers = drivers;
      _isLoading = false;
    });
  }

  String _driverName(dynamic driverId) {
    final d = _drivers.firstWhere(
      (e) => e['id']?.toString() == driverId?.toString(),
      orElse: () => <String, dynamic>{},
    );
    return d['name']?.toString() ?? '—';
  }

  String _clientName(dynamic clientId) {
    final c = _clients.firstWhere(
      (e) => e['id']?.toString() == clientId?.toString(),
      orElse: () => <String, dynamic>{},
    );
    return c['name']?.toString() ?? 'غير محدد';
  }

  String _truckPlate(dynamic truckId) {
    final t = _trucks.firstWhere(
      (e) => e['id']?.toString() == truckId?.toString(),
      orElse: () => <String, dynamic>{},
    );
    return t['plate']?.toString() ?? t['plate_number']?.toString() ?? '—';
  }

  double _priceOf(Map<String, dynamic> order) =>
      (order['price'] as num?)?.toDouble() ?? 0.0;

  Color _statusColor(String? status) {
    switch (status) {
      case 'قيد التنفيذ':
        return Colors.orange;
      case 'مكتملة':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _openTripDialog({Map<String, dynamic>? trip}) async {
    final isEdit = trip != null;
    String? clientId = isEdit ? trip['client_id']?.toString() : null;
    String? truckId = isEdit ? trip['truck_id']?.toString() : null;
    String status = isEdit ? (trip['status']?.toString() ?? kActive) : kActive;
    final routeController = TextEditingController(text: trip?['route']?.toString() ?? '');
    final priceController = TextEditingController(text: trip?['price']?.toString() ?? '');
    final dateController = TextEditingController(text: trip?['departure_date']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'تعديل الرحلة' : 'تسجيل رحلة جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'الزبون / الشركة الطالبة'),
                  initialValue: clientId,
                  items: _clients
                      .toList()
                      .sorted((a, b) => (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''))
                      .map((c) => DropdownMenuItem(
                            value: c['id']?.toString(),
                            child: Text(c['name']?.toString() ?? 'بدون اسم'),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => clientId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'الشاحنة'),
                  initialValue: truckId,
                  items: _trucks
                      .toList()
                      .sorted((a, b) {
                        final aPlate = (a['plate']?.toString() ?? a['plate_number']?.toString() ?? '').toLowerCase();
                        final bPlate = (b['plate']?.toString() ?? b['plate_number']?.toString() ?? '').toLowerCase();
                        return aPlate.compareTo(bPlate);
                      })
                      .map((t) => DropdownMenuItem(
                            value: t['id']?.toString(),
                            child: Text(t['plate']?.toString() ?? t['plate_number']?.toString() ?? 'بدون لوحة'),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => truckId = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: routeController,
                  decoration: const InputDecoration(labelText: 'مسار الرحلة (من - إلى)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'أجرة الشحن المتفق عليها'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: dateController,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'تاريخ الانطلاق'),
                  readOnly: true,
                  onTap: () async {
                    final picked = await showDateWheelPicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                     if (picked != null) {
                       setDialogState(() => dateController.text = DateFormat('dd/MM/yyyy').format(picked));
                     }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'حالة الرحلة'),
                  initialValue: status,
                  items: const [
                    DropdownMenuItem(value: kPending, child: Text('قيد الانتظار (جديد)')),
                    DropdownMenuItem(value: kActive, child: Text('قيد التنفيذ (في الطريق)')),
                    DropdownMenuItem(value: kCompleted, child: Text('مكتملة (تم التفريغ)')),
                  ],
                  onChanged: (v) => setDialogState(() => status = v ?? status),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (clientId == null || routeController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى اختيار الزبون وإدخال المسار')),
                  );
                  return;
                }
                final data = {
                  'client_id': int.tryParse(clientId!),
                  'driver_id': widget.driverId,
                  'truck_id': truckId != null ? int.tryParse(truckId!) : null,
                  'route': routeController.text.trim(),
                  'price': double.tryParse(priceController.text.trim()) ?? 0,
                  'departure_date': dateController.text.trim(),
                  'status': status,
                };
                try {
                  if (isEdit) {
                    await _supabaseService.updateTripOrder(trip['id'] as int, data, localRow: trip);
                  } else {
                    await _supabaseService.addTripOrder(data);
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? 'تم تحديث الرحلة' : 'تم تسجيل الرحلة بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ في حفظ الرحلة: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text(isEdit ? 'حفظ' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeStatus(Map<String, dynamic> trip) async {
    final current = trip['status']?.toString() ?? kActive;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('تحديث حالة الرحلة'),
        children: [
          for (final s in const [kPending, kActive, kCompleted])
            ListTile(
              leading: Icon(
                s == current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: s == current ? Colors.teal : Colors.grey,
              ),
              title: Text(s),
              onTap: () => Navigator.pop(context, s),
            ),
        ],
      ),
    );
    if (selected == null || selected == current) return;
    try {
      await _supabaseService.updateTripOrder(trip['id'] as int, {'status': selected}, localRow: trip);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحديث الحالة إلى: $selected'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحديث الحالة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> trip) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الرحلة'),
        content: const Text('هل أنت متأكد من حذف هذه الرحلة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _supabaseService.deleteTripOrder(trip['id'] as int);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الرحلة')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = _trips.length;
    final completed = _trips.where((t) => (t['status']?.toString() ?? '') == kCompleted).length;
    final active = total - completed;
    final totalValue = _trips.fold<double>(0, (sum, t) => sum + _priceOf(t));
    final isSmall = MediaQuery.of(context).size.width < 400;

    return Scaffold(
      appBar: AppBar(
        title: Text('رحلات ${_driverName(widget.driverId)}'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(isSmall ? 12 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildStatCard('رحلات نشطة', '$active', Icons.local_shipping_rounded, Colors.orange, isDark, isSmall: isSmall),
                      SizedBox(width: isSmall ? 8 : 12),
                      _buildStatCard('الإجمالي', '$total', Icons.analytics_rounded, Colors.blue, isDark, isSmall: isSmall),
                      SizedBox(width: isSmall ? 8 : 12),
                      _buildStatCard('الإجمالي DH', NumberFormat('#,###').format(totalValue), Icons.payments_rounded, Colors.teal, isDark, isSmall: isSmall),
                    ],
                  ),
                  SizedBox(height: isSmall ? 14 : 20),
                  Expanded(
                    child: _trips.isEmpty
                        ? Center(child: Text('لا توجد رحلات مسجلة', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: isSmall ? 14 : null)))
                        : ListView.builder(
                            itemCount: _trips.length,
                            itemBuilder: (context, index) => _buildTripCard(_trips[index], isDark, isSmall: isSmall),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openTripDialog(),
              icon: Icon(Icons.add_road_rounded, size: isSmall ? 20 : 22),
              label: Text('تسجيل رحلة', style: TextStyle(fontSize: isSmall ? 14 : 16)),
            )
          : null,
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark, {bool isSmall = false}) {
    final iconSize = isSmall ? 18.0 : 20.0;
    final valueFont = isSmall ? 18.0 : 20.0;
    final labelFont = isSmall ? 11.0 : 12.0;
    final padding = isSmall ? 10.0 : 14.0;

    return Expanded(
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
          borderRadius: BorderRadius.circular(isSmall ? 10 : 12),
          border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: iconSize),
            SizedBox(height: isSmall ? 6 : 8),
            Text(value, style: TextStyle(fontSize: valueFont, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            Text(label, style: TextStyle(fontSize: labelFont, color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> order, bool isDark, {bool isSmall = false}) {
    final status = order['status']?.toString() ?? kActive;
    final price = _priceOf(order);
    final date = order['departure_date']?.toString() ?? '';
    final padding = isSmall ? 12.0 : 14.0;
    final titleFont = isSmall ? 14.0 : 15.0;
    final statusFont = isSmall ? 11.0 : 12.0;
    final subFont = isSmall ? 12.0 : 13.0;
    final iconSize = isSmall ? 13.0 : 14.0;

    return Card(
      margin: EdgeInsets.symmetric(vertical: isSmall ? 4 : 6),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmall ? 10 : 12),
        side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order['route']?.toString() ?? 'مسار غير محدد',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: titleFont),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 10, vertical: isSmall ? 3 : 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(isSmall ? 6 : 8),
                  ),
                  child: Text(status, style: TextStyle(fontSize: statusFont, color: _statusColor(status), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            SizedBox(height: isSmall ? 8 : 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الزبون', style: TextStyle(fontSize: subFont - 1, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                      Text(_clientName(order['client_id']), style: TextStyle(fontWeight: FontWeight.w600, fontSize: subFont - 1)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الأجرة', style: TextStyle(fontSize: subFont - 1, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                      Text('${price.toStringAsFixed(2)} DH', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: subFont - 1)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmall ? 6 : 8),
            Row(
              children: [
                Icon(Icons.local_shipping, size: iconSize, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                SizedBox(width: isSmall ? 3 : 4),
                Text(_truckPlate(order['truck_id']), style: TextStyle(fontSize: subFont - 1, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                if (date.isNotEmpty) ...[
                  SizedBox(width: isSmall ? 12 : 16),
                  Icon(Icons.event, size: iconSize, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  SizedBox(width: isSmall ? 3 : 4),
                  Text(date, style: TextStyle(fontSize: subFont - 1, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                ],
              ],
            ),
            if (widget.isAdmin) ...[
              SizedBox(height: isSmall ? 8 : 10),
              const Divider(height: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _changeStatus(order),
                    icon: Icon(Icons.refresh, size: iconSize),
                    label: const Text('الحالة'),
                  ),
                  TextButton.icon(
                    onPressed: () => _openTripDialog(trip: order),
                    icon: Icon(Icons.edit, size: iconSize),
                    label: const Text('تعديل'),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmDelete(order),
                    icon: Icon(Icons.delete, size: iconSize, color: Colors.red),
                    label: const Text('حذف', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
