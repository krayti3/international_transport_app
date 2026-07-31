
class TripOrder {
  final int? id;
  final String clientId;
  final String route;
  final double price;
  final DateTime? departureDate;
  final String status;
  final String? truckId;
  final String? driverId;
  final int? tripId;
  final String direction;
  final double specificExpenses;
  final bool isSynced;

  const TripOrder({
    this.id,
    required this.clientId,
    required this.route,
    required this.price,
    this.departureDate,
    required this.status,
    this.truckId,
    this.driverId,
    this.tripId,
    this.direction = 'outbound',
    this.specificExpenses = 0.0,
    this.isSynced = true,
  });

  factory TripOrder.fromMap(Map<String, dynamic> map) {
    return TripOrder(
      id: map['id'] as int?,
      clientId: map['client_id']?.toString() ?? map['clientId']?.toString() ?? '',
      route: map['route']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      departureDate: map['departure_date'] != null ? DateTime.tryParse(map['departure_date'].toString()) : null,
      status: map['status']?.toString() ?? '',
      truckId: map['truck_id']?.toString(),
      driverId: map['driver_id']?.toString(),
      tripId: map['trip_id'] as int?,
      direction: map['direction']?.toString() ?? 'outbound',
      specificExpenses: (map['specific_expenses'] as num?)?.toDouble() ?? 0.0,
      isSynced: map['is_synced'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'client_id': clientId,
      'route': route,
      'price': price,
      if (departureDate != null) 'departure_date': departureDate!.toIso8601String(),
      'status': status,
      if (truckId != null) 'truck_id': truckId,
      if (driverId != null) 'driver_id': driverId,
      if (tripId != null) 'trip_id': tripId,
      'direction': direction,
      'specific_expenses': specificExpenses,
      'is_synced': isSynced,
    };
  }

  TripOrder copyWith({
    int? id,
    String? clientId,
    String? route,
    double? price,
    DateTime? departureDate,
    String? status,
    String? truckId,
    String? driverId,
    int? tripId,
    String? direction,
    double? specificExpenses,
        bool? isSynced,
    }) {
    return TripOrder(
    id: id ?? this.id,
    clientId: clientId ?? this.clientId,
    route: route ?? this.route,
    price: price ?? this.price,
    departureDate: departureDate ?? this.departureDate,
    status: status ?? this.status,
    truckId: truckId ?? this.truckId,
    driverId: driverId ?? this.driverId,
    tripId: tripId ?? this.tripId,
    direction: direction ?? this.direction,
      specificExpenses: specificExpenses ?? this.specificExpenses,
        isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TripOrder && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TripOrder(id: $id, route: $route, price: $price, status: $status, tripId: $tripId, direction: $direction, specificExpenses: $specificExpenses)';
}

