import 'package:cloud_firestore/cloud_firestore.dart';

/// A league chat message, stored at leagues/{leagueId}/messages/{messageId}
/// (Use Case 7). senderName is copied from the sender's username (added in
/// Sprint 4) so the chat doesn't need a read per message.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.isDeleted,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String body;
  final bool isDeleted;
  final DateTime? createdAt;

  static const maxLength = 500;

  factory ChatMessage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'member',
      body: data['body'] as String? ?? '',
      isDeleted: data['isDeleted'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
