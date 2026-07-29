class PendingStatusUpdate {
  final int tripId;
  final String status;
  final DateTime timestamp;

  PendingStatusUpdate({
    required this.tripId,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'tripId': tripId,
        'status': status,
        'timestamp': timestamp.toIso8601String(),
      };

  factory PendingStatusUpdate.fromMap(Map<String, dynamic> map) => PendingStatusUpdate(
        tripId: map['tripId'] as int,
        status: map['status'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
      );
}
