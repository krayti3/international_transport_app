import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';
import '../services/notification_service.dart';

part 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit() : super(const ChatState()) {
    _loadInitialMessages();
    _subscription = Supabase.instance.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .listen((rows) {
          if (!isClosed) {
            _handleStreamUpdate(rows);
          }
        });
  }

  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  int _lastMessageCount = 0;

  void _handleStreamUpdate(List<Map<String, dynamic>> rows) {
    final messages = rows.map((m) => ChatMessage.fromMap(m)).toList();
    final currentUserId = _supabase.auth.currentUser?.id;

    if (state.isChatActive && currentUserId != null) {
      final unreadMessages = messages.where((m) => !m.isMine && !m.isRead).toList();
      if (unreadMessages.isNotEmpty) {
        final messageIds = unreadMessages.map((m) => m.id).toList();
        _supabase
            .from('chat_messages')
            .update({'read_at': DateTime.now().toIso8601String()})
            .inFilter('id', messageIds)
            .then((_) {
              if (!isClosed) {
                emit(state.copyWith(messages: messages, isLoading: false));
              }
            });
        return;
      }
    }

    if (!state.isChatActive && messages.length > _lastMessageCount && currentUserId != null) {
      final newMessages = messages.where((m) => !m.isMine).toList();
      if (newMessages.isNotEmpty) {
        final latest = newMessages.last;
        final senderName = _resolveSenderName(latest.senderId);
        NotificationService().showChatNotification(
          sender: senderName,
          message: latest.message.isNotEmpty ? latest.message : (latest.imageUrl != null ? 'صورة' : 'رسالة جديدة'),
          payload: 'chat',
        );
      }
    }

    _lastMessageCount = messages.length;
    emit(state.copyWith(messages: messages, isLoading: false));
  }

  Future<void> _loadInitialMessages() async {
    try {
      final messages = await _supabase
          .from('chat_messages')
          .select()
          .order('created_at', ascending: true)
          .limit(200);

      final userIds = messages
          .map((m) => m['sender_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final userNames = <String, String>{};
      if (userIds.isNotEmpty) {
        final users = await _supabase
            .from('users')
            .select('id, name, email')
            .inFilter('id', userIds);
        for (final u in users) {
          final uid = u['id']?.toString() ?? '';
          final name = (u['name']?.toString() ?? u['email']?.toString() ?? '').trim();
          if (uid.isNotEmpty) userNames[uid] = name.isEmpty ? 'مستخدم' : name;
        }
      }

      final mapped = messages.map((m) => ChatMessage.fromMap(m)).toList();
      _lastMessageCount = mapped.length;
      emit(state.copyWith(messages: mapped, userNames: userNames, isLoading: false));
    } catch (e) {
      debugPrint('Error loading chat messages: $e');
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    emit(state.copyWith(isSending: true, errorMessage: null));
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        emit(state.copyWith(isSending: false, errorMessage: 'يجب تسجيل الدخول'));
        return;
      }

      await _supabase.from('chat_messages').insert({
        'sender_id': user.id,
        'message': trimmed,
      });

      emit(state.copyWith(isSending: false));
    } catch (e) {
      debugPrint('Error sending chat message: $e');
      emit(state.copyWith(isSending: false, errorMessage: e.toString()));
    }
  }

  Future<void> sendImageMessage(String imageUrl) async {
    emit(state.copyWith(isSending: true, errorMessage: null));
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        emit(state.copyWith(isSending: false, errorMessage: 'يجب تسجيل الدخول'));
        return;
      }

      await _supabase.from('chat_messages').insert({
        'sender_id': user.id,
        'message': '',
        'image_url': imageUrl,
      });

      emit(state.copyWith(isSending: false));
    } catch (e) {
      debugPrint('Error sending image message: $e');
      emit(state.copyWith(isSending: false, errorMessage: e.toString()));
    }
  }

  Future<String> uploadChatImage(File image) async {
    try {
      final extension = image.path.split('.').last.toLowerCase();
      final fileName = 'chat/${DateTime.now().millisecondsSinceEpoch}.$extension';
      
      await _supabase.storage
          .from('chat')
          .upload(fileName, image);

      final publicUrl = _supabase.storage
          .from('chat')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading chat image: $e');
      rethrow;
    }
  }

  void setChatActive(bool isActive) {
    emit(state.copyWith(isChatActive: isActive));
    if (isActive) {
      _markVisibleMessagesAsRead();
    }
  }

  Future<void> _markVisibleMessagesAsRead() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final unreadMessages = state.messages
          .where((m) => !m.isMine && !m.isRead)
          .toList();

      if (unreadMessages.isEmpty) return;

      final messageIds = unreadMessages.map((m) => m.id).toList();
      await _supabase
          .from('chat_messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .inFilter('id', messageIds);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  String displayNameFor(String senderId) {
    final cached = state.userNames[senderId];
    if (cached != null) return cached;
    final current = _supabase.auth.currentUser;
    if (current != null && senderId == current.id) return 'أنا';
    return 'مستخدم';
  }

  String _resolveSenderName(String senderId) {
    final cached = state.userNames[senderId];
    if (cached != null) return cached;
    final current = _supabase.auth.currentUser;
    if (current != null && senderId == current.id) return 'أنا';
    return 'مستخدم';
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
