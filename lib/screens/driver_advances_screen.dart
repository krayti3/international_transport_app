import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../services/supabase_service.dart';

// ignore_for_file: use_build_context_synchronously

class DriverAdvancesScreen extends StatefulWidget {
  final bool isAdmin;
  final int driverId;

  const DriverAdvancesScreen({super.key, required this.isAdmin, required this.driverId});

  @override
  State<DriverAdvancesScreen> createState() => _DriverAdvancesScreenState();
}

class _DriverAdvancesScreenState extends State<DriverAdvancesScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _advances = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _cashBoxes = [];

  static const _statusOptions = {
    'pending': 'معلق',
    'en_route': 'في الطريق',
    'settled': 'تم التسوية',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCashBoxes();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final advances = await _supabaseService.getAdvancesByDriver(widget.driverId);
    if (!mounted) return;
    setState(() {
      _advances = advances;
      _isLoading = false;
    });
  }

  Future<void> _loadCashBoxes() async {
    final boxes = await _supabaseService.getCashBoxes();
    if (!mounted) return;
    setState(() {
      _cashBoxes = boxes;
    });
  }

  Color _statusColor(String? status) =>
      status == 'settled' ? Colors.green : Colors.orange;

  String _statusLabel(String? status) =>
      _statusOptions[status] ?? status ?? 'معلق';

  Future<void> _openAdvanceDialog({Map<String, dynamic>? advance}) async {
    final isEdit = advance != null;
    final amountGivenController = TextEditingController(
      text: advance != null ? (advance['amount_given'] as num?)?.toString() ?? '' : '',
    );
    final dateOutController = TextEditingController(
      text: advance?['date_out']?.toString() ?? DateFormat('dd/MM/yyyy').format(DateTime.now()),
    );
    String status = advance?['status']?.toString() ?? 'en_route';
    final amountSpentController = TextEditingController(
      text: advance != null ? (advance['amount_spent'] as num?)?.toString() ?? '' : '',
    );
    final dateReturnController = TextEditingController(
      text: advance?['date_return']?.toString() ?? '',
    );
    final notesController = TextEditingController(
      text: advance?['notes']?.toString() ?? '',
    );
    String? sourceCashBox = advance?['source_cash_box']?.toString();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'تعديل العهدة' : 'تسجيل عهدة جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amountGivenController,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المسلم',
                    suffixText: 'DH',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: dateOutController,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'تاريخ الانطلاق'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'الحالة'),
                  initialValue: status,
                  items: _statusOptions.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => status = v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountSpentController,
                  decoration: const InputDecoration(
                    labelText: 'المصاريف الفعلية',
                    suffixText: 'DH',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: dateReturnController,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'تاريخ العودة'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'الملاحظات'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: sourceCashBox,
                  decoration: const InputDecoration(
                    labelText: 'مصدر العهدة (الصندوق)',
                  ),
                  items: _cashBoxes.isEmpty
                      ? null
                      : _cashBoxes.map((b) {
                          return DropdownMenuItem(
                            value: b['code']?.toString(),
                            child: Text(b['label']?.toString() ?? ''),
                          );
                        }).toList(),
                  onChanged: (v) {
                    setDialogState(() => sourceCashBox = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'driver_id': widget.driverId,
                  'amount_given': double.tryParse(amountGivenController.text.trim()) ?? 0.0,
                  'date_out': dateOutController.text.trim(),
                  'status': status,
                  'amount_spent': double.tryParse(amountSpentController.text.trim()),
                  'date_return': dateReturnController.text.trim().isEmpty ? null : dateReturnController.text.trim(),
                  'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  'source_cash_box': sourceCashBox,
                };
                try {
                  if (isEdit) {
                    await _supabaseService.updateAdvance(advance['id'] as int, data);
                  } else {
                    await _supabaseService.addAdvance(data);
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEdit ? 'تم تحديث العهدة' : 'تمت إضافة العهدة')),
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
              },
              child: Text(isEdit ? 'حفظ' : 'إضافة'),
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
      await _supabaseService.deleteAdvance(advance['id'] as int);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف العهدة')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settled = _advances.where((a) => (a['status']?.toString() ?? '') == 'settled').toList();
    final isSmall = MediaQuery.of(context).size.width < 400;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('عهد السائق'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'الكل'),
              Tab(text: 'تم التسوية'),
            ],
          ),
          actions: [
            if (widget.isAdmin)
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _openAdvanceDialog(),
                tooltip: 'تسجيل عهدة',
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildList(_advances, isDark, isSmall: isSmall),
                  _buildList(settled, isDark, isSmall: isSmall),
                ],
              ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> advances, bool isDark, {bool isSmall = false}) {
    final padding = isSmall ? 10.0 : 12.0;
    final cardPadding = isSmall ? 12.0 : 14.0;
    final amountFont = isSmall ? 16.0 : 18.0;
    final statusFont = isSmall ? 11.0 : 12.0;
    final iconSize = isSmall ? 13.0 : 14.0;
    final detailFont = isSmall ? 12.0 : 13.0;

    if (advances.isEmpty) {
      return Center(child: Text('لا توجد عهود', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: isSmall ? 14 : null)));
    }
    return ListView.builder(
      padding: EdgeInsets.all(padding),
      itemCount: advances.length,
      itemBuilder: (context, index) {
        final advance = advances[index];
        final given = (advance['amount_given'] as num?)?.toDouble() ?? 0.0;
        final spent = (advance['amount_spent'] as num?)?.toDouble() ?? 0.0;
        final dateOut = advance['date_out']?.toString() ?? '';
        final dateReturn = advance['date_return']?.toString() ?? '';
        final status = advance['status']?.toString() ?? 'pending';
        final notes = advance['notes']?.toString() ?? '';
        final returned = advance['amount_returned'] as num?;
        final remaining = given - spent - (returned ?? 0.0);

        return Card(
          margin: EdgeInsets.symmetric(vertical: isSmall ? 4 : 6),
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isSmall ? 10 : 12),
            side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
          ),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${given.toStringAsFixed(2)} DH',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: amountFont, color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 10, vertical: isSmall ? 3 : 4),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(isSmall ? 6 : 8),
                      ),
                      child: Text(_statusLabel(status), style: TextStyle(fontSize: statusFont, color: _statusColor(status), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                SizedBox(height: isSmall ? 6 : 8),
                Row(
                  children: [
                    Icon(Icons.login, size: iconSize, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    SizedBox(width: isSmall ? 3 : 4),
                    Text('انطلاق: $dateOut', style: TextStyle(fontSize: detailFont, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                  ],
                ),
                if (dateReturn.isNotEmpty) ...[
                  SizedBox(height: isSmall ? 3 : 4),
                  Row(
                    children: [
                      Icon(Icons.exit_to_app, size: iconSize, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      SizedBox(width: isSmall ? 3 : 4),
                      Text('عودة: $dateReturn', style: TextStyle(fontSize: detailFont, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                    ],
                  ),
                ],
                if (spent > 0) ...[
                  SizedBox(height: isSmall ? 3 : 4),
                  Row(
                    children: [
                      Icon(Icons.receipt_long, size: iconSize, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      SizedBox(width: isSmall ? 3 : 4),
                      Text('مصروف: ${spent.toStringAsFixed(2)} DH', style: TextStyle(fontSize: detailFont, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                    ],
                  ),
                ],
                if (returned != null) ...[
                  SizedBox(height: isSmall ? 3 : 4),
                  Row(
                    children: [
                      Icon(Icons.money, size: iconSize, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      SizedBox(width: isSmall ? 3 : 4),
                      Text('مرتجع: ${returned.toDouble().toStringAsFixed(2)} DH', style: TextStyle(fontSize: detailFont, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                    ],
                  ),
                ],
                if (remaining != 0) ...[
                  SizedBox(height: isSmall ? 3 : 4),
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, size: iconSize, color: remaining > 0 ? Colors.green : Colors.red),
                      SizedBox(width: isSmall ? 3 : 4),
                      Text('الباقي: ${remaining.toStringAsFixed(2)} DH', style: TextStyle(fontSize: detailFont, color: remaining > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
                if (notes.isNotEmpty) ...[
                  SizedBox(height: isSmall ? 4 : 6),
                  Container(
                    padding: EdgeInsets.all(isSmall ? 6 : 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(isSmall ? 6 : 8),
                    ),
                    child: Text(notes, style: TextStyle(fontSize: detailFont, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                  ),
                ],
                if (widget.isAdmin) ...[
                  SizedBox(height: isSmall ? 8 : 10),
                  const Divider(height: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: status != 'settled'
                            ? () async {
                                await _supabaseService.updateAdvance(advance['id'] as int, {'status': 'settled'});
                                await _loadData();
                              }
                            : null,
                        icon: Icon(Icons.check_circle, size: iconSize),
                        label: const Text('تسوية'),
                      ),
                      TextButton.icon(
                        onPressed: () => _openAdvanceDialog(advance: advance),
                        icon: Icon(Icons.edit, size: iconSize),
                        label: const Text('تعديل'),
                      ),
                      TextButton.icon(
                        onPressed: () => _confirmDelete(advance),
                        icon: Icon(Icons.delete, size: iconSize, color: Colors.red),
                        label: const Text('حذف', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
