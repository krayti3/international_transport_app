
class Payment {
  final int? id;
  final String clientId;
  final double amount;
  final String method;
  final String ref;
  final DateTime? createdAt;

  const Payment({
    this.id,
    required this.clientId,
    required this.amount,
    required this.method,
    required this.ref,
    this.createdAt,
  });

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as int?,
      clientId: map['client_id']?.toString() ?? map['clientId']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      method: map['method']?.toString() ?? '',
      ref: map['ref']?.toString() ?? '',
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'client_id': clientId,
      'amount': amount,
      'method': method,
      'ref': ref,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Payment copyWith({
    int? id,
    String? clientId,
    double? amount,
    String? method,
    String? ref,
    DateTime? createdAt,
  }) {
    return Payment(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      ref: ref ?? this.ref,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Payment && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Payment(id: $id, clientId: $clientId, amount: $amount, method: $method)';
}
