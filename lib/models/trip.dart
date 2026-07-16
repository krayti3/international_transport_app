class Trip {
  final int? id;
  final int driverId;
  final double amountGiven;
  final String dateOut;
  final String status;
  final double? amountSpent;
  final double? amountReturned;
  final List<String> receiptsImages;
  final String? dateReturn;
  final String? createdAt;
  final String notes;

  const Trip({
    this.id,
    required this.driverId,
    required this.amountGiven,
    required this.dateOut,
    required this.status,
    this.amountSpent,
    this.amountReturned,
    this.receiptsImages = const [],
    this.dateReturn,
    this.createdAt,
    this.notes = '',
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    final rawImages = json['receipts_images'];
    final images = rawImages is List
        ? rawImages
            .map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    return Trip(
      id: json['id'] as int?,
      driverId: (json['driver_id'] as num?)?.toInt() ?? 0,
      amountGiven: (json['amount_given'] as num?)?.toDouble() ?? 0.0,
      dateOut: (json['date_out'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'en_route',
      amountSpent: (json['amount_spent'] as num?)?.toDouble(),
      amountReturned: (json['amount_returned'] as num?)?.toDouble(),
      receiptsImages: images,
      dateReturn: json['date_return'] as String?,
      createdAt: json['created_at'] as String?,
      notes: (json['notes'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'driver_id': driverId,
      'amount_given': amountGiven,
      'date_out': dateOut,
      'status': status,
      'amount_spent': amountSpent,
      'amount_returned': amountReturned,
      'receipts_images': receiptsImages,
      'date_return': dateReturn,
      if (createdAt != null) 'created_at': createdAt,
      'notes': notes,
    };
  }

  Trip copyWith({
    int? id,
    int? driverId,
    double? amountGiven,
    String? dateOut,
    String? status,
    double? amountSpent,
    double? amountReturned,
    List<String>? receiptsImages,
    String? dateReturn,
    String? createdAt,
    String? notes,
  }) {
    return Trip(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      amountGiven: amountGiven ?? this.amountGiven,
      dateOut: dateOut ?? this.dateOut,
      status: status ?? this.status,
      amountSpent: amountSpent ?? this.amountSpent,
      amountReturned: amountReturned ?? this.amountReturned,
      receiptsImages: receiptsImages ?? this.receiptsImages,
      dateReturn: dateReturn ?? this.dateReturn,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
    );
  }
}
