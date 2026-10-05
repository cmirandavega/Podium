import 'package:cloud_firestore/cloud_firestore.dart';

/// A Podium account, stored in Firestore at users/{uid}.
class AppUser {
  const AppUser({
    required this.uid,
    required this.username,
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
    this.createdAt,
  });

  final String uid;
  final String username;
  final String email;
  final String displayName;
  final String role; // "user" or "admin"
  final String status; // "active" or "suspended"
  final DateTime? createdAt;

  bool get isAdmin => role == 'admin';
  bool get isSuspended => status == 'suspended';
  String get nameToShow => displayName.isNotEmpty ? displayName : username;

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppUser(
      uid: doc.id,
      username: data['username'] as String? ?? '',
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: data['role'] as String? ?? 'user',
      status: data['status'] as String? ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
