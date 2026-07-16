import 'package:decimal/decimal.dart';

class Invoice {
  final int? id;
  final String clientId;
  final String invoiceNumber;
  final Decimal totalAmount;
  final Decimal? paidAmount;
  final String status;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final String? bankAccountId;
  final String? currency;
  final String inputMode;
  final Decimal? htAmount;
  final Decimal? tvaRate;
  final Decimal? tvaAmount;
  final Decimal? ttcAmount;

  const Invoice({
    this.id,
    required this.clientId,
    required this.invoiceNumber,
    required this.totalAmount,
    this.paidAmount,
    required this.status,
    this.issueDate,
    this.dueDate,
    this.bankAccountId,
    this.currency,
    this.inputMode = 'HT',
    this.htAmount,
    this.tvaRate,
    this.tvaAmount,
    this.ttcAmount,
  });

  bool get isPaid => status == 'paid';
  bool get isPartiallyPaid => status == 'partially_paid';
  bool get isUnpaid => status == 'unpaid';
  Decimal get remainingAmount => totalAmount - (paidAmount ?? Decimal.zero);

  factory Invoice.fromMap(Map<String, dynamic> map) {
    Decimal parseDecimal(dynamic value) {
      if (value == null) return Decimal.zero;
      if (value is Decimal) return value;
      if (value is num) return Decimal.parse(value.toString());
      if (value is String) return Decimal.parse(value);
      return Decimal.zero;
    }

    return Invoice(
      id: map['id'] as int?,
      clientId: map['client_id']?.toString() ?? map['clientId']?.toString() ?? '',
      invoiceNumber: map['invoice_number']?.toString() ?? map['invoiceNumber']?.toString() ?? '',
      totalAmount: parseDecimal(map['total_amount'] ?? map['totalAmount']),
      paidAmount: map['paid_amount'] != null ? parseDecimal(map['paid_amount']) : null,
      status: map['status']?.toString() ?? 'unpaid',
      issueDate: map['issue_date'] != null ? DateTime.tryParse(map['issue_date'].toString()) : null,
      dueDate: map['due_date'] != null ? DateTime.tryParse(map['due_date'].toString()) : null,
      bankAccountId: map['bank_account_id']?.toString(),
      currency: map['currency']?.toString(),
      inputMode: map['input_mode']?.toString() ?? 'HT',
      htAmount: map['ht_amount'] != null ? parseDecimal(map['ht_amount']) : null,
      tvaRate: map['tva_rate'] != null ? parseDecimal(map['tva_rate']) : null,
      tvaAmount: map['tva_amount'] != null ? parseDecimal(map['tva_amount']) : null,
      ttcAmount: map['ttc_amount'] != null ? parseDecimal(map['ttc_amount']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'client_id': clientId,
      'invoice_number': invoiceNumber,
      'total_amount': totalAmount.toString(),
      if (paidAmount != null) 'paid_amount': paidAmount.toString(),
      'status': status,
      if (issueDate != null) 'issue_date': issueDate!.toIso8601String(),
      if (dueDate != null) 'due_date': dueDate!.toIso8601String(),
      if (bankAccountId != null) 'bank_account_id': bankAccountId,
      if (currency != null) 'currency': currency,
      'input_mode': inputMode,
      if (htAmount != null) 'ht_amount': htAmount.toString(),
      if (tvaRate != null) 'tva_rate': tvaRate.toString(),
      if (tvaAmount != null) 'tva_amount': tvaAmount.toString(),
      if (ttcAmount != null) 'ttc_amount': ttcAmount.toString(),
    };
  }

  Invoice copyWith({
    int? id,
    String? clientId,
    String? invoiceNumber,
    Decimal? totalAmount,
    Decimal? paidAmount,
    String? status,
    DateTime? issueDate,
    DateTime? dueDate,
    String? bankAccountId,
    String? currency,
    String? inputMode,
    Decimal? htAmount,
    Decimal? tvaRate,
    Decimal? tvaAmount,
    Decimal? ttcAmount,
  }) {
    return Invoice(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      bankAccountId: bankAccountId ?? this.bankAccountId,
      currency: currency ?? this.currency,
      inputMode: inputMode ?? this.inputMode,
      htAmount: htAmount ?? this.htAmount,
      tvaRate: tvaRate ?? this.tvaRate,
      tvaAmount: tvaAmount ?? this.tvaAmount,
      ttcAmount: ttcAmount ?? this.ttcAmount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Invoice && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Invoice(id: $id, number: $invoiceNumber, total: $totalAmount, status: $status)';
}
