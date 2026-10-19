import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';

/// Use Case 6: creates and reads notifications in the notifications collection.
class NotificationService {
  NotificationService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('notifications');

  /// Document data for a new notification. Also used inside the
  /// registration transaction so the welcome message is written atomically.
  static Map<String, dynamic> newNotificationData({
    required String userId,
    required String type,
    required String message,
    String? relatedId,
  }) {
    return {
      'userId': userId,
      'type': type,
      'message': message,
      'relatedId': relatedId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Live list of one user's notifications, newest first.
  /// Sorted on the device so no composite Firestore index is needed.
  Stream<List<AppNotification>> watchForUser(String uid) {
    return _notifications.where('userId', isEqualTo: uid).snapshots().map((query) {
      final now = DateTime.now();
      final items = query.docs.map(AppNotification.fromFirestore).toList();
      items.sort((a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now));
      return items;
    });
  }

  Stream<int> watchUnreadCount(String uid) {
    return watchForUser(uid).map((items) => items.where((n) => !n.isRead).length);
  }

  Future<void> send({
    required String userId,
    required String type,
    required String message,
    String? relatedId,
  }) {
    return _notifications.add(newNotificationData(
      userId: userId,
      type: type,
      message: message,
      relatedId: relatedId,
    ));
  }

  Future<void> markAsRead(String notificationId) {
    return _notifications.doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllAsRead(List<AppNotification> items) async {
    final unread = items.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;
    final batch = _db.batch();
    for (final n in unread) {
      batch.update(_notifications.doc(n.id), {'isRead': true});
    }
    await batch.commit();
  }
}
