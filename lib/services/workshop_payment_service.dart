import 'package:decimal/decimal.dart';
import 'package:international_transport_app/models/repair_invoice.dart';

class WorkshopPaymentAllocation {
  final int invoiceId;
  final String invoiceNumber;
  final Decimal totalAmount;
  final Decimal paidAmount;
  final Decimal remainingAmount;
  final Decimal allocatedAmount;
  final String status; // 'paid' | 'partially_paid' | 'unpaid'

  WorkshopPaymentAllocation({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.allocatedAmount,
    required this.status,
  });
}

class WorkshopPaymentResult {
  final int paymentId;
  final double totalAmount;
  final List<WorkshopPaymentAllocation> allocations;
  final double remainingUnallocated;

  WorkshopPaymentResult({
    required this.paymentId,
    required this.totalAmount,
    required this.allocations,
    required this.remainingUnallocated,
  });
}

class WorkshopPaymentService {
  /// خوارزمية FIFO لتوزيع مبلغ دفعة على فواتير الورش.
  ///
  /// تمر على الفواتير مرتبة من الأقدم إلى الأحدث (حسب [date])
  /// وتسددها بالتتابع حتى ينتهي مبلغ الدفعة.
  ///
  /// المعاملات:
  /// - [invoices]: قائمة فواتير الورش غير المدفوعة بالكامل (مرتبة مسبقاً).
  /// - [amount]: مبلغ الدفعة المراد توزيعها.
  ///
  /// يُرجع [WorkshopPaymentResult] يحتوي على تفاصيل كل تخصيص
  /// والمبلغ المتبقي غير المُوزَّع (إن وُجد).
  static WorkshopPaymentResult allocateFIFO({
    required List<RepairInvoice> invoices,
    required double amount,
  }) {
    double remaining = amount;
    final allocations = <WorkshopPaymentAllocation>[];

    for (final invoice in invoices) {
      if (remaining <= 0) break;

      final dueAmount = invoice.remainingAmount;
      if (dueAmount <= Decimal.zero) continue;

      final dueDouble = dueAmount.toDouble();
      double allocated = 0;
      String newStatus = 'partially_paid';

      if (remaining >= dueDouble) {
        allocated = dueDouble;
        remaining -= dueDouble;
        newStatus = 'paid';
      } else {
        allocated = remaining;
        remaining = 0;
        newStatus = 'partially_paid';
      }

      allocations.add(WorkshopPaymentAllocation(
        invoiceId: invoice.id ?? 0,
        invoiceNumber: invoice.invoiceNumber,
        totalAmount: invoice.totalAmount,
        paidAmount: invoice.paidAmount + Decimal.parse(allocated.toString()),
        remainingAmount: invoice.totalAmount - (invoice.paidAmount + Decimal.parse(allocated.toString())),
        allocatedAmount: Decimal.parse(allocated.toString()),
        status: newStatus,
      ));
    }

    return WorkshopPaymentResult(
      paymentId: 0,
      totalAmount: amount,
      allocations: allocations,
      remainingUnallocated: remaining,
    );
  }

  /// يتحقق من صحة التوزيع: مجموع المبالغ المُخصصة لا يتجاوز مبلغ الدفعة
  /// ومجموع المبالغ المُخصصة لكل فاتورة لا يتجاوز رصيدها المتبقي.
  static bool validateAllocations({
    required double paymentAmount,
    required List<WorkshopPaymentAllocation> allocations,
  }) {
    double totalAllocated = 0;
    for (final alloc in allocations) {
      totalAllocated += alloc.allocatedAmount.toDouble();
      if (alloc.allocatedAmount.toDouble() > alloc.totalAmount.toDouble()) {
        return false;
      }
    }
    return totalAllocated <= paymentAmount;
  }

  /// يحسب الرصيد المتبقي الكلي لورشة من قائمة الفواتير.
  static Decimal calculateTotalRemaining(List<RepairInvoice> invoices) {
    Decimal total = Decimal.zero;
    for (final inv in invoices) {
      total += inv.remainingAmount;
    }
    return total;
  }

  /// يحسب الرصيد المدفوع الكلي لورشة.
  static Decimal calculateTotalPaid(List<RepairInvoice> invoices) {
    Decimal total = Decimal.zero;
    for (final inv in invoices) {
      total += inv.paidAmount;
    }
    return total;
  }
}