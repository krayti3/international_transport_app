import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/responsive_layout.dart';

// ignore_for_file: use_build_context_synchronously

class CurrentTripsScreen extends StatefulWidget {
  const CurrentTripsScreen({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  State<CurrentTripsScreen> createState() => _CurrentTripsScreenState();
}

class _CurrentTripsScreenState extends State<CurrentTripsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _trips = [];
  final Map<int, String> _driverNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final trips = await _supabaseService.getAdvances();
    final drivers = await _supabaseService.getDrivers();
    _driverNames.clear();
    for (final driver in drivers) {
      final id = driver['id'] as int?;
      if (id != null) _driverNames[id] = driver['name']?.toString() ?? 'بدون اسم';
    }
    if (mounted) {
      setState(() {
        _trips = trips
            .where((t) => (t['status']?.toString() ?? '') == 'en_route')
            .toList();
        _isLoading = false;
      });
    }
  }

  String _driverName(int? driverId) =>
      driverId != null ? (_driverNames[driverId] ?? 'بدون سائق') : 'بدون سائق';

  List<String> _imagesFrom(Map<String, dynamic> map) {
    final raw = map['receipts_images'];
    if (raw is List) {
      return raw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  Future<void> _openCloseDialog(Map<String, dynamic> trip) async {
    final given = (trip['amount_given'] as num?)?.toDouble() ?? 0.0;
    final spentController = TextEditingController();
    double returned = given;
    bool isSubmitting = false;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            final spent = double.tryParse(spentController.text.trim());
            if (spent == null || spent < 0 || spent > given) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('يرجى إدخال مصاريف صحيحة لا تتجاوز المبلغ المسلم'),
                ),
              );
              return;
            }
            setDialogState(() => isSubmitting = true);
            try {
              final id = trip['id'];
              await _supabaseService.updateAdvance(id, {
                'amount_spent': spent,
                'amount_returned': (given - spent).clamp(0.0, given),
                'date_return': _today(),
                'status': 'settled',
              });
              await _supabaseService.notifyAdmins(
                title: 'تسوية عهدة',
                message: 'قامت السكرتيرة بتسوية عهدة السائق ${_driverName(trip['driver_id'] as int?)}',
              );
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('تم إغلاق الرحلة وتصفية الحساب'),
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: 'تراجع',
                    onPressed: () async {
                      try {
                        await _supabaseService.updateAdvance(id, {
                          'amount_spent': null,
                          'amount_returned': null,
                          'date_return': null,
                          'status': 'en_route',
                        });
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
            } catch (e) {
              if (!mounted) return;
              setDialogState(() => isSubmitting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('خطأ في الإغلاق: $e')),
              );
            }
          }

          return AlertDialog(
            title: const Text('إغلاق الرحلة وتصفية الحساب'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('السائق: ${_driverName(trip['driver_id'] as int?)}'),
                    const SizedBox(height: 4),
                    Text(
                      'المبلغ المسلم: ${given.toStringAsFixed(2)} DH',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: spentController,
                      decoration: const InputDecoration(
                        labelText: 'المصاريف الفعلية',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => submit(),
                      onChanged: (_) {
                        final spent = double.tryParse(spentController.text.trim()) ?? 0.0;
                        setDialogState(() => returned = (given - spent).clamp(0.0, given));
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('المبلغ المتبقي (المسلم - المصاريف):',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            '${returned.toStringAsFixed(2)} DH',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : submit,
                child: isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('إغلاق الرحلة وتصفية الحساب'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الرحلات الجارية حالياً')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? const Center(child: Text('لا توجد رحلات جارية حالياً'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: AppConstrained(
                    padding: const EdgeInsets.all(12),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _trips.length,
                    itemBuilder: (context, index) {
                      final trip = _trips[index];
                      final given = (trip['amount_given'] as num?)?.toDouble() ?? 0.0;
                      final images = _imagesFrom(trip);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: InkWell(
                          onTap: () => _openCloseDialog(trip),
                          borderRadius: BorderRadius.circular(12),
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
                                        _driverName(trip['driver_id'] as int?),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    const Chip(
                                      label: Text('في الطريق'),
                                      backgroundColor: Colors.orange,
                                      labelStyle: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('تاريخ الانطلاق: ${trip['date_out'] ?? ''}'),
                                const SizedBox(height: 4),
                                Text(
                                  'المبلغ المسلم: ${given.toStringAsFixed(2)} DH',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                if ((trip['notes']?.toString() ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'ملاحظات: ${trip['notes']}',
                                    style: const TextStyle(
                                        fontStyle: FontStyle.italic, color: Colors.grey),
                                  ),
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
                                              onPressed: () => showDialog(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  title: const Text('صورة الفاتورة'),
                                                  content: Image.network(url,
                                                      errorBuilder: (_, _, _) =>
                                                          const Text('تعذّر التحميل')),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: const Text('إغلاق'),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'اضغط لإغلاق الرحلة وتصفية الحساب',
                                    style: TextStyle(color: Colors.blue, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
    );
  }
}
