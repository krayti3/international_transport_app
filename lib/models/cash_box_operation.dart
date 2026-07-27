class CashBoxOperation {
  final int cashBoxId;
  final String operationCode;

  const CashBoxOperation({
    required this.cashBoxId,
    required this.operationCode,
  });

  factory CashBoxOperation.fromMap(Map<String, dynamic> map) {
    return CashBoxOperation(
      cashBoxId: map['cash_box_id'] as int,
      operationCode: map['operation_code']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'cash_box_id': cashBoxId,
    'operation_code': operationCode,
  };

  CashBoxOperation copyWith({
    int? cashBoxId,
    String? operationCode,
  }) {
    return CashBoxOperation(
      cashBoxId: cashBoxId ?? this.cashBoxId,
      operationCode: operationCode ?? this.operationCode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashBoxOperation &&
          runtimeType == other.runtimeType &&
          cashBoxId == other.cashBoxId &&
          operationCode == other.operationCode;

  @override
  int get hashCode => Object.hash(cashBoxId, operationCode);

  @override
  String toString() => 'CashBoxOperation(cashBoxId: $cashBoxId, operationCode: $operationCode)';
}
