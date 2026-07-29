import 'package:flutter/material.dart';
import '../services/workshop_service.dart';
import '../widgets/date_wheel_picker.dart';

// ignore_for_file: use_build_context_synchronously

class DebtInvoiceFormScreen extends StatefulWidget {
  final String? workshopId;
  final String? workshopName;

  const DebtInvoiceFormScreen({
    super.key,
    this.workshopId,
    this.workshopName,
  });

  @override
  State<DebtInvoiceFormScreen> createState() =>
      _DebtInvoiceFormScreenState();
}

class _DebtInvoiceFormScreenState extends State<DebtInvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumberController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _vehicleIdController = TextEditingController();
  String _vehicleType = 'truck';
  String _expenseType = 'oil_change';
  DateTime? _date;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _providers = [];
  List<String> _expenseTypes = [];
  String? _selectedProviderId;
  String? _selectedProviderName;
  final WorkshopService _workshopService = WorkshopService();

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _invoiceNumberController.text =
        'INV-DEBT-${DateTime.now().millisecondsSinceEpoch % 10000}';
    _loadOptions();
    if (widget.workshopId != null && widget.workshopId!.isNotEmpty) {
      _selectedProviderId = widget.workshopId;
      _selectedProviderName = widget.workshopName;
    }
  }

  Future<void> _loadOptions() async {
    final providers = await _workshopService.getProviders();
    final types = await _workshopService.getExpenseTypes();
    if (!mounted) return;
    setState(() {
      _providers = providers;
      _expenseTypes = types.isNotEmpty ? types : ['oil_change', 'tires', 'insurance', 'technical_inspection', 'depreciation', 'other'];
      if (_expenseTypes.contains('oil_change')) {
        _expenseType = 'oil_change';
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDateWheelPicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProviderId == null || _selectedProviderId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الورشة')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final amount = double.parse(_amountController.text.trim());
      final invoiceId = await _workshopService.insertDebtInvoice(
        workshopId: _selectedProviderId!,
        vehicleType: _vehicleType,
        vehicleId: _vehicleIdController.text.trim(),
        expenseType: _expenseType,
        amount: amount,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        date: _date,
        invoiceNumber: _invoiceNumberController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إنشاء فاتورة الدين رقم ${_invoiceNumberController.text.trim()} بنجاح')),
      );
      Navigator.pop(context, invoiceId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة دين جديدة'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _invoiceNumberController,
              decoration: const InputDecoration(
                labelText: 'رقم الفاتورة',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'أدخل رقم الفاتورة';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedProviderName,
              decoration: const InputDecoration(
                labelText: 'الورشة',
                border: OutlineInputBorder(),
              ),
              items: _providers
                  .map((p) => DropdownMenuItem<String>(
                        value: p['name']?.toString(),
                        child: Text(p['name']?.toString() ?? ''),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedProviderName = v;
                  final match = _providers.firstWhere(
                    (p) => p['name']?.toString() == v,
                    orElse: () => <String, dynamic>{},
                  );
                  _selectedProviderId = match['id']?.toString();
                });
              },
              validator: (v) {
                if (v == null || v.isEmpty) return 'يرجى اختيار الورشة';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _vehicleType,
              decoration: const InputDecoration(
                labelText: 'نوع المركبة',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'truck', child: Text('شاحنة')),
                DropdownMenuItem(value: 'trailer', child: Text('مقطورة')),
              ],
              onChanged: (v) => setState(() => _vehicleType = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vehicleIdController,
              decoration: const InputDecoration(
                labelText: 'رقم المركبة',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'أدخل رقم المركبة';
                }
                if (int.tryParse(v.trim()) == null) {
                  return 'رقم غير صالح';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _expenseType,
              decoration: const InputDecoration(
                labelText: 'نوع المصروف',
                border: OutlineInputBorder(),
              ),
              items: _expenseTypes
                  .map((t) => DropdownMenuItem<String>(
                        value: t,
                        child: Text(t),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _expenseType = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'المبلغ (DH)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'أدخل المبلغ';
                }
                final val = double.tryParse(v.trim());
                if (val == null || val <= 0) {
                  return 'المبلغ غير صالح';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'الوصف (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            ListTile(
              title: Text(
                _date != null
                    ? 'التاريخ: ${_date!.day}/${_date!.month}/${_date!.year}'
                    : 'اختر التاريخ',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_isSubmitting ? 'جاري الحفظ...' : 'حفظ فاتورة الدين'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
