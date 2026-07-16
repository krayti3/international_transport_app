import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../services/supabase_service.dart';
import '../services/notification_service.dart';

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

  static const _typeOptions = {
    'insurance': 'تأمين',
    'registration': 'تسجيل',
    'technical_control': 'فحص تقني',
    'other': 'أخرى',
  };

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
      _trucks = trucks;
      _isLoading = false;
    });
  }

  String _typeLabel(String? type) => _typeOptions[type] ?? type ?? 'غير معروف';

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
      return intl.DateFormat('yyyy/MM/dd').format(parsed);
    } catch (_) {
      return date;
    }
  }

  Future<void> _scheduleReminder(Map<String, dynamic> doc) async {
    final expiry = DateTime.tryParse(doc['expiry_date']?.toString() ?? '');
    if (expiry == null) return;
    await _notificationService.scheduleDocumentExpiryNotification(
      'وثيقة ${_typeLabel(doc['type']?.toString())} للشاحنة ${_truckLabel(doc['truck_id'])}',
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
    String type = doc?['type']?.toString() ?? 'insurance';
    DateTime? expiryDate = DateTime.tryParse(doc?['expiry_date']?.toString() ?? '');

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
                        .map((t) => DropdownMenuItem<int>(
                              value: t['id'] as int,
                              child: Text(t['plate']?.toString() ?? t['plate_number']?.toString() ?? 'بدون لوحة'),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => selectedTruckId = value),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'نوع الوثيقة'),
                  items: _typeOptions.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => type = value);
                  },
                ),
                TextFormField(
                  controller: numberController,
                  decoration: const InputDecoration(labelText: 'رقم الوثيقة'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(expiryDate == null
                      ? 'اختر تاريخ الانتهاء'
                      : _formatDate(expiryDate!.toIso8601String())),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
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
                final data = {
                  'truck_id': selectedTruckId,
                  'type': type,
                  'document_number': numberController.text.trim(),
                  'expiry_date': expiryDate!.toIso8601String().split('T').first,
                  'attachment_url': urlController.text.trim(),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('وثائق الشاحنات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
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
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _documents.isEmpty
                ? const Center(child: Text('لا توجد وثائق حالياً'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _documents.length,
                    itemBuilder: (context, index) {
                      final doc = _documents[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.description,
                              color: Colors.blue),
                          title: Text(_typeLabel(doc['type']?.toString())),
                          subtitle: Text(
                            '${_truckLabel(doc['truck_id'])} • رقم: ${doc['document_number'] ?? '—'}'
                            ' • انتهاء: ${_formatDate(doc['expiry_date']?.toString())}'
                            '${doc['attachment_url'] != null && doc['attachment_url'].toString().isNotEmpty ? ' • مرفق' : ''}',
                          ),
                          trailing: widget.isAdmin
                              ? PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _openDocumentDialog(doc: doc);
                                    } else if (value == 'delete') {
                                      _confirmDelete(doc);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('تعديل'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('حذف'),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton(
              onPressed: () => _openDocumentDialog(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
