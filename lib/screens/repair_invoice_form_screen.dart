import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:international_transport_app/models/repair_invoice.dart';
import '../services/workshop_service.dart';
import '../widgets/date_wheel_picker.dart';

// ignore_for_file: use_build_context_synchronously

class RepairInvoiceFormScreen extends StatefulWidget {
  final String workshopId;
  final String workshopName;
  final RepairInvoice? existingInvoice;

  const RepairInvoiceFormScreen({
    super.key,
    required this.workshopId,
    required this.workshopName,
    this.existingInvoice,
  });

  @override
  State<RepairInvoiceFormScreen> createState() =>
      _RepairInvoiceFormScreenState();
}

class _RepairInvoiceFormScreenState
    extends State<RepairInvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumberController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _vehicleIdController = TextEditingController();
  String _vehicleType = 'truck';
  DateTime? _date;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final inv = widget.existingInvoice;
    if (inv != null) {
      _invoiceNumberController.text = inv.invoiceNumber;
      _totalAmountController.text = inv.totalAmount.toStringAsFixed(2);
      _paidAmountController.text = inv.paidAmount.toStringAsFixed(2);
      _descriptionController.text = inv.description ?? '';
      _vehicleIdController.text = inv.vehicleId ?? '';
      _vehicleType = inv.vehicleType ?? 'truck';
      _date = inv.date;
    } else {
      _date = DateTime.now();
    }
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
    setState(() => _isSubmitting = true);
    try {
      final workshopService = WorkshopService();
      final totalAmount = Decimal.parse(_totalAmountController.text.trim());
      final paidAmount = _paidAmountController.text.trim().isEmpty
          ? Decimal.zero
          : Decimal.parse(_paidAmountController.text.trim());
      final remainingAmount = totalAmount - paidAmount;
      final status = remainingAmount <= Decimal.zero
          ? 'paid'
          : paidAmount > Decimal.zero
              ? 'partially_paid'
              : 'unpaid';

      final invoice = RepairInvoice(
        id: widget.existingInvoice?.id,
        workshopId: widget.workshopId,
        vehicleId: _vehicleIdController.text.trim().isEmpty
            ? null
            : _vehicleIdController.text.trim(),
        vehicleType: _vehicleType,
        invoiceNumber: _invoiceNumberController.text.trim(),
        totalAmount: totalAmount,
        paidAmount: paidAmount,
        remainingAmount: remainingAmount,
        status: status,
        date: _date,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (widget.existingInvoice != null) {
        await workshopService.updateRepairInvoice(
          widget.existingInvoice!.id!,
          invoice.toMap(),
        );
      } else {
        await workshopService.insertRepairInvoice(invoice);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
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
        title: Text(
          widget.existingInvoice != null
              ? 'تعديل فاتورة الإصلاح'
              : 'فاتورة إصلاح جديدة',
        ),
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
            TextFormField(
              controller: _totalAmountController,
              decoration: const InputDecoration(
                labelText: 'المبلغ الإجمالي (DH)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'أدخل المبلغ الإجمالي';
                }
                final val = double.tryParse(v.trim());
                if (val == null || val < 0) {
                  return 'المبلغ غير صالح';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _paidAmountController,
              decoration: const InputDecoration(
                labelText: 'المبلغ المدفوع (DH)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
                labelText: 'رقم المركبة (اختياري)',
                border: OutlineInputBorder(),
              ),
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
              label: Text(
                widget.existingInvoice != null ? 'تحديث' : 'حفظ',
              ),
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
