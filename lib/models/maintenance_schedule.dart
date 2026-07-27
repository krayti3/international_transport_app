class MaintenanceSchedule {
  final int? id;
  final String vehicleType;
  final int vehicleId;
  final String taskType;
  final String? description;
  final DateTime scheduledDate;
  final double? dueKm;
  final String status;
  final String? assignedTo;
  final double? estimatedCost;
  final bool notificationSent;
  final DateTime? completedAt;
  final double? completedKm;
  final double? actualCost;
  final String? notes;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MaintenanceSchedule({
    this.id,
    required this.vehicleType,
    required this.vehicleId,
    required this.taskType,
    this.description,
    required this.scheduledDate,
    this.dueKm,
    this.status = 'pending',
    this.assignedTo,
    this.estimatedCost,
    this.notificationSent = false,
    this.completedAt,
    this.completedKm,
    this.actualCost,
    this.notes,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  factory MaintenanceSchedule.fromMap(Map<String, dynamic> map) {
    return MaintenanceSchedule(
      id: map['id'] as int?,
      vehicleType: map['vehicle_type']?.toString() ?? 'truck',
      vehicleId: (map['vehicle_id'] as num?)?.toInt() ?? 0,
      taskType: map['task_type']?.toString() ?? '',
      description: map['description']?.toString(),
      scheduledDate: map['scheduled_date'] != null
          ? DateTime.tryParse(map['scheduled_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      dueKm: (map['due_km'] as num?)?.toDouble(),
      status: map['status']?.toString() ?? 'pending',
      assignedTo: map['assigned_to']?.toString(),
      estimatedCost: (map['estimated_cost'] as num?)?.toDouble(),
      notificationSent: map['notification_sent'] == true || map['notification_sent']?.toString() == 'true',
      completedAt: map['completed_at'] != null ? DateTime.tryParse(map['completed_at'].toString()) : null,
      completedKm: (map['completed_km'] as num?)?.toDouble(),
      actualCost: (map['actual_cost'] as num?)?.toDouble(),
      notes: map['notes']?.toString(),
      isDeleted: map['is_deleted'] == true || map['is_deleted']?.toString() == 'true',
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'vehicle_type': vehicleType,
      'vehicle_id': vehicleId,
      'task_type': taskType,
      if (description != null && description!.isNotEmpty) 'description': description,
      'scheduled_date': scheduledDate.toIso8601String().split('T').first,
      if (dueKm != null) 'due_km': dueKm,
      'status': status,
      if (assignedTo != null && assignedTo!.isNotEmpty) 'assigned_to': assignedTo,
      if (estimatedCost != null) 'estimated_cost': estimatedCost,
      'notification_sent': notificationSent,
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      if (completedKm != null) 'completed_km': completedKm,
      if (actualCost != null) 'actual_cost': actualCost,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      'is_deleted': isDeleted,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  MaintenanceSchedule copyWith({
    int? id,
    String? vehicleType,
    int? vehicleId,
    String? taskType,
    String? description,
    DateTime? scheduledDate,
    double? dueKm,
    String? status,
    String? assignedTo,
    double? estimatedCost,
    bool? notificationSent,
    DateTime? completedAt,
    double? completedKm,
    double? actualCost,
    String? notes,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MaintenanceSchedule(
      id: id ?? this.id,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleId: vehicleId ?? this.vehicleId,
      taskType: taskType ?? this.taskType,
      description: description ?? this.description,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      dueKm: dueKm ?? this.dueKm,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      notificationSent: notificationSent ?? this.notificationSent,
      completedAt: completedAt ?? this.completedAt,
      completedKm: completedKm ?? this.completedKm,
      actualCost: actualCost ?? this.actualCost,
      notes: notes ?? this.notes,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isSkipped => status == 'skipped';
  bool get isOverdue => status == 'overdue';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MaintenanceSchedule && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MaintenanceSchedule(id: $id, vehicleType: $vehicleType, vehicleId: $vehicleId, taskType: $taskType, scheduledDate: $scheduledDate, status: $status)';
}
