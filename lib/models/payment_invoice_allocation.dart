
class PaymentInvoiceAllocation {
  final int? id;
  final String paymentId;
  final String invoiceId;
  final double allocatedAmount;

  const PaymentInvoiceAllocation({
    this.id,
    required this.paymentId,
    required this.invoiceId,
    required this.allocatedAmount,
  });

  factory PaymentInvoiceAllocation.fromMap(Map<String, dynamic> map) {
    return PaymentInvoiceAllocation(
      id: map['id'] as int?,
      paymentId: map['payment_id']?.toString() ?? map['paymentId']?.toString() ?? '',
      invoiceId: map['invoice_id']?.toString() ?? map['invoiceId']?.toString() ?? '',
      allocatedAmount: (map['allocated_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'payment_id': paymentId,
      'invoice_id': invoiceId,
      'allocated_amount': allocatedAmount,
    };
  }

  PaymentInvoiceAllocation copyWith({
    int? id,
    String? paymentId,
    String? invoiceId,
    double? allocatedAmount,
  }) {
    return PaymentInvoiceAllocation(
      id: id ?? this.id,
      paymentId: paymentId ?? this.paymentId,
      invoiceId: invoiceId ?? this.invoiceId,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentInvoiceAllocation && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PaymentInvoiceAllocation(id: $id, paymentId: $paymentId, invoiceId: $invoiceId, amount: $allocatedAmount)';
}
