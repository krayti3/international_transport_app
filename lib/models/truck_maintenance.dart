class TruckMaintenance {
  final int? id;
  final int truckId;
  final String expenseType;
  final String? description;
  final double amount;
  final double? kmAtTime;
  final String? dueDate;
  final DateTime? createdAt;
  final String? providerName;
  final String paymentStatus;
  final DateTime? maintenanceDate;
  final String currency;

  const TruckMaintenance({
    this.id,
    required this.truckId,
    required this.expenseType,
    this.description,
    required this.amount,
    this.kmAtTime,
    this.dueDate,
    this.createdAt,
    this.providerName,
    this.paymentStatus = 'paid_by_owner',
    this.maintenanceDate,
    this.currency = 'MAD',
  });

  factory TruckMaintenance.fromMap(Map<String, dynamic> map) {
    return TruckMaintenance(
      id: map['id'] as int?,
      truckId: (map['truck_id'] as num?)?.toInt() ?? 0,
      expenseType: map['expense_type']?.toString() ?? '',
      description: map['description']?.toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      kmAtTime: (map['km_at_time'] as num?)?.toDouble(),
      dueDate: map['due_date']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      providerName: map['provider_name']?.toString(),
      paymentStatus: map['payment_status']?.toString() ?? 'paid_by_owner',
      maintenanceDate: map['maintenance_date'] != null ? DateTime.tryParse(map['maintenance_date'].toString()) : null,
        currency: map['currency']?.toString() ?? 'MAD',
        );
   }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'truck_id': truckId,
      'expense_type': expenseType,
      if (description != null && description!.isNotEmpty) 'description': description,
      'amount': amount,
      if (kmAtTime != null) 'km_at_time': kmAtTime,
      if (dueDate != null) 'due_date': dueDate,
      if (providerName != null && providerName!.isNotEmpty) 'provider_name': providerName,
      'payment_status': paymentStatus,
      if (maintenanceDate != null) 'maintenance_date': maintenanceDate!.toIso8601String(),
        'currency': currency,
        };
   }

  TruckMaintenance copyWith({
    int? id,
    int? truckId,
    String? expenseType,
    String? description,
    double? amount,
    double? kmAtTime,
    String? dueDate,
    DateTime? createdAt,
    String? providerName,
    String? paymentStatus,
    DateTime? maintenanceDate,
    String? currency,
  }) {
    return TruckMaintenance(
      id: id ?? this.id,
      truckId: truckId ?? this.truckId,
      expenseType: expenseType ?? this.expenseType,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      kmAtTime: kmAtTime ?? this.kmAtTime,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      providerName: providerName ?? this.providerName,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      maintenanceDate: maintenanceDate ?? this.maintenanceDate,
      currency: currency ?? this.currency,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TruckMaintenance && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TruckMaintenance(id: $id, truckId: $truckId, expenseType: $expenseType, amount: $amount)';
}
