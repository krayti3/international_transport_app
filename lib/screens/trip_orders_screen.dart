import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../services/supabase_service.dart';

// ignore_for_file: use_build_context_synchronously

class TripOrdersScreen extends StatefulWidget {
  const TripOrdersScreen({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  State<TripOrdersScreen> createState() => _TripOrdersScreenState();
}

class _TripOrdersScreenState extends State<TripOrdersScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  List<Map<String, dynamic>> _tripOrders = [];
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _trucks = [];
  bool _isLoading = true;

  // الحالات المعتمدة (عربية) لتبقى متوافقة مع باقي شاشات المشروع.
  static const String kPending = 'قيد الانتظار';
  static const String kActive = 'قيد التنفيذ';
  static const String kCompleted = 'مكتملة';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final tripOrders = await _supabaseService.getTripOrders();
    final clients = await _supabaseService.getClients();
    final drivers = await _supabaseService.getDrivers();
    final trucks = await _supabaseService.getTrucks();
    if (!mounted) return;
    tripOrders.sort((a, b) {
      final ai = (a['id'] as int?) ?? 0;
      final bi = (b['id'] as int?) ?? 0;
      return bi.compareTo(ai);
    });
    setState(() {
      _tripOrders = tripOrders;
      _clients = clients;
      _drivers = drivers;
      _trucks = trucks;
      _isLoading = false;
    });
  }

  String _clientName(dynamic clientId) {
    final c = _clients.firstWhere(
      (e) => e['id']?.toString() == clientId?.toString(),
      orElse: () => const {},
    );
    return c['name']?.toString() ?? 'غير محدد';
  }

  String _driverName(dynamic driverId) {
    final d = _drivers.firstWhere(
      (e) => e['id']?.toString() == driverId?.toString(),
      orElse: () => const {},
    );
    return d['name']?.toString() ?? '—';
  }

  String _truckPlate(dynamic truckId) {
    final t = _trucks.firstWhere(
      (e) => e['id']?.toString() == truckId?.toString(),
      orElse: () => const {},
    );
    return t['plate']?.toString() ?? t['plate_number']?.toString() ?? '—';
  }

  double _priceOf(Map<String, dynamic> order) =>
      (order['price'] as num?)?.toDouble() ?? 0.0;

  Future<List<Map<String, dynamic>>> _loadTripDocuments(int tripOrderId) async {
    return _supabaseService.getTripDocuments(tripOrderId);
  }

  Future<void> _openDocumentsDialog(Map<String, dynamic> trip) async {
    final tripId = trip['id'] as int;
    final documents = await _loadTripDocuments(tripId);
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('وثائق الرحلة #${trip['id'] ?? '?'}'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.6,
            child: documents.isEmpty
                ? const Text('لا توجد وثائق مرفقة حالياً')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: documents.length,
                    itemBuilder: (context, index) {
                      final doc = documents[index];
                      final isImage = doc['file_type']?.toString() == 'image';
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Icon(
                            isImage ? Icons.image : Icons.picture_as_pdf,
                            color: isImage ? Colors.green : Colors.red,
                          ),
                          title: Text(doc['file_name']?.toString() ?? 'وثيقة'),
                          subtitle: Text(doc['document_type']?.toString() ?? ''),
                          trailing: widget.isAdmin
                              ? IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
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
                                      try {
                                        await _supabaseService.deleteTripDocument(doc['id'] as int);
                                        final updated = await _loadTripDocuments(tripId);
                                        if (mounted) {
                                          setDialogState(() {
                                            documents.clear();
                                            documents.addAll(updated);
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('تم حذف الوثيقة بنجاح')),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('خطأ في حذف الوثيقة: $e')),
                                          );
                                        }
                                      }
                                    }
                                  },
                                )
                              : null,
                          onTap: () {
                            final url = doc['file_url']?.toString();
                            if (url != null && url.isNotEmpty) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  content: SizedBox(
                                    width: MediaQuery.of(context).size.width * 0.6,
                                    height: MediaQuery.of(context).size.height * 0.6,
                                    child: isImage
                                        ? Image.network(url, fit: BoxFit.contain)
                                        : const Center(child: Text('لا يمكن عرض ملف PDF هنا، يرجى فتحه من الرابط')),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('إغلاق'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('الرابط: $url')),
                                        );
                                      },
                                      child: const Text('فتح الرابط'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
            if (widget.isAdmin)
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                  );
                  if (result == null || result.files.isEmpty) return;
                  final picked = result.files.first;
                  if (picked.bytes == null) return;

                  if (mounted) setState(() => _isLoading = true);
                  try {
                    final url = await _supabaseService.uploadTripDocument(
                      picked.name,
                      picked.bytes!,
                    );
                    await _supabaseService.addTripDocument({
                      'trip_order_id': tripId,
                      'file_name': picked.name,
                      'file_url': url,
                      'file_type': picked.name.toLowerCase().endsWith('.pdf') ? 'pdf' : 'image',
                      'document_type': 'customs',
                    });
                    final updated = await _loadTripDocuments(tripId);
                    if (mounted) {
                      setDialogState(() {
                        documents.clear();
                        documents.addAll(updated);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم إرفاق الوثيقة بنجاح')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('خطأ في إرفاق الوثيقة: $e')),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
                icon: const Icon(Icons.attach_file),
                label: const Text('إرفاق وثيقة'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTripDialog({Map<String, dynamic>? trip}) async {
    final isEdit = trip != null;
    String? clientId = isEdit ? trip['client_id']?.toString() : null;
    String? driverId = isEdit ? trip['driver_id']?.toString() : null;
    String? truckId = isEdit ? trip['truck_id']?.toString() : null;
    String status = isEdit ? (trip['status']?.toString() ?? kActive) : kActive;
    final routeController = TextEditingController(text: trip?['route']?.toString() ?? '');
    final priceController = TextEditingController(text: trip?['price']?.toString() ?? '');
    final dateController = TextEditingController(text: trip?['departure_date']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'تعديل الرحلة' : 'تسجيل طلب رحلة جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'الزبون / الشركة الطالبة'),
                  initialValue: clientId,
                  items: _clients
                      .map((c) => DropdownMenuItem(
                            value: c['id']?.toString(),
                            child: Text(c['name']?.toString() ?? 'بدون اسم'),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => clientId = v),
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'السائق'),
                  initialValue: driverId,
                  items: _drivers
                      .map((d) => DropdownMenuItem(
                            value: d['id']?.toString(),
                            child: Text(d['name']?.toString() ?? 'بدون اسم'),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() {
                    driverId = v;
                    final drv = _drivers.firstWhere(
                      (d) => d['id']?.toString() == v,
                      orElse: () => <String, dynamic>{},
                    );
                    truckId = drv['default_truck_id']?.toString() ?? truckId;
                  }),
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'الشاحنة'),
                  initialValue: truckId,
                  items: _trucks
                      .map((t) => DropdownMenuItem(
                            value: t['id']?.toString(),
                              child: Text(t['plate']?.toString() ?? t['plate_number']?.toString() ?? 'بدون لوحة'),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() {
                    truckId = v;
                    if (v != null) {
                      final defaultDriver = _drivers.firstWhere(
                        (d) => d['default_truck_id']?.toString() == v,
                        orElse: () => <String, dynamic>{},
                      );
                      if (defaultDriver.isNotEmpty) {
                        driverId = defaultDriver['id']?.toString();
                      }
                    }
                  }),
                ),
                TextFormField(
                  controller: routeController,
                  decoration: const InputDecoration(labelText: 'مسار الرحلة (من - إلى)'),
                ),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'أجرة الشحن المتفق عليها'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextFormField(
                  controller: dateController,
                  decoration: const InputDecoration(labelText: 'تاريخ الانطلاق'),
                  readOnly: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (clientId == null || routeController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى اختيار الزبون وإدخال المسار')),
                  );
                  return;
                }
                final data = {
                  'client_id': clientId,
                  'driver_id': driverId,
                  'truck_id': truckId,
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
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'تم تحديث الرحلة' : 'تم تسجيل طلب الرحلة بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ في حفظ الرحلة: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text(isEdit ? 'حفظ' : 'حفظ الطلب'),
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
      await _supabaseService.updateTripOrder(
        trip['id'] as int,
        {'status': selected},
        localRow: trip,
      );
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final total = _tripOrders.length;
    final completed = _tripOrders
        .where((t) => (t['status']?.toString() ?? '') == kCompleted)
        .length;
    final active = total - completed;
    final totalValue = _tripOrders.fold<double>(0, (sum, t) => sum + _priceOf(t));

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة طلبات الرحلات'),
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // بطاقات إحصائية بأرقام حقيقية من قاعدة البيانات.
                  Row(
                    children: [
                      _buildStatCard(
                        'رحلات قيد التنفيذ',
                        '$active',
                        Icons.local_shipping_rounded,
                        Colors.orange,
                        isDark,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'إجمالي الطلبات',
                        '$total',
                        Icons.analytics_rounded,
                        Colors.teal,
                        isDark,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'إجمالي الأجور',
                        NumberFormat('#,###').format(totalValue),
                        Icons.payments_rounded,
                        Colors.blue,
                        isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'طلبات النقل واللوجستيك الحالية',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.blueGrey[900],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _tripOrders.isEmpty
                        ? const Center(child: Text('لا توجد طلبات رحلات مسجلة حالياً.'))
                        : ListView.builder(
                            itemCount: _tripOrders.length,
                            itemBuilder: (context, index) =>
                                _buildTripCard(_tripOrders[index], isDark),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTripDialog(),
        icon: const Icon(Icons.add_road_rounded),
        label: const Text('تسجيل رحلة'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> order, bool isDark) {
    final status = order['status']?.toString() ?? kActive;
    final price = _priceOf(order);
    final date = order['departure_date']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // المسار + الحالة.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.red[400], size: 20),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          order['route']?.toString() ?? 'مسار غير محدد',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(status),
              ],
            ),
            const Divider(height: 24),
            // الزبون + الأجرة.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الزبون / الشاحن',
                          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[500], fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(_clientName(order['client_id']),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                     Text('الأجرة المتفق عليها',
                         style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[500], fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat('#,###').format(price),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 15),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // السائق + الشاحنة + التاريخ + قائمة الإجراءات.
            Row(
              children: [
                Icon(Icons.person, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                const SizedBox(width: 4),
                Text(_driverName(order['driver_id']),
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                const SizedBox(width: 12),
                Icon(Icons.local_shipping, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                const SizedBox(width: 4),
                 Text(_truckPlate(order['truck_id']),
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                if (date.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.event, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(date, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                ],
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      _openTripDialog(trip: order);
                    } else if (value == 'status') {
                      await _changeStatus(order);
                    } else if (value == 'documents') {
                      await _openDocumentsDialog(order);
                    } else if (value == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('حذف الرحلة'),
                          content: const Text('هل أنت متأكد من حذف هذه الرحلة؟'),
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
                        try {
                          await _supabaseService.deleteTripOrder(order['id'] as int);
                          await _loadData();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطأ في حذف الرحلة: $e')),
                          );
                        }
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                    const PopupMenuItem(value: 'status', child: Text('تحديث الحالة')),
                    const PopupMenuItem(value: 'documents', child: Text('الوثائق')),
                    if (widget.isAdmin)
                      const PopupMenuItem(value: 'delete', child: Text('حذف')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case kCompleted:
        bgColor = Colors.green.withValues(alpha: 0.15);
        textColor = Colors.green[700]!;
        label = 'مكتملة';
        break;
      case kPending:
        bgColor = Colors.orange.withValues(alpha: 0.15);
        textColor = Colors.orange[700]!;
        label = 'قيد الانتظار';
        break;
      default:
        bgColor = Colors.blue.withValues(alpha: 0.15);
        textColor = Colors.blue[700]!;
        label = status.isEmpty ? 'قيد التنفيذ' : status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(title,
                       style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[500], fontSize: 13),
                       overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(value,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
