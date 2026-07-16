import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

class FleetDocsScreen extends StatefulWidget {
  const FleetDocsScreen({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  State<FleetDocsScreen> createState() => _FleetDocsScreenState();
}

class _FleetDocsScreenState extends State<FleetDocsScreen> with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  late TabController _tabController;

  List<Map<String, dynamic>> _trucks = [];
  List<Map<String, dynamic>> _trailers = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _fleetDocuments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final trucks = await _supabaseService.getTrucks();
      final trailers = await _supabaseService.getTrailers();
      final categories = await _supabaseService.getDocumentCategories();
      final docs = await _supabaseService.getFleetDocuments();
      if (!mounted) return;
      setState(() {
        _trucks = trucks;
        _trailers = trailers;
        _categories = categories;
        _fleetDocuments = docs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading fleet data: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getDocsForEntity(String entityType, int entityId) {
    return _fleetDocuments
        .where((doc) => doc['entity_type'] == entityType && doc['entity_id'] == entityId)
        .toList();
  }

  String _getVehiclePlate(Map<String, dynamic> vehicle, String entityType) {
    if (entityType == 'truck') {
      return vehicle['plate']?.toString() ?? vehicle['plate_number']?.toString() ?? 'بدون لوحة';
    }
    return vehicle['plate_number']?.toString() ?? vehicle['plate']?.toString() ?? 'بدون لوحة';
  }

  String _getVehicleLabel(Map<String, dynamic> vehicle, String entityType) {
    final plate = _getVehiclePlate(vehicle, entityType);
    final model = vehicle['model']?.toString() ?? vehicle['type']?.toString() ?? '';
    return model.isNotEmpty ? '$plate - $model' : plate;
  }

  Color _getDocColor(DateTime? expiryDate, bool isDark) {
    if (expiryDate == null) return isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final now = DateTime.now();
    final diff = expiryDate.difference(now).inDays;
    if (diff < 0) return isDark ? Colors.red.shade900.withValues(alpha: 0.35) : Colors.red.shade50;
    if (diff <= 30) return isDark ? Colors.orange.shade900.withValues(alpha: 0.35) : Colors.orange.shade50;
    return isDark ? Colors.green.shade900.withValues(alpha: 0.35) : Colors.green.shade50;
  }

  Color _getDocBorderColor(DateTime? expiryDate) {
    if (expiryDate == null) return Colors.grey;
    final now = DateTime.now();
    final diff = expiryDate.difference(now).inDays;
    if (diff < 0) return Colors.red;
    if (diff <= 30) return Colors.orange;
    return Colors.green;
  }

  String _getDocStatusText(DateTime? expiryDate) {
    if (expiryDate == null) return 'غير معروف';
    final now = DateTime.now();
    final diff = expiryDate.difference(now).inDays;
    if (diff < 0) return 'انتهت منذ ${diff.abs()} يوم';
    if (diff == 0) return 'تنتهي اليوم';
    return 'متبقي $diff يوم';
  }

  String _getCategoryName(int? categoryId) {
    if (categoryId == null) return 'غير معروف';
    final cat = _categories.firstWhere(
      (c) => c['id'] == categoryId,
      orElse: () => <String, dynamic>{'name': 'غير معروف'},
    );
    return cat['name']?.toString() ?? 'غير معروف';
  }

  Future<void> _openDocDialog({Map<String, dynamic>? doc, required String entityType, int? entityId}) async {
    final isEdit = doc != null;
    int? selectedVehicleId = doc != null
        ? doc['entity_id'] as int?
        : entityId ?? (entityType == 'truck' ? (_trucks.isNotEmpty ? _trucks.first['id'] as int : null) : (_trailers.isNotEmpty ? _trailers.first['id'] as int : null));

    int? selectedCategoryId = doc != null ? doc['category_id'] as int? : (_categories.isNotEmpty ? _categories.first['id'] as int : null);
    final numberController = TextEditingController(text: doc?['document_number']?.toString() ?? '');
    final urlController = TextEditingController(text: doc?['attachment_url']?.toString() ?? '');
    DateTime? expiryDate = doc != null && doc['expiry_date'] != null
        ? DateTime.tryParse(doc['expiry_date'].toString())
        : null;

    final vehicles = entityType == 'truck' ? _trucks : _trailers;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'تعديل الوثيقة' : 'إضافة وثيقة جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(labelText: entityType == 'truck' ? 'الشاحنة' : 'المقطورة'),
                  initialValue: selectedVehicleId,
                  items: vehicles
                      .map((v) => DropdownMenuItem<int>(
                            value: v['id'] as int,
                            child: Text(_getVehicleLabel(v, entityType)),
                          ))
                      .toList(),
                  onChanged: (value) => setDialogState(() => selectedVehicleId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'نوع الوثيقة'),
                  initialValue: selectedCategoryId,
                  items: _categories
                      .map((c) => DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(c['name']?.toString() ?? ''),
                          ))
                      .toList(),
                  onChanged: (value) => setDialogState(() => selectedCategoryId = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: numberController,
                  decoration: const InputDecoration(labelText: 'رقم الوثيقة'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setDialogState(() => expiryDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'تاريخ انتهاء الصلاحية'),
                    child: Text(
                      expiryDate == null
                          ? 'اختر التاريخ'
                          : DateFormat('yyyy/MM/dd').format(expiryDate!),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: urlController,
                  decoration: const InputDecoration(labelText: 'رابط المرفق (اختياري)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (selectedVehicleId == null || selectedCategoryId == null || expiryDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة')),
                  );
                  return;
                }
                final data = {
                  'entity_type': entityType,
                  'entity_id': selectedVehicleId,
                  'category_id': selectedCategoryId,
                  'document_number': numberController.text.trim(),
                  'expiry_date': expiryDate!.toIso8601String().split('T').first,
                  'attachment_url': urlController.text.trim(),
                };
                try {
                  if (isEdit) {
                    await _supabaseService.updateFleetDocument(doc['id'] as int, data);
                  } else {
                    await _supabaseService.addFleetDocument(data);
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEdit ? 'تم تحديث الوثيقة' : 'تمت إضافة الوثيقة')),
                  );
                  await _loadData();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e')),
                  );
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الوثيقة'),
        content: const Text('هل أنت متأكد من حذف هذه الوثيقة؟'),
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
    if (confirm == true) {
      try {
        await _supabaseService.deleteFleetDocument(doc['id'] as int);
        await _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vehicles = _tabController.index == 0 ? _trucks : _trailers;
    final entityType = _tabController.index == 0 ? 'truck' : 'trailer';

    return Scaffold(
        appBar: AppBar(
          title: const Text('وثائق الأسطول'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'الشاحنات', icon: Icon(Icons.local_shipping_rounded)),
              Tab(text: 'المقطورات', icon: Icon(Icons.share_rounded)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
              onPressed: _loadData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : vehicles.isEmpty
                ? Center(
                    child: Text(
                      _tabController.index == 0 ? 'لا توجد شاحنات مسجلة' : 'لا توجد مقطورات مسجلة',
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: vehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = vehicles[index];
                      final docs = _getDocsForEntity(entityType, vehicle['id'] as int);
                      final plate = _getVehiclePlate(vehicle, entityType);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ExpansionTile(
                          title: Row(
                            children: [
                              Icon(Icons.local_shipping_rounded, color: Colors.teal[600], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  plate,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              if (docs.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getExpiringCountColor(docs, isDark),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${docs.length} وثيقة',
                                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            vehicle['model']?.toString() ?? vehicle['type']?.toString() ?? '',
                            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
                          ),
                          children: [
                            if (docs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Text(
                                  'لا توجد وثائق مسجلة',
                                  style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500], fontSize: 13),
                                ),
                              )
                            else
                              ...docs.map((doc) {
                                final expiryStr = doc['expiry_date']?.toString();
                                final expiryDate = expiryStr != null && expiryStr.isNotEmpty
                                    ? DateTime.tryParse(expiryStr)
                                    : null;
                                final cardColor = _getDocColor(expiryDate, isDark);
                                final borderColor = _getDocBorderColor(expiryDate);
                                final statusText = _getDocStatusText(expiryDate);
                                final categoryName = _getCategoryName(doc['category_id'] as int?);

                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              categoryName,
                                              style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'رقم: ${doc['document_number']?.toString() ?? '—'}',
                                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              statusText,
                                              style: TextStyle(fontSize: 12, color: borderColor, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (widget.isAdmin)
                                        PopupMenuButton<String>(
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _openDocDialog(doc: doc, entityType: entityType, entityId: vehicle['id'] as int);
                                            } else if (value == 'delete') {
                                              _confirmDelete(doc);
                                            }
                                          },
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                            PopupMenuItem(value: 'delete', child: Text('حذف')),
                                          ],
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            const SizedBox(height: 8),
                          ],
                        ),
                      );
                    },
                  ),
        floatingActionButton: widget.isAdmin
            ? FloatingActionButton(
                onPressed: () => _openDocDialog(entityType: entityType),
                tooltip: 'إضافة وثيقة',
                child: const Icon(Icons.add),
              )
            : null,
    );
  }

  Color _getExpiringCountColor(List<Map<String, dynamic>> docs, bool isDark) {
    bool hasExpired = false;
    bool hasExpiringSoon = false;
    for (final doc in docs) {
      final expiryStr = doc['expiry_date']?.toString();
      if (expiryStr == null || expiryStr.isEmpty) continue;
      final expiryDate = DateTime.tryParse(expiryStr);
      if (expiryDate == null) continue;
      final diff = expiryDate.difference(DateTime.now()).inDays;
      if (diff < 0) {
        hasExpired = true;
      } else if (diff <= 30) {
        hasExpiringSoon = true;
      }
    }
    if (hasExpired) return isDark ? Colors.red.shade700 : Colors.red.shade200;
    if (hasExpiringSoon) return isDark ? Colors.orange.shade700 : Colors.orange.shade200;
    return isDark ? Colors.green.shade700 : Colors.green.shade200;
  }
}
