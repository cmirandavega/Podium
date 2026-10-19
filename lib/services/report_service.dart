import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_report.dart';

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> submitReport({
    required String reportedUserId,
    required String reason,
    required String details,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw StateError('You must be logged in.');
    }

    if (currentUser.uid == reportedUserId) {
      throw StateError('You cannot report yourself.');
    }

    if (reason.trim().isEmpty) {
      throw ArgumentError('A report reason is required.');
    }

    if (details.length > 1000) {
      throw ArgumentError('Report details are too long.');
    }

    await _db.collection('reports').add({
      'reporterId': currentUser.uid,
      'reportedUserId': reportedUserId,
      'reason': reason.trim(),
      'details': details.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'reviewedAt': null,
      'reviewedBy': null,
    });
  }

  Stream<List<UserReport>> watchReports() {
    return _db
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(UserReport.fromFirestore).toList(),
        );
  }

  Future<void> reviewReport({
    required String reportId,
    required String status,
  }) async {
    final admin = _auth.currentUser;

    if (admin == null) {
      throw StateError('You must be logged in.');
    }

    if (!['dismissed', 'warned', 'suspended'].contains(status)) {
      throw ArgumentError('Invalid review status.');
    }

    final reportRef = _db.collection('reports').doc(reportId);

    await _db.runTransaction((transaction) async {
      final report = await transaction.get(reportRef);

      if (!report.exists || report.data()?['status'] != 'pending') {
        throw StateError('This report is no longer pending.');
      }

      final reportedUserId = report.data()?['reportedUserId'] as String?;

      if (reportedUserId == null || reportedUserId.isEmpty) {
        throw StateError('Reported user is missing.');
      }

      if (status == 'warned' || status == 'suspended') {
        final userRef = _db.collection('users').doc(reportedUserId);
        final user = await transaction.get(userRef);

        if (!user.exists || user.data()?['role'] == 'admin') {
          throw StateError('This account cannot be moderated.');
        }

        final currentStatus = user.data()?['status'];

        if (currentStatus == 'suspended' && status == 'warned') {
          throw StateError(
            'A suspended account cannot be downgraded to a warning.',
          );
        }

        transaction.update(userRef, {'status': status});
      }

      transaction.update(reportRef, {
        'status': status,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': admin.uid,
      });
      if (status == 'warned' || status == 'suspended') {
        final noticeRef = _db.collection('moderationNotices').doc(reportId);

        transaction.set(noticeRef, {
          'userId': reportedUserId,
          'reason': report.data()?['reason'] ?? 'Account moderation',
          'status': status,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
