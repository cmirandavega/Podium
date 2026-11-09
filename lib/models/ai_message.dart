import 'package:cloud_firestore/cloud_firestore.dart';

/// One message in an AI conversation. Stored for the Coach at
/// coachConversations/{conversationId}/messages/{messageId}.
///
/// role, content, and createdAt are from the database table. A Coach reply
/// can also carry a lineup suggestion (startPlayerId, benchPlayerId, and
/// suggestionStatus, added in Sprint 4) that the user can apply or dismiss.
class AiMessage {
  const AiMessage({
    required this.role,
    required this.content,
    this.id,
    this.createdAt,
    this.startPlayerId,
    this.benchPlayerId,
    this.suggestionStatus,
  });

  const AiMessage.user(String content) : this(role: 'user', content: content);
  const AiMessage.assistant(String content)
      : this(role: 'assistant', content: content);

  final String? id;
  final String role; // "user" or "assistant"
  final String content;
  final DateTime? createdAt;
  final String? startPlayerId;
  final String? benchPlayerId;
  final String? suggestionStatus; // "pending", "applied", "dismissed"

  bool get isUser => role == 'user';
  bool get hasSuggestion => startPlayerId != null && benchPlayerId != null;

  factory AiMessage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AiMessage(
      id: doc.id,
      role: data['role'] as String? ?? 'user',
      content: data['content'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      startPlayerId: data['startPlayerId'] as String?,
      benchPlayerId: data['benchPlayerId'] as String?,
      suggestionStatus: data['suggestionStatus'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'role': role,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
        if (hasSuggestion) ...{
          'startPlayerId': startPlayerId,
          'benchPlayerId': benchPlayerId,
          'suggestionStatus': suggestionStatus ?? 'pending',
        },
      };
}
