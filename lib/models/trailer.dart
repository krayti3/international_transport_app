
class Trailer {
  final int? id;
  final String plate;
  final String type;
  final String status;
  final String? truckId;
  final DateTime? createdAt;

  const Trailer({
    this.id,
    required this.plate,
    required this.type,
    required this.status,
    this.truckId,
    this.createdAt,
  });

  factory Trailer.fromMap(Map<String, dynamic> map) {
    return Trailer(
      id: map['id'] as int?,
      plate: map['plate']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      truckId: map['truck_id']?.toString() ?? map['truckId']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'plate': plate,
      'type': type,
      'status': status,
      if (truckId != null) 'truck_id': truckId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  Trailer copyWith({
    int? id,
    String? plate,
    String? type,
    String? status,
    String? truckId,
    DateTime? createdAt,
  }) {
    return Trailer(
      id: id ?? this.id,
      plate: plate ?? this.plate,
      type: type ?? this.type,
      status: status ?? this.status,
      truckId: truckId ?? this.truckId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Trailer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Trailer(id: $id, plate: $plate, type: $type, status: $status)';
}
