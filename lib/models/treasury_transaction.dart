class TreasuryTransaction {
  final int? id;
  final double amount;
  final String type;
  final String description;
  final String currency;
  final DateTime? createdAt;
  final int? cashBoxId;
  final int? relatedCashBoxId;

  const TreasuryTransaction({
    this.id,
    required this.amount,
    required this.type,
    required this.description,
    this.currency = 'MAD',
    this.createdAt,
    this.cashBoxId,
    this.relatedCashBoxId,
  });

  factory TreasuryTransaction.fromMap(Map<String, dynamic> map) {
    return TreasuryTransaction(
      id: map['id'] as int?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: map['type']?.toString() ?? map['category']?.toString() ?? map['transaction_type']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      currency: map['currency']?.toString() ?? 'MAD',
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      cashBoxId: map['cash_box_id'] as int?,
      relatedCashBoxId: map['related_cash_box_id'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'type': type,
      'description': description,
      'currency': currency,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (cashBoxId != null) 'cash_box_id': cashBoxId,
      if (relatedCashBoxId != null) 'related_cash_box_id': relatedCashBoxId,
    };
  }

  TreasuryTransaction copyWith({
    int? id,
    double? amount,
    String? type,
    String? description,
    String? currency,
    DateTime? createdAt,
    int? cashBoxId,
    int? relatedCashBoxId,
  }) {
    return TreasuryTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      description: description ?? this.description,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      cashBoxId: cashBoxId ?? this.cashBoxId,
      relatedCashBoxId: relatedCashBoxId ?? this.relatedCashBoxId,
    );
  }

  String get currencySymbol {
    switch (currency) {
      case 'EUR':
        return '€';
      case 'MAD':
      default:
        return 'DH';
    }
  }

  bool get isIncome => type == 'capital_injection' || type == 'trip_revenue';
  bool get isTransfer => type == 'transfer';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TreasuryTransaction && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'TreasuryTransaction(id: $id, amount: $amount, type: $type, currency: $currency, description: $description, cashBoxId: $cashBoxId, relatedCashBoxId: $relatedCashBoxId)';
}
