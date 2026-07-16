
class AppSettings {
  final int? id;
  final bool isEnabled;
  final double percentage;

  const AppSettings({
    this.id,
    required this.isEnabled,
    required this.percentage,
  });

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      id: map['id'] as int?,
      isEnabled: map['is_enabled'] as bool? ?? map['isEnabled'] as bool? ?? false,
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'is_enabled': isEnabled,
      'percentage': percentage,
    };
  }

  AppSettings copyWith({
    int? id,
    bool? isEnabled,
    double? percentage,
  }) {
    return AppSettings(
      id: id ?? this.id,
      isEnabled: isEnabled ?? this.isEnabled,
      percentage: percentage ?? this.percentage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AppSettings && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AppSettings(id: $id, isEnabled: $isEnabled, percentage: $percentage)';
}
