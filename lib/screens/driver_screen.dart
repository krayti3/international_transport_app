import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:collection/collection.dart';
import '../services/supabase_service.dart';
import '../widgets/responsive_layout.dart';
import '../l10n/app_localizations.dart';

// ignore_for_file: use_build_context_synchronously

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _advances = [];
  int? _selectedDriverId;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    final drivers = await _supabaseService.getDrivers();
    final authUserId = Supabase.instance.client.auth.currentUser?.id;
    int? myDriverId;
    
    if (authUserId != null) {
      for (final d in drivers) {
        if (d['user_id']?.toString() == authUserId.toString()) {
          myDriverId = d['id'] as int?;
          break;
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _drivers = drivers;
        _selectedDriverId = myDriverId;
      });
    }
    await _loadAdvances();
  }

  Future<void> _loadAdvances() async {
    if (_selectedDriverId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    final all = await _supabaseService.getAdvances();
    final mine = all
        .where((a) => (a['driver_id'] as int?) == _selectedDriverId)
        .toList();
    if (mounted) {
      setState(() {
        _advances = mine;
        _isLoading = false;
      });
    }
  }

  List<String> _imagesFrom(Map<String, dynamic> map) {
    final raw = map['receipts_images'];
    if (raw is List) {
      return raw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  Future<void> _captureAndAttach(Map<String, dynamic> advance) async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await _supabaseService.uploadReceipt(picked.name, bytes);
      final images = _imagesFrom(advance)..add(url);
      await _supabaseService.updateAdvance(advance['id'], {
        'receipts_images': images,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('تم إرسال الفاتورة بنجاح'))),
      );
      await _loadAdvances();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('تعذّر إرسال الفاتورة: {0}', [e]))),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('رحلاتي وعُهدي'))),
      body: Column(
        children: [
          if (_selectedDriverId != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('رحلاتك المعينة لك'),
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            )
          else if (_selectedDriverId == null && _drivers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  labelText: context.tr('اختر السائق'),
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                initialValue: _selectedDriverId,
                items: _drivers
                    .toList()
                    .sorted((a, b) => (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''))
                    .map((d) => DropdownMenuItem<int>(
                          value: d['id'] as int?,
                          child: Text(d['name']?.toString() ?? context.tr('بدون اسم')),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedDriverId = value);
                    _loadAdvances();
                  }
                },
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _advances.isEmpty
                    ? Center(child: Text(context.tr('لا توجد عُهد مسجلة عليك حالياً')))
                    : RefreshIndicator(
                        onRefresh: _loadAdvances,
                        child: AppConstrained(
                          padding: const EdgeInsets.all(12),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _advances.length,
                          itemBuilder: (context, index) {
                            final advance = _advances[index];
                            final status = advance['status']?.toString() ?? 'pending';
                            final given = (advance['amount_given'] as num?)?.toDouble() ?? 0.0;
                            final spent = (advance['amount_spent'] as num?)?.toDouble();
                            final returned = (advance['amount_returned'] as num?)?.toDouble();
                            final images = _imagesFrom(advance);

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
                                        Text(
                                          context.tr('عهدة #{0}', [advance['id'] ?? '?']),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Chip(
                                          label: Text(
                                            status == 'settled' ? context.tr('تم التسوية') : context.tr('جارية'),
                                          ),
                                          backgroundColor: status == 'settled'
                                              ? Colors.green.withValues(alpha: 0.15)
                                              : Colors.orange.withValues(alpha: 0.15),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(context.tr('تاريخ الانطلاق: {0}', [advance['date_out'] ?? ''])),
                                    const SizedBox(height: 4),
                                      Text(
                                        context.tr('المبلغ المسلم: {0} DH', [given.toStringAsFixed(2)]),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    if (spent != null) ...[
                                      const SizedBox(height: 4),
                                      Text(context.tr('المصاريف: {0} DH', [spent.toStringAsFixed(2)])),
                                      const SizedBox(height: 4),
                                      Text(
                                        context.tr('المتبقي: {0} DH', [returned != null ? returned.toStringAsFixed(2) : '0.00']),
                                        style: const TextStyle(color: Colors.green),
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
                                                  label: Text(context.tr('فاتورة')),
                                                  onPressed: () => showDialog(
                                                    context: context,
                                                    builder: (_) => AlertDialog(
                                                      title: Text(context.tr('صورة الفاتورة')),
                                                      content: Image.network(url,
                                                          errorBuilder: (_, _, _) =>
                                                              Text(context.tr('تعذّر التحميل'))),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context),
                                                          child: Text(context.tr('إغلاق')),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ))
                                            .toList(),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    if (status != 'settled')
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _isUploading
                                              ? null
                                              : () => _captureAndAttach(advance),
                                          icon: _isUploading
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              : const Icon(Icons.camera_alt),
                                          label: Text(_isUploading ? 'جاري الإرسال...' : 'تصوير وإرسال فاتورة'),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
          ),
        ],
      ),
    );
  }
}
