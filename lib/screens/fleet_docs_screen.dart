import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart' show DateFormat;
import '../services/supabase_service.dart';
import 'package:image_picker/image_picker.dart';
import 'document_categories_screen.dart';
import '../widgets/date_wheel_picker.dart';

class FleetDocsScreen extends StatefulWidget {
  const FleetDocsScreen({super.key, required this.isAdmin, this.trailerId});
  final bool isAdmin;
  final int? trailerId;

  @override
  State<FleetDocsScreen> createState() => _FleetDocsScreenState();
}

class _FleetDocsScreenState extends State<FleetDocsScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  List<Map<String, dynamic>> _trailers = [];
  List<Map<String, dynamic>> _fleetDocuments = [];
  bool _isLoading = true;
  String? _docFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final trailers = await _supabaseService.getTrailers();
      final docs = await _supabaseService.getFleetDocuments();
      if (!mounted) return;
      setState(() {
        _trailers = widget.trailerId != null
            ? trailers.where((t) => t['id'] == widget.trailerId).toList()
            : trailers;
        _fleetDocuments = docs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading fleet data: $e');
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
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> _getDocsForTrailer(int trailerId) {
    final docs = _fleetDocuments
        .where((doc) => doc['entity_type'] == 'trailer' && doc['entity_id'] == trailerId)
        .toList();
    return _filterDocs(docs);
  }

  String _getTrailerPlate(Map<String, dynamic> trailer) {
    return trailer['plate_number']?.toString() ?? trailer['plate']?.toString() ?? 'بدون لوحة';
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

  Future<void> _openDocDialog({Map<String, dynamic>? doc, int? entityId}) async {
    final isEdit = doc != null;
    int? selectedVehicleId = doc != null
        ? doc['entity_id'] as int?
        : entityId ?? (_trailers.isNotEmpty ? _trailers.first['id'] as int : null);

    final numberController = TextEditingController(text: doc?['document_number']?.toString() ?? '');
    final urlController = TextEditingController(text: doc?['attachment_url']?.toString() ?? '');
    String? selectedDocType;
    final ImagePicker picker = ImagePicker();
    String? attachmentUrl = doc != null ? doc['attachment_url']?.toString() : null;
    Uint8List? pickedImageBytes;
    String? pickedImageName;
    DateTime? expiryDate = doc != null && doc['expiry_date'] != null
        ? DateTime.tryParse(doc['expiry_date'].toString())
        : null;

    List<Map<String, dynamic>> docTypes = [];
    await _supabaseService.getDocumentCategories().then((cats) {
      docTypes.addAll(cats);
    });
    if (!mounted) return;
    final String? docTypeName = doc?['doc_type']?.toString();
    if (docTypeName != null && docTypes.any((c) => c['name']?.toString() == docTypeName)) {
      selectedDocType = docTypeName;
    } else if (docTypes.isNotEmpty) {
      selectedDocType = docTypes.first['name']?.toString();
    } else {
      selectedDocType = '';
    }

    final vehicles = _trailers;

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
                  decoration: const InputDecoration(labelText: 'المقطورة'),
                  initialValue: selectedVehicleId,
                  items: vehicles
                      .toList()
                      .sorted((a, b) {
                        final aPlate = (a['plate_number']?.toString() ?? a['plate']?.toString() ?? '').toLowerCase();
                        final bPlate = (b['plate_number']?.toString() ?? b['plate']?.toString() ?? '').toLowerCase();
                        return aPlate.compareTo(bPlate);
                      })
                      .map((v) => DropdownMenuItem<int>(
                            value: v['id'] as int,
                            child: Text(_getTrailerPlate(v)),
                          ))
                      .toList(),
                  onChanged: (value) => setDialogState(() => selectedVehicleId = value),
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
                        final cats = await _supabaseService.getDocumentCategories();
                        if (mounted) {
                          setDialogState(() {
                            docTypes = cats;
                            if (!docTypes.any((c) => c['name']?.toString() == selectedDocType)) {
                              selectedDocType = null;
                            }
                          });
                        }
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
                if (selectedVehicleId == null || expiryDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة')),
                  );
                  return;
                }
                if (selectedDocType == null || selectedDocType == '') {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى اختيار نوع الوثيقة')),
                  );
                  return;
                }
                if (!isEdit) {
                  final exists = await _supabaseService.hasFleetDocumentType(
                    'trailer',
                    selectedVehicleId!,
                    selectedDocType!,
                  );
                  if (exists) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('وثيقة من نوع "$selectedDocType" مسجلة مسبقاً لهذه المقطورة'),
                      ),
                    );
                    return;
                  }
                }
                 if (pickedImageBytes != null && selectedVehicleId != null) {
                  try {
                    attachmentUrl = await _supabaseService.uploadFleetDocImage(
                      entityType: 'trailer',
                      entityId: selectedVehicleId!,
                      fileName: pickedImageName ?? 'doc.jpg',
                      bytes: pickedImageBytes!,
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر رفع الصورة: $e')));
                    return;
                  }
                }
                final data = {
                  'entity_type': 'trailer',
                  'entity_id': selectedVehicleId,
                  'doc_type': selectedDocType ?? '',
                  'document_number': numberController.text.trim(),
                  'expiry_date': expiryDate!.toIso8601String().split('T').first,
                  'attachment_url': attachmentUrl ?? '',
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

    return Scaffold(
        appBar: AppBar(
          title: const Text('وثائق المقطورات'),
          actions: [
            if (widget.isAdmin)
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _openDocDialog(),
                tooltip: 'إضافة وثيقة',
              ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
              onPressed: _loadData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _trailers.isEmpty
                ? Center(
                    child: Text(
                      widget.trailerId != null ? 'لا توجد وثائق لهذه المقطورة' : 'لا توجد مقطورات مسجلة',
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  )
                : Column(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('الكل'),
                              selected: _docFilter == null,
                              onSelected: (_) => setState(() => _docFilter = null)),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('منتهية'),
                              selected: _docFilter == 'expired',
                              onSelected: (_) => setState(() => _docFilter = 'expired')),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('تنتهي خلال 15 يوم'),
                              selected: _docFilter == 'expiring_soon',
                              onSelected: (_) => setState(() => _docFilter = 'expiring_soon')),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _trailers.length,
                    itemBuilder: (context, index) {
                      final vehicle = _trailers[index];
                      final docs = _getDocsForTrailer(vehicle['id'] as int);
                      final plate = _getTrailerPlate(vehicle);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ExpansionTile(
                          title: Row(
                            children: [
                              Icon(Icons.share_rounded, color: Colors.teal[600], size: 20),
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
                            vehicle['type']?.toString() ?? '',
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
                                final docType = doc['doc_type']?.toString() ?? 'وثيقة';

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
                                              docType,
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
                                            if ((doc['attachment_url']?.toString() ?? '').startsWith('http')) ...[
                                              const SizedBox(height: 6),
                                              GestureDetector(
                                                onTap: () => showDialog(
                                                  context: context,
                                                  builder: (_) => Dialog(child: Image.network(doc['attachment_url'].toString())),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: Image.network(doc['attachment_url'].toString(), height: 90, fit: BoxFit.cover),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (widget.isAdmin)
                                        PopupMenuButton<String>(
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _openDocDialog(doc: doc, entityId: vehicle['id'] as int);
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
                      ),
                    ],
                  ),
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
