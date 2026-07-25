import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../widgets/responsive_layout.dart';

// ignore_for_file: use_build_context_synchronously

class TripFormScreen extends StatefulWidget {
  const TripFormScreen({super.key});

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _amountFocus = FocusNode();
  final _notesFocus = FocusNode();

  List<Map<String, dynamic>> _drivers = [];
  int? _selectedDriverId;
  bool _isLoadingDrivers = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _amountFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadDrivers() async {
    final drivers = await _supabaseService.getDrivers();
    if (mounted) {
      setState(() {
        _drivers = drivers;
        if (drivers.isNotEmpty) _selectedDriverId = drivers.first['id'] as int?;
        _isLoadingDrivers = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDriverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار السائق')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال مبلغ صحيح أكبر من صفر')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _supabaseService.addAdvance({
        'driver_id': _selectedDriverId,
        'amount_given': amount,
        'date_out': _today(),
        'status': 'en_route',
        'notes': _notesController.text.trim(),
      });
      final driverName = _drivers
          .where((d) => d['id'] == _selectedDriverId)
          .map((d) => d['name']?.toString() ?? 'بدون اسم')
          .firstOrNull ?? 'بدون اسم';
      await _supabaseService.notifyAdmins(
        title: 'عهدة جديدة',
        message: 'أضافت السكرتيرة عهدة للسائق $driverName',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تأكيد السفر وحفظ العهدة بنجاح')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الحفظ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسليم عهدة وتأكيد سفر')),
      body: _isLoadingDrivers
          ? const Center(child: CircularProgressIndicator())
          : CallbackShortcuts(
              bindings: {
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter):
                    () => _save(),
                LogicalKeySet(LogicalKeyboardKey.numpadEnter): () => _save(),
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AppConstrained(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'السائق',
                            border: OutlineInputBorder(),
                          ),
                          initialValue: _selectedDriverId,
                          items: _drivers
                              .toList()
                              .sorted((a, b) => (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''))
                              .map((d) => DropdownMenuItem<int>(
                                    value: d['id'] as int?,
                                    child: Text(d['name']?.toString() ?? 'بدون اسم'),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() => _selectedDriverId = value);
                            _amountFocus.requestFocus();
                          },
                          validator: (value) =>
                              value == null ? 'يرجى اختيار السائق' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountController,
                          focusNode: _amountFocus,
                          decoration: const InputDecoration(
                            labelText: 'المبلغ المسلم',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _notesFocus.requestFocus(),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال المبلغ';
                            }
                            final parsed = double.tryParse(value.trim());
                            if (parsed == null || parsed <= 0) {
                              return 'يرجى إدخال مبلغ صحيح أكبر من صفر';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _notesController,
                          focusNode: _notesFocus,
                          decoration: const InputDecoration(
                            labelText: 'الملاحظات',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 4,
                        ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle),
                        label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ وتأكيد السفر'),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ),
          ),
    );
  }
}
