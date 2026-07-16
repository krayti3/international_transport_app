class BankAccount {
  final String id;
  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final String currency;
  final String? iban;
  final String? swiftCode;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  BankAccount({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
    required this.currency,
    this.iban,
    this.swiftCode,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName => '$bankName ($currency)';
  String get currencySymbol => currency == 'MAD' ? 'DH' : '€';

  BankAccount copyWith({
    String? id,
    String? bankName,
    String? accountNumber,
    String? accountHolder,
    String? currency,
    String? iban,
    String? swiftCode,
    bool? isActive,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory BankAccount.fromMap(Map<String, dynamic> map) {
    return BankAccount(
      id: map['id'] as String,
      bankName: map['bank_name'] as String,
      accountNumber: map['account_number'] as String,
      accountHolder: map['account_holder'] as String,
      currency: map['currency'] as String,
      iban: map['iban'] as String?,
      swiftCode: map['swift_code'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_holder': accountHolder,
      'currency': currency,
      'iban': iban,
      'swift_code': swiftCode,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
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
  String toString() => displayName;
}
