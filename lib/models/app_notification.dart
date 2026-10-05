import 'package:cloud_firestore/cloud_firestore.dart';
/// notification for one user, stored in Firestore
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.message,
    required this.isRead,
    this.createdAt,
    this.relatedId,
  });

  final String id;
  final String userId;
  final String type; // welcome, profile_updated, account_status, trade offer, ...
  final String message;
  final bool isRead;
  final String? relatedId;
  final DateTime? createdAt; // null for a moment while the server timestamp is pending

  factory AppNotification.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      type: data['type'] as String? ?? 'general',
      message: data['message'] as String? ?? '',
      isRead: data['isRead'] as bool? ?? false,
      relatedId: data['relatedId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}