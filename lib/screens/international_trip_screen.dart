import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../widgets/responsive_layout.dart';

// ignore_for_file: use_build_context_synchronously

class InternationalTripScreen extends StatefulWidget {
  const InternationalTripScreen({super.key});

  @override
  State<InternationalTripScreen> createState() => _InternationalTripScreenState();
}

class _InternationalTripScreenState extends State<InternationalTripScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _trucks = [];
  List<Map<String, dynamic>> _trailers = [];
  List<Map<String, dynamic>> _clients = [];

  int? _driverId;
  int? _truckId;
  int? _trailerId;
  int? _outboundClientId;
  int? _returnClientId;

  final _advanceController = TextEditingController();
  final _outboundRouteController = TextEditingController();
  final _outboundPriceController = TextEditingController();
  final _returnRouteController = TextEditingController();
  final _returnPriceController = TextEditingController();
  final _notesController = TextEditingController();
  final _departureDateController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _departureDateController.text = _today();
  }

  @override
  void dispose() {
    _advanceController.dispose();
    _outboundRouteController.dispose();
    _outboundPriceController.dispose();
    _returnRouteController.dispose();
    _returnPriceController.dispose();
    _notesController.dispose();
    _departureDateController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadData() async {
    final drivers = await _supabaseService.getDrivers();
    final trucks = await _supabaseService.getTrucks();
    final trailers = await _supabaseService.getTrailers();
    final clients = await _supabaseService.getClients();

    if (mounted) {
      setState(() {
        _drivers = drivers;
        _trucks = trucks;
        _trailers = trailers;
        _clients = clients;
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final departureDate = _departureDateController.text.trim();
      final advanceAmount = double.tryParse(_advanceController.text.trim()) ?? 0.0;
      final outboundPrice = double.tryParse(_outboundPriceController.text.trim()) ?? 0.0;
      final returnPrice = double.tryParse(_returnPriceController.text.trim()) ?? 0.0;

      final advance = await _supabaseService.createAdvanceReturning({
        'driver_id': _driverId,
        'truck_id': _truckId,
        'trailer_id': _trailerId,
        'amount_given': advanceAmount,
        'date_out': departureDate,
        'status': 'en_route',
        'notes': _notesController.text.trim(),
      });

      if (advance == null || advance['id'] == null) {
        throw Exception('فشل في إنشاء المهمة');
      }

      final tripId = advance['id'] as int;

      await _supabaseService.addTripOrder({
        'trip_id': tripId,
        'client_id': _outboundClientId,
        'direction': 'outbound',
        'route': _outboundRouteController.text.trim(),
        'price': outboundPrice,
        'departure_date': departureDate,
        'status': 'en_route',
        'truck_id': _truckId,
        'driver_id': _driverId,
      });

      await _supabaseService.addTripOrder({
        'trip_id': tripId,
        'client_id': _returnClientId,
        'direction': 'return',
        'route': _returnRouteController.text.trim(),
        'price': returnPrice,
        'departure_date': departureDate,
        'status': 'scheduled',
        'truck_id': _truckId,
        'driver_id': _driverId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء الرحلة ومسارَي الذهاب والعودة بنجاح')),
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
      appBar: AppBar(title: const Text('إنشاء رحلة نقل دولي')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CallbackShortcuts(
              bindings: {
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter): () => _save(),
                LogicalKeySet(LogicalKeyboardKey.numpadEnter): () => _save(),
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: AppConstrained(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildMissionCard(),
                        const SizedBox(height: 16),
                        _buildOutboundCard(),
                        const SizedBox(height: 16),
                        _buildReturnCard(),
                        const SizedBox(height: 24),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildMissionCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('المهمة والأسطول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'السائق',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              initialValue: _driverId,
              items: _drivers.map((d) {
                return DropdownMenuItem<int>(
                  value: d['id'] as int?,
                  child: Text(d['name']?.toString() ?? 'بدون اسم'),
                );
              }).toList(),
              onChanged: (v) => setState(() => _driverId = v),
              validator: (v) => v == null ? 'يرجى اختيار السائق' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'الشاحنة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_shipping),
              ),
              initialValue: _truckId,
              items: _trucks.map((t) {
                final plate = t['plate']?.toString() ?? t['plate_number']?.toString() ?? 'بدون لوحة';
                return DropdownMenuItem<int>(
                  value: t['id'] as int?,
                  child: Text(plate),
                );
              }).toList(),
              onChanged: (v) => setState(() {
                _truckId = v;
                if (v != null) {
                  final defaultDriver = _drivers.firstWhere(
                    (d) => d['default_truck_id']?.toString() == v.toString(),
                    orElse: () => <String, dynamic>{},
                  );
                  if (defaultDriver.isNotEmpty) {
                    _driverId = defaultDriver['id'] as int?;
                  }
                }
              }),
              validator: (v) => v == null ? 'يرجى اختيار الشاحنة' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              decoration: const InputDecoration(
                labelText: 'المقطورة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_railway),
              ),
              initialValue: _trailerId,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('بدون مقطورة')),
                ..._trailers.map((t) {
                  return DropdownMenuItem<int?>(
                    value: t['id'] as int?,
                    child: Text(t['plate_number']?.toString() ?? 'بدون لوحة'),
                  );
                }),
              ],
              onChanged: (v) => setState(() => _trailerId = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _advanceController,
              decoration: const InputDecoration(
                labelText: 'العهدة المالية (المبلغ المسلم)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'يرجى إدخال العهدة المالية';
                final n = double.tryParse(v.trim());
                if (n == null || n <= 0) return 'يرجى إدخال مبلغ صحيح أكبر من صفر';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _departureDateController,
              decoration: const InputDecoration(
                labelText: 'تاريخ انطلاق المهمة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  _departureDateController.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutboundCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('مسار الذهاب (Outbound)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'زبون الذهاب',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              initialValue: _outboundClientId,
              items: _clients.map((c) {
                return DropdownMenuItem<int>(
                  value: c['id'] as int?,
                  child: Text(c['name']?.toString() ?? 'بدون اسم'),
                );
              }).toList(),
              onChanged: (v) => setState(() => _outboundClientId = v),
              validator: (v) => v == null ? 'يرجى اختيار زبون الذهاب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _outboundRouteController,
              decoration: const InputDecoration(
                labelText: 'المسار',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.route),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال المسار' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _outboundPriceController,
              decoration: const InputDecoration(
                labelText: 'السعر المتفق عليه',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'يرجى إدخال السعر';
                final n = double.tryParse(v.trim());
                if (n == null || n <= 0) return 'يرجى إدخال مبلغ صحيح';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('مسار العودة (Return)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'زبون العودة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              initialValue: _returnClientId,
              items: _clients.map((c) {
                return DropdownMenuItem<int>(
                  value: c['id'] as int?,
                  child: Text(c['name']?.toString() ?? 'بدون اسم'),
                );
              }).toList(),
              onChanged: (v) => setState(() => _returnClientId = v),
              validator: (v) => v == null ? 'يرجى اختيار زبون العودة' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _returnRouteController,
              decoration: const InputDecoration(
                labelText: 'المسار',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.route),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال المسار' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _returnPriceController,
              decoration: const InputDecoration(
                labelText: 'السعر المتفق عليه',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'يرجى إدخال السعر';
                final n = double.tryParse(v.trim());
                if (n == null || n <= 0) return 'يرجى إدخال مبلغ صحيح';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _save,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save),
        label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ الرحلة'),
        style: ButtonStyle(
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 14)),
        ),
      ),
    );
  }
}
