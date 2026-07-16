
class TripOrderDocument {
  final int? id;
  final int tripOrderId;
  final String fileName;
  final String fileUrl;
  final String fileType;
  final String documentType;
  final DateTime createdAt;

  const TripOrderDocument({
    this.id,
    required this.tripOrderId,
    required this.fileName,
    required this.fileUrl,
    this.fileType = 'image',
    this.documentType = 'customs',
    required this.createdAt,
  });

  factory TripOrderDocument.fromMap(Map<String, dynamic> map) {
    return TripOrderDocument(
      id: map['id'] as int?,
      tripOrderId: map['trip_order_id'] as int? ?? 0,
      fileName: map['file_name']?.toString() ?? '',
      fileUrl: map['file_url']?.toString() ?? '',
      fileType: map['file_type']?.toString() ?? 'image',
      documentType: map['document_type']?.toString() ?? 'customs',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'trip_order_id': tripOrderId,
      'file_name': fileName,
      'file_url': fileUrl,
      'file_type': fileType,
      'document_type': documentType,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
