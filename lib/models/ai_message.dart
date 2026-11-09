import 'package:cloud_firestore/cloud_firestore.dart';

/// One message in an AI conversation. Stored for the Coach at
/// coachConversations/{conversationId}/messages/{messageId}.
class AiMessage {
  const AiMessage({
    required this.role,
    required this.content,
    this.id,
    this.createdAt,
  });

  const AiMessage.user(String content) : this(role: 'user', content: content);
  const AiMessage.assistant(String content)
      : this(role: 'assistant', content: content);

  final String? id;
  final String role; // "user" or "assistant"
  final String content;
  final DateTime? createdAt;

  bool get isUser => role == 'user';

  factory AiMessage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AiMessage(
      id: doc.id,
      role: data['role'] as String? ?? 'user',
      content: data['content'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'role': role,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
