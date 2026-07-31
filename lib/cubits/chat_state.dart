part of 'chat_cubit.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;
  final Map<String, String> userNames;
  final bool isSending;
  final bool isChatActive;

  const ChatState({
    this.messages = const [],
    this.isLoading = true,
    this.errorMessage,
    this.userNames = const {},
    this.isSending = false,
    this.isChatActive = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
    Map<String, String>? userNames,
    bool? isSending,
    bool? isChatActive,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      userNames: userNames ?? this.userNames,
      isSending: isSending ?? this.isSending,
      isChatActive: isChatActive ?? this.isChatActive,
    );
  }
}
