import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

// ignore_for_file: use_build_context_synchronously

class AdvancesScreen extends StatefulWidget {
  const AdvancesScreen({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  State<AdvancesScreen> createState() => _AdvancesScreenState();
}

class _AdvancesScreenState extends State<AdvancesScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _advances = [];
  List<Map<String, dynamic>> _drivers = [];
  final Map<int, String> _driverNames = {};
  bool _isLoading = true;
  String _currentFilter = 'all'; // all, pending, settled

  static const _statusOptions = {
    'pending': 'معلق',
    'en_route': 'في الطريق',
    'settled': 'تم التسوية',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final advances = await _supabaseService.getAdvances();
    final drivers = await _supabaseService.getDrivers();
    _driverNames.clear();
    for (final driver in drivers) {
      final id = driver['id'] as int?;
      if (id != null) _driverNames[id] = driver['name']?.toString() ?? 'بدون اسم';
    }
    setState(() {
      _advances = advances;
      _drivers = drivers;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredAdvances {
    if (_currentFilter == 'all') return _advances;
    if (_currentFilter == 'pending') {
      return _advances
          .where((a) => (a['status']?.toString() ?? 'pending') != 'settled')
          .toList();
    }
    return _advances.where((a) => (a['status']?.toString() ?? 'pending') == _currentFilter).toList();
  }

  String _driverName(int? driverId) =>
      driverId != null ? (_driverNames[driverId] ?? 'بدون سائق') : 'بدون سائق';

  double _sumPending() {
    double total = 0.0;
    for (final a in _advances) {
      if ((a['status']?.toString() ?? 'pending') != 'settled') {
        total += (a['amount_given'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return total;
  }

  double _sumOutstanding() {
    double total = 0.0;
    for (final a in _advances) {
      final given = (a['amount_given'] as num?)?.toDouble() ?? 0.0;
      final returned = (a['amount_returned'] as num?)?.toDouble() ?? 0.0;
      if ((a['status']?.toString() ?? 'pending') != 'settled') {
        total += given - returned;
      }
    }
    return total;
  }

  Color _statusColor(String? status) =>
      status == 'settled' ? Colors.green : Colors.orange;

  String _statusLabel(String? status) => _statusOptions[status] ?? 'معلق';

  Future<void> _openAdvanceDialog({Map<String, dynamic>? advance}) async {
    final isEdit = advance != null;
    final drivers = _drivers;

    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة سائق أولاً')),
      );
      return;
    }

    int? selectedDriverId = advance != null
        ? (advance['driver_id'] as int?)
        : (drivers.first['id'] as int?);
    final amountGivenController = TextEditingController(
      text: advance != null ? (advance['amount_given'] as num?)?.toString() ?? '' : '',
    );
    final dateOutController = TextEditingController(
      text: advance?['date_out']?.toString() ?? _today(),
    );
    String status = advance?['status']?.toString() ?? 'en_route';
    final amountSpentController = TextEditingController(
      text: advance != null ? (advance['amount_spent'] as num?)?.toString() ?? '' : '',
    );
    final dateReturnController = TextEditingController(
      text: advance?['date_return']?.toString() ?? _today(),
    );
    final receipts = List<String>.from(
      advance != null ? _imagesFromMap(advance) : [],
    );
    final receiptController = TextEditingController();
    final notesController = TextEditingController(
      text: advance?['notes']?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'تعديل العهدة' : 'تسليم عهدة جديدة'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'السائق'),
                    initialValue: selectedDriverId,
                    items: drivers
                        .map((d) => DropdownMenuItem<int>(
                              value: d['id'] as int?,
                              child: Text(d['name']?.toString() ?? 'بدون اسم'),
                            ))
                        .toList(),
                    onChanged: (value) => setDialogState(() => selectedDriverId = value),
                    validator: (v) => v == null ? 'يرجى اختيار السائق' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountGivenController,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المسلم',
                      suffixText: 'DH',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'يرجى إدخال المبلغ المسلم';
                      final p = double.tryParse(v.trim());
                      if (p == null) return 'يرجى إدخال أرقام فقط';
                      if (p <= 0) return 'يرجى إدخال مبلغ أكبر من صفر';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dateOutController,
                    decoration: const InputDecoration(labelText: 'تاريخ الانطلاق'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'يرجى إدخال التاريخ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'الحالة'),
                    initialValue: status,
                    items: _statusOptions.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => status = value);
                    },
                    validator: (v) => v == null || v.isEmpty ? 'يرجى اختيار الحالة' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountSpentController,
                    decoration: const InputDecoration(
                      labelText: 'المصاريف الفعلية',
                      suffixText: 'DH',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null; // optional
                      final p = double.tryParse(v.trim());
                      if (p == null) return 'يرجى إدخال أرقام فقط';
                      if (p < 0) return 'لا يمكن أن يكون المبلغ سالباً';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dateReturnController,
                    decoration: const InputDecoration(labelText: 'تاريخ العودة'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'الملاحظات'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('روابط صور الفواتير', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: receipts
                        .map((url) => Chip(
                              label: const Text('صورة فاتورة'),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => setDialogState(() => receipts.remove(url)),
                            ))
                        .toList(),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: receiptController,
                          decoration: const InputDecoration(labelText: 'أضف رابط صورة'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          final url = receiptController.text.trim();
                          if (url.isNotEmpty) {
                            setDialogState(() {
                              receipts.add(url);
                              receiptController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final given = double.tryParse(amountGivenController.text.trim()) ?? 0.0;
                final spent = amountSpentController.text.trim().isEmpty
                    ? null
                    : double.tryParse(amountSpentController.text.trim());
                final returned = spent != null ? (given - spent).clamp(0.0, given) : null;
                final data = {
                  'driver_id': selectedDriverId,
                  'amount_given': given,
                  'date_out': dateOutController.text.trim(),
                  'status': status,
                  'amount_spent': spent,
                  'amount_returned': returned,
                  'receipts_images': receipts,
                  'date_return': dateReturnController.text.trim().isEmpty
                      ? null
                      : dateReturnController.text.trim(),
                  'notes': notesController.text.trim(),
                };
                try {
                  if (isEdit) {
                    final id = advance['id'];
                    final previous = <String, dynamic>{
                      'driver_id': advance['driver_id'],
                      'amount_given': advance['amount_given'],
                      'date_out': advance['date_out'],
                      'status': advance['status'],
                      'amount_spent': advance['amount_spent'],
                      'amount_returned': advance['amount_returned'],
                      'receipts_images': advance['receipts_images'],
                      'date_return': advance['date_return'],
                      'notes': advance['notes'],
                    };
                    await _supabaseService.updateAdvance(id, data);
                    await _supabaseService.syncAdvanceTreasury(id);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('تم حفظ التعديلات'),
                        duration: const Duration(seconds: 5),
                        action: SnackBarAction(
                          label: 'تراجع',
                          onPressed: () async {
                            try {
                              await _supabaseService.updateAdvance(id, previous);
                              if (mounted) await _loadData();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('تعذّر التراجع: $e')),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    );
                    await _loadData();
                  } else {
                    final created = await _supabaseService.createAdvanceReturning(data);
                    if (created != null && created['id'] != null) {
                      await _supabaseService.syncAdvanceTreasury(created['id'] as int);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    await _loadData();
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

  Future<void> _confirmDelete(Map<String, dynamic> advance) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف العهدة'),
        content: const Text('هل أنت متأكد من حذف هذه العهدة؟'),
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
      final id = advance['id'];
      await _supabaseService.deleteAdvance(id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم حذف العهدة'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'تراجع',
              onPressed: () async {
                try {
                  await _supabaseService.restoreAdvance(id);
                  if (mounted) await _loadData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تعذّر التراجع: $e')),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _openSettleDialog(Map<String, dynamic> advance) async {
    final given = (advance['amount_given'] as num?)?.toDouble() ?? 0.0;
    final spentController = TextEditingController();
    final dateReturnController = TextEditingController(text: _today());
    final receipts = List<String>.from(_imagesFromMap(advance));
    final receiptController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تسوية العهدة'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('المبلغ المسلم: ${NumberFormat('#,###.00').format(given)} DH'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: spentController,
                    decoration: const InputDecoration(
                      labelText: 'المصاريف الفعلية',
                      suffixText: 'DH',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'يرجى إدخال المصاريف';
                      final p = double.tryParse(v.trim());
                      if (p == null) return 'يرجى إدخال أرقام فقط';
                      if (p < 0) return 'لا يمكن أن يكون المبلغ سالباً';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dateReturnController,
                    decoration: const InputDecoration(labelText: 'تاريخ العودة'),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('روابط صور الفواتير', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: receipts
                        .map((url) => Chip(
                              label: const Text('صورة فاتورة'),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => setDialogState(() => receipts.remove(url)),
                            ))
                        .toList(),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: receiptController,
                          decoration: const InputDecoration(labelText: 'أضف رابط صورة'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          final url = receiptController.text.trim();
                          if (url.isNotEmpty) {
                            setDialogState(() {
                              receipts.add(url);
                              receiptController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (spentController.text.isNotEmpty)
                    Builder(
                      builder: (ctx) {
                        final s = double.tryParse(spentController.text) ?? 0.0;
                        if (s <= given) {
                          return Text(
                            'المبلغ المرجع المتوقع: ${NumberFormat('#,###.00').format((given - s).clamp(0.0, given))} DH',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          );
                        }
                        return Text(
                          'المبلغ المستحق على الشركة: ${NumberFormat('#,###.00').format((s - given))} DH',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.red),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final spent = double.tryParse(spentController.text.trim()) ?? 0.0;
                final data = {
                  'amount_spent': spent,
                  'amount_returned': (given - spent).clamp(0.0, given),
                  'date_return': dateReturnController.text.trim(),
                  'receipts_images': receipts,
                  'status': 'settled',
                };
                try {
                  await _supabaseService.updateAdvance(advance['id'], data);
                  await _supabaseService.syncAdvanceTreasury(advance['id']);
                  await _supabaseService.notifyAdmins(
                    title: 'تسوية عهدة',
                    message:
                        'قامت السكرتيرة بتسوية عهدة السائق ${_driverName(advance['driver_id'] as int?)}',
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  await _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تسوية العهدة بنجاح')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ في التسوية: $e')),
                  );
                }
              },
              child: const Text('تسوية'),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _imagesFromMap(Map<String, dynamic> map) {
    final raw = map['receipts_images'];
    if (raw is List) {
      return raw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final pendingTotal = _sumPending();
    final outstanding = _sumOutstanding();
    final currencyFmt = NumberFormat('#,###.00');

    return Scaffold(
      appBar: AppBar(title: const Text('العُهد (الرحلات)')),
      body: Column(
        children: [
          // Summary cards
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'عهدة معلقة',
                    value: currencyFmt.format(pendingTotal),
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'مبلغ غير مسوى',
                    value: currencyFmt.format(outstanding),
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _FilterChip(
                  label: 'الكل',
                  isSelected: _currentFilter == 'all',
                  onTap: () => setState(() => _currentFilter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'معلق',
                  isSelected: _currentFilter == 'pending',
                  onTap: () => setState(() => _currentFilter = 'pending'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'تم التسوية',
                  isSelected: _currentFilter == 'settled',
                  onTap: () => setState(() => _currentFilter = 'settled'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Advances list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAdvances.isEmpty
                    ? const Center(child: Text('لا يوجد عُهد لعرضها'))
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredAdvances.length,
                          itemBuilder: (context, index) {
                            final advance = _filteredAdvances[index];
                            final status = advance['status']?.toString() ?? 'pending';
                            final given = (advance['amount_given'] as num?)?.toDouble() ?? 0.0;
                            final spent = (advance['amount_spent'] as num?)?.toDouble();
                            final returned = (advance['amount_returned'] as num?)?.toDouble();
                            final images = _imagesFromMap(advance);

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _driverName(advance['driver_id'] as int?),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _statusColor(status).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: _statusColor(status)),
                                          ),
                                          child: Text(
                                            _statusLabel(status),
                                            style: TextStyle(
                                              color: _statusColor(status),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text('تاريخ الانطلاق: ${advance['date_out'] ?? ''}'),
                                    const SizedBox(height: 4),
                                    Text(
                                      'المبلغ المسلم: ${currencyFmt.format(given)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    if (spent != null) ...[
                                      const SizedBox(height: 4),
                                      Text('المصاريف الفعلية: ${currencyFmt.format(spent)}'),
                                      const SizedBox(height: 4),
                                      Text(
                                        'المبلغ المرجع: ${returned != null ? currencyFmt.format(returned) : '0.00'}',
                                        style: const TextStyle(color: Colors.green),
                                      ),
                                      if (advance['date_return'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text('تاريخ العودة: ${advance['date_return']}'),
                                      ],
                                    ],
                                    if (images.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: images
                                            .map((url) => ActionChip(
                                                  avatar: const Icon(Icons.image, size: 16),
                                                  label: const Text('فاتورة'),
                                                  onPressed: () => _openImage(context, url),
                                                ))
                                            .toList(),
                                      ),
                                    ],
                                    if ((advance['notes']?.toString() ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'ملاحظات: ${advance['notes']}',
                                        style: const TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (status != 'settled')
                                          TextButton.icon(
                                            icon: const Icon(Icons.check_circle),
                                            label: const Text('تسوية'),
                                            onPressed: () => _openSettleDialog(advance),
                                          ),
                                        if (widget.isAdmin) ...[
                                          TextButton.icon(
                                            icon: const Icon(Icons.edit),
                                            label: const Text('تعديل'),
                                            onPressed: () => _openAdvanceDialog(advance: advance),
                                          ),
                                          TextButton.icon(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            label: const Text('حذف'),
                                            onPressed: () => _confirmDelete(advance),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openAdvanceDialog(),
              icon: const Icon(Icons.add),
              label: const Text('تسليم عهدة'),
            )
          : null,
    );
  }

  void _openImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('صورة الفاتورة'),
        content: Image.network(url, errorBuilder: (_, _, _) => const Text('تعذّر تحميل الصورة')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }
}
