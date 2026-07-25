import 'package:decimal/decimal.dart';

class RepairInvoice {
  final int? id;
  final String workshopId;
  final String? vehicleId;
  final String? vehicleType;
  final String invoiceNumber;
  final Decimal totalAmount;
  final Decimal paidAmount;
  final Decimal _cachedRemainingAmount;
  final String status;
  final DateTime? date;
  final String? description;
  final String? paymentMethod;
  final String? paymentRef;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  RepairInvoice({
    this.id,
    required this.workshopId,
    this.vehicleId,
    this.vehicleType,
    required this.invoiceNumber,
    required this.totalAmount,
    Decimal? paidAmount,
    Decimal? remainingAmount,
    this.status = 'unpaid',
    this.date,
    this.description,
    this.paymentMethod,
    this.paymentRef,
    this.createdAt,
    this.updatedAt,
  })  : paidAmount = paidAmount ?? Decimal.zero,
        _cachedRemainingAmount = remainingAmount ??
            (totalAmount - (paidAmount ?? Decimal.zero));

  Decimal get remainingAmount => _cachedRemainingAmount;

  bool get isPaid => status == 'paid';
  bool get isPartiallyPaid => status == 'partially_paid';
  bool get isUnpaid => status == 'unpaid';

  factory RepairInvoice.fromMap(Map<String, dynamic> map) {
    Decimal parseDecimal(dynamic value) {
      if (value == null) return Decimal.zero;
      if (value is Decimal) return value;
      if (value is num) return Decimal.parse(value.toString());
      if (value is String) return Decimal.parse(value);
      return Decimal.zero;
    }

    String statusFromDb(String? s) {
      if (s == null) return 'unpaid';
      switch (s.toLowerCase()) {
        case 'paid':
          return 'paid';
        case 'partially_paid':
          return 'partially_paid';
        default:
          return 'unpaid';
      }
    }

    return RepairInvoice(
      id: map['id'] as int?,
      workshopId: map['workshop_id']?.toString() ?? '',
      vehicleId: map['vehicle_id']?.toString(),
      vehicleType: map['vehicle_type']?.toString(),
      invoiceNumber: map['invoice_number']?.toString() ?? '',
      totalAmount: parseDecimal(map['total_amount'] ?? map['totalAmount']),
      paidAmount: parseDecimal(map['paid_amount'] ?? map['paidAmount']),
      remainingAmount: map['remaining_amount'] != null
          ? parseDecimal(map['remaining_amount'])
          : null,
      status: statusFromDb(map['status']?.toString()),
      date: map['date'] != null ? DateTime.tryParse(map['date'].toString()) : null,
      description: map['description']?.toString(),
      paymentMethod: map['payment_method']?.toString(),
      paymentRef: map['payment_ref']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'workshop_id': workshopId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (vehicleType != null) 'vehicle_type': vehicleType,
      'invoice_number': invoiceNumber,
      'total_amount': totalAmount.toString(),
      'paid_amount': paidAmount.toString(),
      'status': status,
      if (date != null) 'date': date!.toIso8601String(),
      if (description != null) 'description': description,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (paymentRef != null) 'payment_ref': paymentRef,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  RepairInvoice copyWith({
    int? id,
    String? workshopId,
    String? vehicleId,
    String? vehicleType,
    String? invoiceNumber,
    Decimal? totalAmount,
    Decimal? paidAmount,
    Decimal? remainingAmount,
    String? status,
    DateTime? date,
    String? description,
    String? paymentMethod,
    String? paymentRef,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RepairInvoice(
      id: id ?? this.id,
      workshopId: workshopId ?? this.workshopId,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleType: vehicleType ?? this.vehicleType,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? _cachedRemainingAmount,
      status: status ?? this.status,
      date: date ?? this.date,
      description: description ?? this.description,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentRef: paymentRef ?? this.paymentRef,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepairInvoice && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'RepairInvoice(id: $id, number: $invoiceNumber, total: $totalAmount, status: $status)';
}