import 'package:supabase_flutter/supabase_flutter.dart';

class ChatMessage {
  final int id;
  final String senderId;
  final String message;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? readAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.message,
    this.imageUrl,
    required this.createdAt,
    this.readAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: (map['id'] as num).toInt(),
      senderId: map['sender_id']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      imageUrl: map['image_url']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      readAt: map['read_at'] != null ? DateTime.tryParse(map['read_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender_id': senderId,
      'message': message,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }

  bool get isMine {
    final current = Supabase.instance.client.auth.currentUser;
    return current != null && senderId == current.id;
  }

  bool get isRead => readAt != null;
}
