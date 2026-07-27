class BankAccount {
  final String id;
  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final String currency;
  final String? iban;
  final String? swiftCode;
  final bool isActive;
  final int? cashBoxId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BankAccount({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
    required this.currency,
    this.iban,
    this.swiftCode,
    this.isActive = true,
    this.cashBoxId,
    this.createdAt,
    this.updatedAt,
  });

  String get displayName => '$bankName ($currency)';

  factory BankAccount.fromMap(Map<String, dynamic> map) {
    return BankAccount(
      id: map['id'] as String,
      bankName: map['bank_name'] as String,
      accountNumber: map['account_number'] as String,
      accountHolder: map['account_holder'] as String,
      currency: map['currency'] as String,
      iban: map['iban'] as String?,
      swiftCode: map['swift_code'] as String?,
      isActive: map['is_active'] as bool,
      cashBoxId: map['cash_box_id'] as int?,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_holder': accountHolder,
      'currency': currency,
      if (iban != null) 'iban': iban,
      if (swiftCode != null) 'swift_code': swiftCode,
      'is_active': isActive,
      if (cashBoxId != null) 'cash_box_id': cashBoxId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  BankAccount copyWith({
    String? id,
    String? bankName,
    String? accountNumber,
    String? accountHolder,
    String? currency,
    String? iban,
    String? swiftCode,
    bool? isActive,
    int? cashBoxId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BankAccount(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountHolder: accountHolder ?? this.accountHolder,
      currency: currency ?? this.currency,
      iban: iban ?? this.iban,
      swiftCode: swiftCode ?? this.swiftCode,
      isActive: isActive ?? this.isActive,
      cashBoxId: cashBoxId ?? this.cashBoxId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BankAccount &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'BankAccount{id: $id, bankName: $bankName, currency: $currency}';
  }
}
