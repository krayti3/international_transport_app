
class UserDocument {
  final int? id;
  final String documentType;
  final String documentNumber;
  final DateTime? expiryDate;
  final String attachmentUrl;
  final String relatedId;
  final String relatedType;

  const UserDocument({
    this.id,
    required this.documentType,
    required this.documentNumber,
    this.expiryDate,
    required this.attachmentUrl,
    required this.relatedId,
    required this.relatedType,
  });

  factory UserDocument.fromMap(Map<String, dynamic> map) {
    return UserDocument(
      id: map['id'] as int?,
      documentType: map['document_type']?.toString() ?? map['documentType']?.toString() ?? '',
      documentNumber: map['document_number']?.toString() ?? map['documentNumber']?.toString() ?? '',
      expiryDate: map['expiry_date'] != null ? DateTime.tryParse(map['expiry_date'].toString()) : null,
      attachmentUrl: map['attachment_url']?.toString() ?? map['attachmentUrl']?.toString() ?? '',
      relatedId: map['related_id']?.toString() ?? map['relatedId']?.toString() ?? '',
      relatedType: map['related_type']?.toString() ?? map['relatedType']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'document_type': documentType,
      'document_number': documentNumber,
      if (expiryDate != null) 'expiry_date': expiryDate!.toIso8601String(),
      'attachment_url': attachmentUrl,
      'related_id': relatedId,
      'related_type': relatedType,
    };
  }

  UserDocument copyWith({
    int? id,
    String? documentType,
    String? documentNumber,
    DateTime? expiryDate,
    String? attachmentUrl,
    String? relatedId,
    String? relatedType,
  }) {
    return UserDocument(
      id: id ?? this.id,
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      relatedId: relatedId ?? this.relatedId,
      relatedType: relatedType ?? this.relatedType,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserDocument && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'UserDocument(id: $id, type: $documentType, number: $documentNumber, related: $relatedType/$relatedId)';
}
