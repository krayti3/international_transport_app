import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../l10n/app_localizations.dart';
import 'fleet_docs_screen.dart';
import 'trailer_maintenance_screen.dart';

// ignore_for_file: use_build_context_synchronously

class TrailerDetailsScreen extends StatefulWidget {
  const TrailerDetailsScreen({
    super.key,
    required this.trailer,
    required this.onDeleted,
    required this.onUpdated,
  });

  final Map<String, dynamic> trailer;
  final VoidCallback onDeleted;
  final VoidCallback onUpdated;

  @override
  State<TrailerDetailsScreen> createState() => _TrailerDetailsScreenState();
}

class _TrailerDetailsScreenState extends State<TrailerDetailsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isDeleting = false;
  bool _hasLinkedRecords = false;
  int _tripCount = 0;
  int _maintenanceCount = 0;
  int _documentCount = 0;
  List<Map<String, dynamic>> _allTrucks = [];

  @override
  void initState() {
    super.initState();
    _checkLinkedRecords();
    _loadTrucks();
  }

  Future<void> _checkLinkedRecords() async {
    final trailerId = widget.trailer['id'] as int?;
    if (trailerId == null) return;

    final trips = await _supabaseService.getTripOrders();
    final maintenances = await _supabaseService.getTrailerMaintenances();
    final documents = await _supabaseService.getFleetDocuments();

    final associatedTruckIds = _allTrucks
        .where((t) => t['default_trailer_id'] == trailerId)
        .map((t) => t['id'] as int)
        .toList();

    final trailerTrips = trips.where((t) => associatedTruckIds.contains(t['truck_id'] as int?)).toList();
    final trailerMaintenances = maintenances.where((m) => m['trailer_id'] == trailerId).toList();
    final trailerDocuments = documents.where((d) => d['entity_type'] == 'trailer' && d['entity_id'] == trailerId).toList();

    if (mounted) {
      setState(() {
        _tripCount = trailerTrips.length;
        _maintenanceCount = trailerMaintenances.length;
        _documentCount = trailerDocuments.length;
        _hasLinkedRecords = _tripCount > 0 || _maintenanceCount > 0 || _documentCount > 0;
      });
    }
  }

  Future<void> _loadTrucks() async {
    try {
      final trucks = await _supabaseService.getTrucks();
      if (mounted) {
        setState(() {
          _allTrucks = trucks;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allTrucks = [];
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    final inUse = await _supabaseService.isTrailerInUse(widget.trailer['id'] as int);
    if (inUse) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('تأكيد الحذف')),
          content: Text(context.tr('لا يمكن حذف المقطورة لأنها مرتبطة ببيانات أخرى')),
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
        title: Text(context.tr('حذف المقطورة')),
        content: Text(context.tr('سيتم حذف هذه المقطورة نهائياً')),
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
      await _supabaseService.deleteTrailer(widget.trailer['id'] as int);
      if (!mounted) return;
      widget.onDeleted();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('تم حذف المقطورة بنجاح'))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('خطأ في حذف المقطورة: {0}', [e]))),
      );
    }
  }

  Future<void> _openEditDialog() async {
    final plateController = TextEditingController(text: widget.trailer['plate_number']?.toString() ?? widget.trailer['plate']?.toString() ?? '');
    final typeController = TextEditingController(text: widget.trailer['type']?.toString() ?? '');
    String status = widget.trailer['status']?.toString() ?? 'active';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('تعديل المقطورة')),
          content: SingleChildScrollView(
            child: Form(
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
                      if (value != null) setDialogState(() => status = value);
                    },
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
                final isUnique = await _supabaseService.checkTrailerPlateUnique(
                  plateController.text.trim(),
                  excludeId: widget.trailer['id'] as int?,
                );
                if (!isUnique) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('رقم اللوحة موجود مسبقاً'))),
                  );
                  return;
                }
                final data = {
                  'plate_number': plateController.text.trim(),
                  'type': typeController.text.trim(),
                  'status': status,
                };
                await _supabaseService.updateTrailer(
                  widget.trailer['id'] as int,
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
    final trailerId = widget.trailer['id'] as int?;
    if (trailerId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FleetDocsScreen(
          isAdmin: true,
          trailerId: trailerId,
        ),
      ),
    );
  }

  void _openMaintenanceScreen() {
    final trailerId = widget.trailer['id'] as int?;
    if (trailerId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrailerMaintenanceScreen(
          isAdmin: true,
          trailerId: trailerId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plate = widget.trailer['plate']?.toString() ?? widget.trailer['plate_number']?.toString() ?? context.tr('بدون لوحة');
    final type = widget.trailer['type']?.toString() ?? '';
    final status = widget.trailer['status']?.toString() ?? 'active';

    final associatedTruck = _allTrucks.firstWhere(
      (t) => t['default_trailer_id'] == widget.trailer['id'],
      orElse: () => <String, dynamic>{},
    );
    final associatedTruckPlate = associatedTruck.isNotEmpty
        ? (associatedTruck['plate']?.toString() ?? associatedTruck['plate_number']?.toString() ?? '')
        : null;

    String statusLabel = context.tr('نشط');
    if (status == 'maintenance') statusLabel = context.tr('صيانة');
    if (status == 'inactive') statusLabel = context.tr('غير نشط');

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('تفاصيل المقطورة')),
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
                        _buildInfoRow(context.tr('رقم اللوحة'), plate, isDark, textDirection: TextDirection.ltr),
                        const SizedBox(height: 12),
                        _buildInfoRow(context.tr('النوع'), type, isDark),
                        const SizedBox(height: 12),
                        _buildInfoRow(context.tr('الحالة'), statusLabel, isDark),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          context.tr('الشاحنة المرتبطة'),
                          associatedTruckPlate != null && associatedTruckPlate.isNotEmpty
                              ? associatedTruckPlate
                              : context.tr('بدون شاحنة مرتبطة'),
                          isDark,
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  color: isDark ? const Color(0xFF1E1E1E) : null,
                  child: ListTile(
                    leading: const Icon(Icons.description, color: Colors.blue),
                    title: Text(context.tr('وثائق المقطورة')),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                    onTap: _openDocumentsScreen,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: isDark ? const Color(0xFF1E1E1E) : null,
                  child: ListTile(
                    leading: const Icon(Icons.build, color: Colors.orange),
                    title: Text(context.tr('صيانة المقطورة')),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                    onTap: _openMaintenanceScreen,
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

  Widget _buildInfoRow(String label, String value, bool isDark, {TextDirection? textDirection}) {
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
            textDirection: textDirection,
            textAlign: textDirection == TextDirection.ltr ? TextAlign.left : null,
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
