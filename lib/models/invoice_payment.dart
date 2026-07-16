
class InvoicePayment {
  final int? id;
  final int invoiceId;
  final double amountPaid;
  final DateTime paymentDate;
  final String paymentMethod;
  final String receiptReference;

  const InvoicePayment({
    this.id,
    required this.invoiceId,
    required this.amountPaid,
    required this.paymentDate,
    required this.paymentMethod,
    required this.receiptReference,
  });

  factory InvoicePayment.fromMap(Map<String, dynamic> map) {
    return InvoicePayment(
      id: map['id'] as int?,
      invoiceId: (map['invoice_id'] as num?)?.toInt() ?? 0,
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0.0,
      paymentDate: map['payment_date'] != null
          ? DateTime.tryParse(map['payment_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      paymentMethod: map['payment_method']?.toString() ?? '',
      receiptReference: map['receipt_reference']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_id': invoiceId,
      'amount_paid': amountPaid,
      'payment_date': paymentDate.toIso8601String(),
      'payment_method': paymentMethod,
      'receipt_reference': receiptReference,
    };
  }

  InvoicePayment copyWith({
    int? id,
    int? invoiceId,
    double? amountPaid,
    DateTime? paymentDate,
    String? paymentMethod,
    String? receiptReference,
  }) {
    return InvoicePayment(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      amountPaid: amountPaid ?? this.amountPaid,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptReference: receiptReference ?? this.receiptReference,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoicePayment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'InvoicePayment(id: $id, invoiceId: $invoiceId, amount: $amountPaid, method: $paymentMethod)';
}