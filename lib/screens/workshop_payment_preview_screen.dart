import 'package:flutter/material.dart';
import 'package:international_transport_app/models/repair_invoice.dart';
import '../services/workshop_payment_service.dart';

// ignore_for_file: use_build_context_synchronously

class WorkshopPaymentPreviewScreen extends StatelessWidget {
  final String workshopName;
  final List<RepairInvoice> invoices;
  final double paymentAmount;
  final String method;
  final String ref;
  final String? note;

  const WorkshopPaymentPreviewScreen({
    super.key,
    required this.workshopName,
    required this.invoices,
    required this.paymentAmount,
    required this.method,
    required this.ref,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final result = WorkshopPaymentService.allocateFIFO(
      invoices: invoices,
      amount: paymentAmount,
    );

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة توزيع الدفعة'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ملخص الدفعة
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الدفعة: ${paymentAmount.toStringAsFixed(2)} DH',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('طريقة الدفع: $method'),
                  if (ref.isNotEmpty) Text('المرجع: $ref'),
                  if (note != null && note!.isNotEmpty) Text('ملاحظة: $note'),
                  const SizedBox(height: 8),
                  Text(
                    'عدد الفواتير المستحقة: ${invoices.length}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // تفاصيل التوزيع
          Text(
            'تفاصيل التوزيع (FIFO)',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...result.allocations.map((alloc) {
            final statusColor = alloc.status == 'paid'
                ? Colors.green
                : alloc.status == 'partially_paid'
                    ? Colors.orange
                    : Colors.red;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(alloc.invoiceNumber),
                subtitle: Text(
                  'المبلغ الأصلي: ${alloc.totalAmount.toStringAsFixed(2)} DH'
                  '\nالمدفوع السابق: ${alloc.paidAmount.toStringAsFixed(2)} DH'
                  '\nالمخصص من هذه الدفعة: ${alloc.allocatedAmount.toStringAsFixed(2)} DH'
                  '\nالمتبقي الجديد: ${alloc.remainingAmount.toStringAsFixed(2)} DH',
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    alloc.status == 'paid' ? 'مدفوعة' : 'مدفوعة جزئياً',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }),
          if (result.remainingUnallocated > 0)
            Card(
              color: Colors.orange.withValues(alpha: 0.1),
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                title: Text(
                  'المبلغ المتبقي غير الموزع: ${result.remainingUnallocated.toStringAsFixed(2)} DH',
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'جميع الفواتير غير المدفوعة تم تغطيتها. '
                  'سيتم حفظ المبلغ المتبقي كرصيد مفتوح.',
                ),
              ),
            ),
          const SizedBox(height: 16),
          // زر التأكيد
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context, result);
            },
            icon: const Icon(Icons.check_rounded),
            label: const Text('تأكيد التسوية'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}