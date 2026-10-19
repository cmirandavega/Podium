import 'package:cloud_firestore/cloud_firestore.dart';

class UserReport {
  const UserReport({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    required this.reason,
    required this.details,
    required this.status,
    this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  final String id;
  final String reporterId;
  final String reportedUserId;
  final String reason;
  final String details;
  final String status;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  factory UserReport.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return UserReport(
      id: doc.id,
      reporterId: data['reporterId'] as String? ?? '',
      reportedUserId: data['reportedUserId'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      details: data['details'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'] as String?,
    );
  }
}
