import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:collection/collection.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import 'document_categories_screen.dart';
import '../widgets/date_wheel_picker.dart';

// ignore_for_file: use_build_context_synchronously

class TruckDocumentsScreen extends StatefulWidget {
  const TruckDocumentsScreen({super.key, required this.isAdmin, this.truckId});
  final bool isAdmin;
  final int? truckId;

  @override
  State<TruckDocumentsScreen> createState() => _TruckDocumentsScreenState();
}

class _TruckDocumentsScreenState extends State<TruckDocumentsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final NotificationService _notificationService = NotificationService();
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _trucks = [];
  bool _isLoading = true;
  String? _docFilter;

  @override
  void initState() {
    super.initState();
    _notificationService.initialize();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final documents = await _supabaseService.getTruckDocuments();
    final trucks = await _supabaseService.getTrucks();
    setState(() {
      _documents = widget.truckId != null
          ? documents.where((d) => d['truck_id'] == widget.truckId).toList()
          : documents;
      _trucks = widget.truckId != null
          ? trucks.where((t) => t['id'] == widget.truckId).toList()
          : trucks;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _filteredTrucks() {
    if (_docFilter == null) return _trucks;
    final now = DateTime.now();
    return _trucks.where((truck) {
      final truckId = truck['id'] as int;
      final docs = _documents.where((d) => d['truck_id'] == truckId).toList();
      if (docs.isEmpty) return false;
      return docs.any((doc) {
        final expiryStr = doc['expiry_date']?.toString();
        if (expiryStr == null || expiryStr.isEmpty) return false;
        final expiryDate = DateTime.tryParse(expiryStr);
        if (expiryDate == null) return false;
        final diff = expiryDate.difference(now).inDays;
        if (_docFilter == 'expired') return diff < 0;
        if (_docFilter == 'expiring_soon') return diff >= 0 && diff <= 15;
        return true;
      });
    }).toList();
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

  String _truckLabel(dynamic truckId) {
    final truck = _trucks.firstWhere(
      (t) => t['id'].toString() == truckId.toString(),
      orElse: () => <String, dynamic>{},
    );
    return truck['plate']?.toString() ?? truck['plate_number']?.toString() ?? 'شاحنة غير معروفة';
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '—';
    try {
      final parsed = DateTime.parse(date);
      return intl.DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {
      return date;
    }
  }

  Future<void> _scheduleReminder(Map<String, dynamic> doc) async {
    final expiry = DateTime.tryParse(doc['expiry_date']?.toString() ?? '');
    if (expiry == null) return;
    await _notificationService.scheduleDocumentExpiryNotification(
      'وثيقة ${doc['type']?.toString() ?? 'غير معروف'} للشاحنة ${_truckLabel(doc['truck_id'])}',
      expiry,
    );
  }

  Future<void> _openDocumentDialog({Map<String, dynamic>? doc}) async {
    final isEdit = doc != null;
    int? selectedTruckId = doc != null
        ? int.tryParse(doc['truck_id'].toString())
        : widget.truckId ?? (_trucks.isNotEmpty ? _trucks.first['id'] as int : null);
    final numberController =
        TextEditingController(text: doc?['document_number']?.toString() ?? '');
    final urlController =
        TextEditingController(text: doc?['attachment_url']?.toString() ?? '');
    final ImagePicker picker = ImagePicker();
    String? attachmentUrl = doc != null ? doc['attachment_url']?.toString() : null;
    Uint8List? pickedImageBytes;
    String? pickedImageName;
    String? selectedDocType;
    DateTime? expiryDate = DateTime.tryParse(doc?['expiry_date']?.toString() ?? '');

    List<Map<String, dynamic>> docTypes = [];
    await _supabaseService.getDocumentCategories().then((cats) {
      docTypes.addAll(cats);
    });
    if (!mounted) return;
    final String? docTypeName = doc?['type']?.toString();
    if (docTypeName != null && docTypes.any((c) => c['name']?.toString() == docTypeName)) {
      selectedDocType = docTypeName;
    } else if (docTypes.isNotEmpty) {
      selectedDocType = docTypes.first['name']?.toString();
    } else {
      selectedDocType = '';
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'تعديل الوثيقة' : 'إضافة وثيقة جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                    if (widget.truckId == null)
                      DropdownButtonFormField<int>(
                        initialValue: selectedTruckId,
                        decoration: const InputDecoration(labelText: 'الشاحنة'),
                        items: _trucks
                            .toList()
                            .sorted((a, b) {
                              final aPlate = (a['plate']?.toString() ?? a['plate_number']?.toString() ?? '').toLowerCase();
                              final bPlate = (b['plate']?.toString() ?? b['plate_number']?.toString() ?? '').toLowerCase();
                              return aPlate.compareTo(bPlate);
                            })
                            .map((t) => DropdownMenuItem<int>(
                                  value: t['id'] as int,
                                  child: Text(t['plate']?.toString() ?? t['plate_number']?.toString() ?? 'بدون لوحة'),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setDialogState(() => selectedTruckId = value),
                      ),
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
                            final cats = await _supabaseService.getDocumentCategories();
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
                TextFormField(
                  controller: numberController,
                  decoration: const InputDecoration(labelText: 'رقم الوثيقة'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(expiryDate == null
                      ? 'اختر تاريخ الانتهاء'
                      : _formatDate(expiryDate!.toIso8601String()), textDirection: TextDirection.ltr),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDateWheelPicker(
                      context: context,
                      initialDate: expiryDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                     if (picked != null) setDialogState(() => expiryDate = picked);
                  },
                ),
                TextFormField(
                  controller: urlController,
                  decoration: const InputDecoration(labelText: 'رابط المرفق'),
                ),
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedTruckId == null || expiryDate == null) return;
                if (selectedDocType == null || selectedDocType == '') {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى اختيار نوع الوثيقة')),
                  );
                  return;
                }
                if (!isEdit) {
                  final exists = await _supabaseService.hasTruckDocumentType(
                    selectedTruckId!,
                    selectedDocType!,
                  );
                  if (exists) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('وثيقة من نوع "$selectedDocType" مسجلة مسبقاً لهذه الشاحنة'),
                      ),
                    );
                    return;
                  }
                }
                if (pickedImageBytes != null && selectedTruckId != null) {
                  try {
                    attachmentUrl = await _supabaseService.uploadFleetDocImage(
                      entityType: 'truck',
                      entityId: selectedTruckId!,
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
                  final data = {
                    'truck_id': selectedTruckId,
                    'type': selectedDocType ?? '',
                    'document_number': numberController.text.trim(),
                    'expiry_date': expiryDate!.toIso8601String().split('T').first,
                    'attachment_url': attachmentUrl ?? '',
                  };
                  if (isEdit) {
                    await _supabaseService.updateTruckDocument(doc['id'], data);
                  } else {
                    await _supabaseService.addTruckDocument(data);
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  await _loadData();
                  if (isEdit) {
                    await _scheduleReminder({...data, 'id': doc['id']});
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ في الحفظ: $e')),
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _supabaseService.deleteTruckDocument(doc['id']);
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('وثائق الشاحنات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_rounded),
            tooltip: 'جدولة تذكيرات الانتهاء',
            onPressed: () async {
              for (final doc in _documents) {
                await _scheduleReminder(doc);
              }
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم جدولة تذكيرات الانتهاء')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredTrucks().isEmpty
              ? Center(
                  child: Text(
                    _docFilter == null
                        ? (widget.truckId != null ? 'لا توجد وثائق لهذه الشاحنة' : 'لا توجد شاحنات مسجلة')
                        : 'لا توجد شاحنات تطابق الفلتر المحدد',
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
                  itemCount: _filteredTrucks().length,
                  itemBuilder: (context, index) {
                    final truck = _filteredTrucks()[index];
                    final truckId = truck['id'] as int;
                    final docs = _filterDocs(_documents.where((d) => d['truck_id'] == truckId).toList());
                    final plate = truck['plate']?.toString() ?? truck['plate_number']?.toString() ?? 'بدون لوحة';

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
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.left,
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
                          truck['model']?.toString() ?? '',
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
                              final docType = doc['type']?.toString() ?? 'وثيقة';

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
                                            _openDocumentDialog(doc: doc);
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
        floatingActionButton: widget.isAdmin
          ? FloatingActionButton(
              onPressed: () => _openDocumentDialog(),
              tooltip: 'إضافة وثيقة',
              child: const Icon(Icons.add),
            )
          : null,
    );
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
