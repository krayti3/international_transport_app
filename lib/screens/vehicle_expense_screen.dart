import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../services/supabase_service.dart';
import '../widgets/date_wheel_picker.dart';
import 'providers_screen.dart';

class VehicleExpenseScreen extends StatefulWidget {
  final bool isAdmin;
  final String vehicleType; // 'truck' | 'trailer'
  final int vehicleId;
  final String expenseType;

  const VehicleExpenseScreen({
    super.key,
    required this.isAdmin,
    required this.vehicleType,
    required this.vehicleId,
    required this.expenseType,
  });

  @override
  State<VehicleExpenseScreen> createState() => _VehicleExpenseScreenState();
}

class _VehicleExpenseScreenState extends State<VehicleExpenseScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _records = [];
  String? _vehicleLabel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      String? label;
      if (widget.vehicleType == 'truck') {
        final trucks = await _supabaseService.getTrucks();
        final truck = trucks.firstWhere(
          (t) => t['id'] == widget.vehicleId,
          orElse: () => <String, dynamic>{},
        );
        label = truck['plate']?.toString() ?? truck['plate_number']?.toString();
      } else {
        final trailers = await _supabaseService.getTrailers();
        final trailer = trailers.firstWhere(
          (t) => t['id'] == widget.vehicleId,
          orElse: () => <String, dynamic>{},
        );
        label = trailer['plate_number']?.toString() ?? trailer['plate']?.toString();
      }

      List<Map<String, dynamic>> records;
      if (widget.vehicleType == 'truck') {
        records = await _supabaseService.getTruckMaintenancesByTruck(widget.vehicleId);
        records = records.where((r) => r['expense_type']?.toString() == widget.expenseType).toList();
      } else {
        records = await _supabaseService.getTrailerMaintenancesByTrailer(widget.vehicleId);
        records = records.where((r) => r['expense_type']?.toString() == widget.expenseType).toList();
      }
      records.sort((a, b) {
        final aDate = a['maintenance_date']?.toString() ?? '';
        final bDate = b['maintenance_date']?.toString() ?? '';
        return bDate.compareTo(aDate);
      });

      if (!mounted) return;
      setState(() {
        _records = records;
        _vehicleLabel = label;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading vehicle expenses: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openExpenseDialog({Map<String, dynamic>? record}) async {
    final isEdit = record != null;
    final amountController = TextEditingController(text: record?['amount']?.toString() ?? '');
    final kmController = TextEditingController(text: (record?['km_at_time'] as num?)?.toDouble().toString() ?? '');
    final descController = TextEditingController(text: record?['description']?.toString() ?? '');
    String paymentStatus = record?['payment_status']?.toString() ?? 'paid_by_owner';
    DateTime? maintenanceDate = record != null && record['maintenance_date'] != null
        ? DateTime.tryParse(record['maintenance_date'].toString())
        : DateTime.now();
    String selectedDocType = widget.expenseType;
    String? selectedProvider = record?['provider_name']?.toString() ?? '';

    final providers = await _supabaseService.getProviders();
    if (!mounted) return;
    List<String> providerNames = providers.map((p) => p['name']?.toString() ?? '').toList();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'تعديل مصروف' : 'إضافة مصروف'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.vehicleType == 'truck' ? 'شاحنة' : 'مقطورة'}: ${_vehicleLabel ?? 'غير معروف'}',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedDocType,
                  decoration: const InputDecoration(labelText: 'نوع المصروف'),
                  items: const [
                    DropdownMenuItem(value: 'oil_change', child: Text('تغيير الزيت')),
                    DropdownMenuItem(value: 'tires', child: Text('إطارات')),
                    DropdownMenuItem(value: 'insurance', child: Text('تأمين')),
                    DropdownMenuItem(value: 'technical_inspection', child: Text('فحص تقني')),
                    DropdownMenuItem(value: 'depreciation', child: Text('إهلاك')),
                    DropdownMenuItem(value: 'other', child: Text('أخرى')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedDocType = v ?? widget.expenseType),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: paymentStatus,
                  decoration: const InputDecoration(labelText: 'حالة الدفع'),
                  items: const [
                    DropdownMenuItem(value: 'paid_by_owner', child: Text('الكاش من صاحب الشركة')),
                    DropdownMenuItem(value: 'bank_transfer', child: Text('تحويل بنكي من صاحب الشركة')),
                    DropdownMenuItem(value: 'secretary_cash', child: Text('الكاش من خزينة السكرتيرة')),
                    DropdownMenuItem(value: 'on_credit', child: Text('على الحساب (دَين)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => paymentStatus = v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'المبلغ (DH)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: kmController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'عداد الكيلومترات'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDateWheelPicker(
                      context: context,
                      initialDate: maintenanceDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setDialogState(() => maintenanceDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'تاريخ إجراء الإصلاح'),
                    child: Text(
                      maintenanceDate == null ? 'اختر التاريخ' : DateFormat('dd/MM/yyyy').format(maintenanceDate!),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: (selectedProvider == null || selectedProvider!.isEmpty) ? null : selectedProvider,
                  decoration: InputDecoration(
                    labelText: 'اسم المزود / الورشة',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.manage_history, size: 20),
                      tooltip: 'إدارة الورشات',
                      onPressed: () async {
                        if (!widget.isAdmin) return;
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProvidersScreen()),
                        );
                        final providers = await _supabaseService.getProviders();
                        if (mounted) {
                          setDialogState(() {
                            providerNames = providers.map((p) => p['name']?.toString() ?? '').toList();
                            if ((selectedProvider == null || selectedProvider!.isEmpty) && providerNames.isNotEmpty) {
                              selectedProvider = providerNames.first;
                            }
                          });
                        }
                      },
                    ),
                  ),
                  items: [
                    ...providerNames.map((name) {
                      return DropdownMenuItem(
                        value: name,
                        child: Text(name),
                      );
                    }),
                    if (providerNames.isEmpty)
                      const DropdownMenuItem(
                        value: '',
                        child: Text('لا توجد ورشات'),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() {
                        selectedProvider = v;
                      });
                    }
                  },
                ),
                TextFormField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final vehicleIdVal = widget.vehicleId;
                if (amountController.text.trim().isEmpty) return;
                try {
                  final data = {
                    if (widget.vehicleType == 'truck')
                      'truck_id': vehicleIdVal
                    else
                      'trailer_id': vehicleIdVal,
                    'expense_type': selectedDocType,
                    'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                    'amount': double.tryParse(amountController.text.trim()) ?? 0.0,
                    'km_at_time': kmController.text.trim().isEmpty ? null : double.tryParse(kmController.text.trim()),
                    'payment_status': paymentStatus,
                    'provider_name': (selectedProvider == null || selectedProvider!.isEmpty) ? null : selectedProvider,
                    'maintenance_date': maintenanceDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
                  };
                  if (isEdit) {
                    if (widget.vehicleType == 'truck') {
                      await _supabaseService.updateTruckMaintenance(record['id'] as int, data);
                    } else {
                      await _supabaseService.updateTrailerMaintenance(record['id'] as int, data);
                    }
                  } else {
                    if (widget.vehicleType == 'truck') {
                      await _supabaseService.addTruckMaintenance(data);
                    } else {
                      await _supabaseService.addTrailerMaintenance(data);
                    }
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEdit ? 'تم تحديث المصروف' : 'تم إضافة المصروف')),
                  );
                  await _loadData();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المصروف'),
        content: const Text('هل أنت متأكد؟'),
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
      if (widget.vehicleType == 'truck') {
        await _supabaseService.deleteTruckMaintenance(record['id'] as int);
      } else {
        await _supabaseService.deleteTrailerMaintenance(record['id'] as int);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المصروف')));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'oil_change':
        return Icons.oil_barrel;
      case 'tires':
        return Icons.circle;
      case 'insurance':
        return Icons.shield;
      case 'technical_inspection':
        return Icons.check_circle;
      case 'depreciation':
        return Icons.trending_down;
      default:
        return Icons.receipt_long;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.expenseType} - ${_vehicleLabel ?? ''}'),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openExpenseDialog(),
              tooltip: 'إضافة مصروف',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(child: Text('لا توجد مصاريف من هذا النوع', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final record = _records[index];
                    final amount = (record['amount'] as num?)?.toDouble() ?? 0.0;
                    final dateStr = record['maintenance_date']?.toString() ?? record['created_at']?.toString() ?? '';
                    final typeLabel = record['expense_type']?.toString() ?? 'أخرى';
                    final km = (record['km_at_time'] as num?)?.toDouble();
                    final provider = record['provider_name']?.toString() ?? '';
                    final desc = record['description']?.toString() ?? '';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              leading: Icon(_typeIcon(typeLabel), color: Colors.blue),
                              title: Text(typeLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${amount.toStringAsFixed(2)} DH'),
                                  if (dateStr.isNotEmpty)
                                    Text(DateFormat('dd/MM/yyyy').format(DateTime.tryParse(dateStr) ?? DateTime.now()), textDirection: TextDirection.ltr),
                                  if (km != null) Text('${km.toStringAsFixed(0)} كم'),
                                  if (provider.isNotEmpty) Text('المزود: $provider'),
                                  if (desc.isNotEmpty) Text('ملاحظات: $desc'),
                                ],
                              ),
                            ),
                          ),
                          if (widget.isAdmin)
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _openExpenseDialog(record: record);
                                } else if (value == 'delete') {
                                  _confirmDelete(record);
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
                  },
                ),
    );
  }
}
