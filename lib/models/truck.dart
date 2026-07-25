
class Truck {
  final int? id;
  final String plate;
  final String model;
  final String status;
  final String? currentLocation;
  final DateTime? createdAt;

  const Truck({
    this.id,
    required this.plate,
    required this.model,
    required this.status,
    this.currentLocation,
    this.createdAt,
  });

  factory Truck.fromMap(Map<String, dynamic> map) {
    return Truck(
      id: map['id'] as int?,
      plate: map['plate_number']?.toString() ?? map['plate']?.toString() ?? '',
      model: map['model']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      currentLocation: map['current_location']?.toString() ?? map['currentLocation']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'plate_number': plate,
      'model': model,
      'status': status,
      if (currentLocation != null) 'current_location': currentLocation,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Truck copyWith({
    int? id,
    String? plate,
    String? model,
    String? status,
    String? currentLocation,
    DateTime? createdAt,
  }) {
    return Truck(
      id: id ?? this.id,
      plate: plate ?? this.plate,
      model: model ?? this.model,
      status: status ?? this.status,
      currentLocation: currentLocation ?? this.currentLocation,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Truck && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Truck(id: $id, plate: $plate, model: $model, status: $status)';
}
