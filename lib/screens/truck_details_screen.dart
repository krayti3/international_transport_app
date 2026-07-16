import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../l10n/app_localizations.dart';
import 'truck_documents_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _checkLinkedRecords();
  }

  Future<void> _checkLinkedRecords() async {
    final truckId = widget.truck['id'] as int?;
    if (truckId == null) return;

    final trips = await _supabaseService.getTripOrders();
    final maintenances = await _supabaseService.getTruckMaintenances();
    final documents = await _supabaseService.getDocuments();

    final truckTrips = trips.where((t) => t['truck_id'] == truckId).toList();
    final truckMaintenances = maintenances.where((m) => m['truck_id'] == truckId).toList();
    final truckDocuments = documents.where((d) => d['vehicle_type'] == 'truck' && d['vehicle_id'] == truckId).toList();

    if (mounted) {
      setState(() {
        _tripCount = truckTrips.length;
        _maintenanceCount = truckMaintenances.length;
        _documentCount = truckDocuments.length;
        _hasLinkedRecords = _tripCount > 0 || _maintenanceCount > 0 || _documentCount > 0;
      });
    }
  }

  Future<void> _confirmDelete() async {
    if (_hasLinkedRecords) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('تأكيد الحذف')),
          content: Text(context.tr('لا يمكن حذف الشاحنة لوجود رحلات أو صيانة مرتبطة')),
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

  Future<void> _openEditDialog() async {
    final plateController = TextEditingController(text: widget.truck['plate']?.toString() ?? '');
    final modelController = TextEditingController(text: widget.truck['model']?.toString() ?? '');
    final brandController = TextEditingController(text: widget.truck['brand']?.toString() ?? '');
    final currentKmController = TextEditingController(
      text: widget.truck['current_km'] != null
          ? (widget.truck['current_km'] as num).toString()
          : '',
    );
    final oilChangeController = TextEditingController(
      text: widget.truck['oil_change_km'] != null
          ? (widget.truck['oil_change_km'] as num).toString()
          : '',
    );
    final locationController = TextEditingController(text: widget.truck['current_location']?.toString() ?? '');
    String status = widget.truck['status']?.toString() ?? 'active';

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
                  'plate': plateController.text.trim(),
                  'brand': brandController.text.trim(),
                  'model': modelController.text.trim(),
                  'status': status,
                  'current_km': double.tryParse(currentKmController.text.trim()) ?? 0.0,
                  'oil_change_km': double.tryParse(oilChangeController.text.trim()),
                  'current_location': locationController.text.trim(),
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
