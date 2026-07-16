class Driver {
  final int? id;
  final String name;
  final String phone;
  final String license;
  final String status;
  final double baseSalary;
  final double bonusPercentage;
  final int? defaultTruckId;
  final String? visaNumber;
  final DateTime? visaExpiryDate;
  final bool hasValidVisa;

  const Driver({
    this.id,
    required this.name,
    required this.phone,
    required this.license,
    required this.status,
    required this.baseSalary,
    required this.bonusPercentage,
    this.defaultTruckId,
    this.visaNumber,
    this.visaExpiryDate,
    this.hasValidVisa = false,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as int?,
      name: (json['name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      license: (json['license'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'active',
      baseSalary: (json['base_salary'] as num?)?.toDouble() ?? 0.0,
      bonusPercentage: (json['bonus_percentage'] as num?)?.toDouble() ?? 0.0,
      defaultTruckId: json['default_truck_id'] as int?,
      visaNumber: json['visa_number'] as String?,
      visaExpiryDate: json['visa_expiry_date'] != null
          ? DateTime.parse(json['visa_expiry_date'] as String)
          : null,
      hasValidVisa: (json['has_valid_visa'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'license': license,
      'status': status,
      'base_salary': baseSalary,
      'bonus_percentage': bonusPercentage,
      if (defaultTruckId != null) 'default_truck_id': defaultTruckId,
      if (visaNumber != null) 'visa_number': visaNumber,
      if (visaExpiryDate != null)
        'visa_expiry_date': visaExpiryDate!.toIso8601String(),
      'has_valid_visa': hasValidVisa,
    };
  }
}
