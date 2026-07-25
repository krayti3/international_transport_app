import 'package:decimal/decimal.dart';

enum CashBoxType {
  ownerCash('owner_cash', 'كاش صاحب الشركة'),
  bankMorocco('bank_morocco', 'الحساب البنكي المغربي'),
  bankEurope('bank_europe', 'الحساب البنكي الأوروبي'),
  secretaryCash('secretary_cash', 'خزينة السكرتيرة');

  final String code;
  final String label;
  const CashBoxType(this.code, this.label);
}

class CashBox {
  final int? id;
  final String name;
  final String type;
  final String? description;
  final Decimal balance;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CashBox({
    this.id,
    required this.name,
    required this.type,
    this.description,
    Decimal? balance,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  }) : balance = balance ?? Decimal.zero;

  factory CashBox.fromMap(Map<String, dynamic> map) {
    Decimal parseDecimal(dynamic value) {
      if (value == null) return Decimal.zero;
      if (value is Decimal) return value;
      if (value is num) return Decimal.parse(value.toString());
      if (value is String) return Decimal.parse(value);
      return Decimal.zero;
    }

    return CashBox(
      id: map['id'] as int?,
      name: map['name']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      description: map['description']?.toString(),
      balance: parseDecimal(map['balance']),
      isActive: map['is_active'] as bool? ?? true,
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
      'name': name,
      'type': type,
      if (description != null) 'description': description,
      'balance': balance.toString(),
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  CashBox copyWith({
    int? id,
    String? name,
    String? type,
    String? description,
    Decimal? balance,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CashBox(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      balance: balance ?? this.balance,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashBox && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CashBox(id: $id, name: $name, type: $type)';
}