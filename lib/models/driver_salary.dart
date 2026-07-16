
class DriverSalary {
  final int? id;
  final String driverId;
  final int month;
  final int year;
  final double baseSalary;
  final double bonusAmount;
  final double totalSalary;
  final int completedTripsCount;
  final String status;

  const DriverSalary({
    this.id,
    required this.driverId,
    required this.month,
    required this.year,
    required this.baseSalary,
    required this.bonusAmount,
    required this.totalSalary,
    this.completedTripsCount = 0,
    required this.status,
  });

  factory DriverSalary.fromMap(Map<String, dynamic> map) {
    return DriverSalary(
      id: map['id'] as int?,
      driverId: map['driver_id']?.toString() ?? map['driverId']?.toString() ?? '',
      month: map['month'] as int? ?? 0,
      year: map['year'] as int? ?? 0,
      baseSalary: (map['base_salary'] as num?)?.toDouble() ?? 0.0,
      bonusAmount: (map['bonus_amount'] as num?)?.toDouble() ?? 0.0,
      totalSalary: (map['total_salary'] as num?)?.toDouble() ?? 0.0,
      completedTripsCount: map['completed_trips_count'] as int? ?? 0,
      status: map['status']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'driver_id': driverId,
      'month': month,
      'year': year,
      'base_salary': baseSalary,
      'bonus_amount': bonusAmount,
      'total_salary': totalSalary,
      'completed_trips_count': completedTripsCount,
      'status': status,
    };
  }

  DriverSalary copyWith({
    int? id,
    String? driverId,
    int? month,
    int? year,
    double? baseSalary,
    double? bonusAmount,
    double? totalSalary,
    int? completedTripsCount,
    String? status,
  }) {
    return DriverSalary(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      month: month ?? this.month,
      year: year ?? this.year,
      baseSalary: baseSalary ?? this.baseSalary,
      bonusAmount: bonusAmount ?? this.bonusAmount,
      totalSalary: totalSalary ?? this.totalSalary,
      completedTripsCount: completedTripsCount ?? this.completedTripsCount,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DriverSalary && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DriverSalary(id: $id, driverId: $driverId, month: $month/$year, total: $totalSalary)';
}
