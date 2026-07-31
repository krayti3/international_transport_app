import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart' show DateFormat;
import 'package:image_picker/image_picker.dart';
import '../services/fleet_service.dart';
import '../services/reference_service.dart';
import 'document_categories_screen.dart';
import '../widgets/date_wheel_picker.dart';

// ignore_for_file: use_build_context_synchronously

class VehicleDocTypeScreen extends StatefulWidget {
  final bool isAdmin;
  final String entityType; // 'truck' | 'trailer'
  final int entityId;
  final String docType;

  const VehicleDocTypeScreen({
    super.key,
    required this.isAdmin,
    required this.entityType,
    required this.entityId,
    required this.docType,
  });

  @override
  State<VehicleDocTypeScreen> createState() => _VehicleDocTypeScreenState();
}

class _VehicleDocTypeScreenState extends State<VehicleDocTypeScreen> {
  final FleetService _fleetService = FleetService();
  final ReferenceService _referenceService = ReferenceService();
  List<Map<String, dynamic>> _documents = [];
  String? _entityLabel;
  bool _isLoading = true;
  String? _docFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final docs = await _fleetService.getVehicleDocumentsByType(
        entityType: widget.entityType,
        entityId: widget.entityId,
        docType: widget.docType,
      );
      String? label;
      if (widget.entityType == 'truck') {
        final trucks = await _fleetService.getTrucks();
        final truck = trucks.firstWhereOrNull((t) => t['id'] == widget.entityId);
        if (truck != null) {
          label = truck['plate']?.toString() ?? truck['plate_number']?.toString();
        }
      } else {
        final trailers = await _fleetService.getTrailers();
        final trailer = trailers.firstWhereOrNull((t) => t['id'] == widget.entityId);
        if (trailer != null) {
          label = trailer['plate_number']?.toString() ?? trailer['plate']?.toString();
        }
      }
      if (!mounted) return;
      setState(() {
        _documents = docs;
        _entityLabel = label;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading vehicle doc type: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _filterDocs(List<Map<String, dynamic>> docs) {
    final now = DateTime.now();
    return docs.where((doc) {
      final expiryStr = doc['expiry_date']?.toString();
      if (expiryStr == null || expiryStr.isEmpty) return _docFilter == null;
      final expiryDate = DateTime.tryParse(expiryStr);
      if (expiryDate == null) return _docFilter == null;
      final diff = expiryDate.difference(now).inDays;
      if (_docFilter == null) return true;
      if (_docFilter == 'expired') return diff < 0;
      if (_docFilter == 'expiring_soon') return diff >= 0 && diff <= 15;
      if (_docFilter == 'valid') return diff > 15;
      return true;
    }).toList();
  }

  String _sourceKey(Map<String, dynamic> doc) {
    return doc['_source']?.toString() ?? 'unknown';
  }

  Future<void> _openDocDialog({Map<String, dynamic>? doc}) async {
    final isEdit = doc != null;
    final source = doc != null ? _sourceKey(doc) : 'fleet';

    final numberController = TextEditingController(text: doc?['document_number']?.toString() ?? '');
    final urlController = TextEditingController(text: doc?['attachment_url']?.toString() ?? '');
    String? selectedDocType = doc?['doc_type']?.toString() ?? widget.docType;
    final ImagePicker picker = ImagePicker();
    String? attachmentUrl = doc != null ? doc['attachment_url']?.toString() : null;
    Uint8List? pickedImageBytes;
    String? pickedImageName;
    DateTime? expiryDate = doc != null && doc['expiry_date'] != null
        ? DateTime.tryParse(doc['expiry_date'].toString())
        : null;

    List<Map<String, dynamic>> docTypes = [];
    await _referenceService.getDocumentCategories().then((cats) {
      docTypes.addAll(cats);
    });
    if (!mounted) return;
    if (doc != null && docTypes.any((c) => c['name']?.toString() == selectedDocType)) {
      // keep selectedDocType
    } else if (docTypes.isNotEmpty) {
      selectedDocType = docTypes.first['name']?.toString();
    } else {
      selectedDocType = widget.docType;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'تعديل الوثيقة' : 'إضافة وثيقة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.entityType == 'truck' ? 'شاحنة' : 'مقطورة'}: ${_entityLabel ?? 'غير معروف'}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedDocType,
                  decoration: InputDecoration(
                    labelText: 'نوع الوثيقة',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.manage_history, size: 20),
                      tooltip: 'إدارة أنواع الوثائق',
                      onPressed: () async {
                        if (!widget.isAdmin) return;
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DocumentCategoriesScreen()),
                        );
                        if (!mounted) return;
                        final cats = await _referenceService.getDocumentCategories();
                        setDialogState(() {
                          docTypes = cats;
                          if (!docTypes.any((c) => c['name']?.toString() == selectedDocType)) {
                            selectedDocType = null;
                          }
                        });
                      },
                    ),
                  ),
                  items: [
                    ...docTypes.map((c) => DropdownMenuItem(
                          value: c['name']?.toString() ?? '',
                          child: Text(c['name']?.toString() ?? ''),
                        )),
                    if (docTypes.isEmpty)
                      const DropdownMenuItem(
                        value: '',
                        child: Text('لا توجد أنواع'),
                      ),
                  ],
                  onChanged: (v) => setDialogState(() => selectedDocType = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: numberController,
                  decoration: const InputDecoration(labelText: 'رقم الوثيقة'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDateWheelPicker(
                      context: context,
                      initialDate: expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
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
                          : DateFormat('dd/MM/yyyy').format(expiryDate!),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: urlController,
                  decoration: const InputDecoration(labelText: 'رابط المرفق (اختياري)'),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                    if (picked != null) {
                      final bytes = await picked.readAsBytes();
                      setDialogState(() {
                        pickedImageBytes = bytes;
                        pickedImageName = picked.name;
                      });
                    }
                  },
                  icon: const Icon(Icons.image),
                  label: const Text('إرفاق صورة الوثيقة'),
                ),
                if (pickedImageBytes != null) ...[
                  const SizedBox(height: 8),
                  Image.memory(pickedImageBytes!, height: 140, fit: BoxFit.cover),
                  const SizedBox(height: 4),
                  const Text('تم اختيار الصورة', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ] else if (attachmentUrl != null && attachmentUrl!.isNotEmpty && attachmentUrl!.startsWith('http')) ...[
                  const SizedBox(height: 8),
                  Image.network(attachmentUrl!, height: 140, fit: BoxFit.cover),
                  const SizedBox(height: 4),
                  const Text('الصورة الحالية', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (selectedDocType == null || expiryDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى ملء الحقول المطلوبة')),
                  );
                  return;
                }
                if (pickedImageBytes != null) {
                  try {
                    attachmentUrl = await _fleetService.uploadFleetDocImage(
                      entityType: widget.entityType,
                      entityId: widget.entityId,
                      fileName: pickedImageName ?? 'doc.jpg',
                      bytes: pickedImageBytes!,
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر رفع الصورة: $e')));
                    return;
                  }
                }
                try {
                  final nowIso = expiryDate!.toIso8601String().split('T').first;
                  if (isEdit) {
                    if (source == 'fleet') {
                      await _referenceService.updateFleetDocument(doc['id'] as int, {
                        'doc_type': selectedDocType ?? '',
                        'document_number': numberController.text.trim(),
                        'expiry_date': nowIso,
                        'attachment_url': attachmentUrl ?? '',
                      });
                    } else {
                      await _referenceService.updateTruckDocument(doc['id'] as int, {
                        'type': selectedDocType ?? '',
                        'document_number': numberController.text.trim(),
                        'expiry_date': nowIso,
                        'attachment_url': attachmentUrl ?? '',
                      });
                    }
                  } else {
                    await _referenceService.addFleetDocument({
                      'entity_type': widget.entityType,
                      'entity_id': widget.entityId,
                      'doc_type': selectedDocType ?? '',
                      'document_number': numberController.text.trim(),
                      'expiry_date': nowIso,
                      'attachment_url': attachmentUrl ?? '',
                    });
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
    final source = _sourceKey(doc);
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
    if (confirm != true) return;
    try {
      final docId = doc['id'] as int;
      if (source == 'fleet') {
        await _referenceService.deleteFleetDocument(docId);
      } else {
        await _referenceService.deleteTruckDocument(docId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الوثيقة')));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
    }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredDocs = _filterDocs(_documents);
    final expiredCount = filteredDocs.where((doc) {
      final expiryStr = doc['expiry_date']?.toString();
      final expiryDate = expiryStr != null && expiryStr.isNotEmpty ? DateTime.tryParse(expiryStr) : null;
      return expiryDate != null && expiryDate.difference(DateTime.now()).inDays < 0;
    }).length;
    final expiringCount = filteredDocs.where((doc) {
      final expiryStr = doc['expiry_date']?.toString();
      final expiryDate = expiryStr != null && expiryStr.isNotEmpty ? DateTime.tryParse(expiryStr) : null;
      return expiryDate != null && expiryDate.difference(DateTime.now()).inDays >= 0 && expiryDate.difference(DateTime.now()).inDays <= 15;
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.docType} - $_entityLabel'),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openDocDialog(),
              tooltip: 'إضافة وثيقة',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                  child: Row(
                    children: [
                      _SummaryBadge(label: 'الكل', value: filteredDocs.length, isActive: _docFilter == null, isDark: isDark),
                      const SizedBox(width: 8),
                      _SummaryBadge(label: 'منتهية', value: expiredCount, isActive: _docFilter == 'expired', isDark: isDark, color: Colors.red),
                      const SizedBox(width: 8),
                      _SummaryBadge(label: 'قريبة الانتهاء', value: expiringCount, isActive: _docFilter == 'expiring_soon', isDark: isDark, color: Colors.orange),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      ChoiceChip(label: const Text('الكل'), selected: _docFilter == null, onSelected: (_) => setState(() => _docFilter = null)),
                      const SizedBox(width: 8),
                      ChoiceChip(label: const Text('منتهية'), selected: _docFilter == 'expired', onSelected: (_) => setState(() => _docFilter = 'expired')),
                      const SizedBox(width: 8),
                      ChoiceChip(label: const Text('تنتهي خلال 15 يوم'), selected: _docFilter == 'expiring_soon', onSelected: (_) => setState(() => _docFilter = 'expiring_soon')),
                      const SizedBox(width: 8),
                      ChoiceChip(label: const Text('صالحة'), selected: _docFilter == 'valid', onSelected: (_) => setState(() => _docFilter = 'valid')),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredDocs.isEmpty
                      ? Center(child: Text('لا توجد وثائق', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            final doc = filteredDocs[index];
                            final expiryStr = doc['expiry_date']?.toString();
                            final expiryDate = expiryStr != null && expiryStr.isNotEmpty
                                ? DateTime.tryParse(expiryStr)
                                : null;
                            final borderColor = _getDocBorderColor(expiryDate);
                            final statusText = _getDocStatusText(expiryDate);
                            final docTypeLabel = doc['doc_type']?.toString() ?? widget.docType;
                            final docNumber = doc['document_number']?.toString() ?? '—';

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: _getDocColor(expiryDate, isDark),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            docTypeLabel,
                                            style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                                          ),
                                          const SizedBox(height: 4),
                                          Text('رقم الوثيقة: $docNumber', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                                          const SizedBox(height: 2),
                                          Text(
                                            DateFormat('dd/MM/yyyy').format(expiryDate ?? DateTime.now()),
                                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                                            textDirection: TextDirection.ltr,
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: borderColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(statusText, style: TextStyle(fontSize: 11, color: borderColor, fontWeight: FontWeight.w600)),
                                          ),
                                          if ((doc['attachment_url']?.toString() ?? '').startsWith('http')) ...[
                                            const SizedBox(height: 8),
                                            GestureDetector(
                                              onTap: () => showDialog(
                                                context: context,
                                                builder: (_) => Dialog(child: Image.network(doc['attachment_url'].toString())),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(6),
                                                child: Image.network(doc['attachment_url'].toString(), height: 80, fit: BoxFit.cover),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (widget.isAdmin)
                                    Container(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _openDocDialog(doc: doc);
                                          } else if (value == 'delete') {
                                            _confirmDelete(doc);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                          PopupMenuItem(value: 'delete', child: Text('حذف')),
                                        ],
                                      ),
                                    ),
                                ],
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

class _SummaryBadge extends StatelessWidget {
  final String label;
  final int value;
  final bool isActive;
  final bool isDark;
  final Color? color;

  const _SummaryBadge({required this.label, required this.value, required this.isActive, required this.isDark, this.color});

  @override
  Widget build(BuildContext context) {
    final bg = isActive
        ? (color ?? Theme.of(context).colorScheme.primary)
        : (isDark ? const Color(0xFF2A2A2A) : Colors.grey[200]!);
    final textColor = isActive ? Colors.white : (isDark ? Colors.grey[300]! : Colors.grey[700]!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$label: $value', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}
