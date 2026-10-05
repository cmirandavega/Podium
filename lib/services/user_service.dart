import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

/// Reads and updates user profiles in the users collection.
class UserService {
  UserService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  /// Live profile for one user; emits null until the document exists.
  Stream<AppUser?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map(
          (snapshot) => snapshot.exists ? AppUser.fromFirestore(snapshot) : null,
        );
  }

  Future<void> updateDisplayName(String uid, String displayName) {
    return _users.doc(uid).update({'displayName': displayName.trim()});
  }

  /// All users, newest first. Admin screen only.
  Stream<List<AppUser>> watchAllUsers() {
    return _users
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((query) => query.docs.map(AppUser.fromFirestore).toList());
  }

  /// Admin action: "active" or "suspended". Security rules block non-admins.
  Future<void> setStatus(String uid, String status) {
    return _users.doc(uid).update({'status': status});
  }
}
