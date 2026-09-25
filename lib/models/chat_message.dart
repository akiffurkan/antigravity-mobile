enum MessageRole {
  user,
  antigravity,
  tool,
  system,
}

enum MessageType {
  text,
  code,
  command,
  toolExecution,
  approvalCard,
  error,
}

class ChatMessage {
  final String id;
  final String sessionId;
  final MessageRole role;
  final MessageType type;
  final String content;
  final DateTime timestamp;
  final bool isStreaming;
  final String? toolName;
  final String? toolCallId;
  final String? codeSnippet;
  final String? language;
  final String? approvalRequestId;

  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    this.type = MessageType.text,
    required this.content,
    required this.timestamp,
    this.isStreaming = false,
    this.toolName,
    this.toolCallId,
    this.codeSnippet,
    this.language,
    this.approvalRequestId,
  });

  ChatMessage copyWith({
    String? id,
    String? sessionId,
    MessageRole? role,
    MessageType? type,
    String? content,
    DateTime? timestamp,
    bool? isStreaming,
    String? toolName,
    String? toolCallId,
    String? codeSnippet,
    String? language,
    String? approvalRequestId,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      type: type ?? this.type,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      toolName: toolName ?? this.toolName,
      toolCallId: toolCallId ?? this.toolCallId,
      codeSnippet: codeSnippet ?? this.codeSnippet,
      language: language ?? this.language,
      approvalRequestId: approvalRequestId ?? this.approvalRequestId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'role': role.name,
      'type': type.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isStreaming': isStreaming,
      'toolName': toolName,
      'toolCallId': toolCallId,
      'codeSnippet': codeSnippet,
      'language': language,
      'approvalRequestId': approvalRequestId,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      role: MessageRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => MessageRole.antigravity,
      ),
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      content: json['content'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
      isStreaming: json['isStreaming'] as bool? ?? false,
      toolName: json['toolName'] as String?,
      toolCallId: json['toolCallId'] as String?,
      codeSnippet: json['codeSnippet'] as String?,
      language: json['language'] as String?,
      approvalRequestId: json['approvalRequestId'] as String?,
    );
  }
}
