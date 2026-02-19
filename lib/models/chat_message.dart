enum MessageRole { user, assistant, system }

enum MessageStatus { complete, streaming, error }

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final String? thinkingContent;
  final MessageStatus status;
  final String? errorMessage;
  final int? tokenCount;
  final int? latencyMs;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.thinkingContent,
    this.status = MessageStatus.complete,
    this.errorMessage,
    this.tokenCount,
    this.latencyMs,
  });

  bool get hasThinking => thinkingContent != null && thinkingContent!.isNotEmpty;
  bool get isStreaming => status == MessageStatus.streaming;
  bool get hasError => status == MessageStatus.error;

  ChatMessage copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    String? thinkingContent,
    MessageStatus? status,
    String? errorMessage,
    int? tokenCount,
    int? latencyMs,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      thinkingContent: thinkingContent ?? this.thinkingContent,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      tokenCount: tokenCount ?? this.tokenCount,
      latencyMs: latencyMs ?? this.latencyMs,
    );
  }
}

/// A conversation groups messages by agent.
class Conversation {
  final String id;
  final String agentId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  const Conversation({
    required this.id,
    required this.agentId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  Conversation copyWith({
    String? id,
    String? agentId,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return Conversation(
      id: id ?? this.id,
      agentId: agentId ?? this.agentId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }
}
