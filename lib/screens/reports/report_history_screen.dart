import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReportHistoryScreen extends StatelessWidget {
  const ReportHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please log in.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Report History')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Reports I Submitted',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _ReportList(field: 'reporterId', uid: uid, submitted: true),
          const SizedBox(height: 24),
          Text(
            'Reports About Me',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _ReportList(field: 'userId', uid: uid, submitted: false),
        ],
      ),
    );
  }
}

class _ReportList extends StatelessWidget {
  const _ReportList({
    required this.field,
    required this.uid,
    required this.submitted,
  });

  final String field;
  final String uid;
  final bool submitted;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(submitted ? 'reports' : 'moderationNotices')
          .where(field, isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Could not load reports. Check permissions or connection.',
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final first = a.data()['createdAt'] as Timestamp?;
            final second = b.data()['createdAt'] as Timestamp?;
            return (second?.millisecondsSinceEpoch ?? 0).compareTo(
              first?.millisecondsSinceEpoch ?? 0,
            );
          });

        if (reports.isEmpty) {
          return Text(
            submitted
                ? 'You have not submitted any reports.'
                : 'No reports about your account.',
          );
        }

        return Column(
          children: reports.map((doc) {
            final data = doc.data();
            final status = data['status'] as String? ?? 'pending';
            final reason = data['reason'] as String? ?? 'Account moderation';
            final details = data['details'] as String? ?? '';

            return Card(
              child: ListTile(
                title: Text(reason),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: ${_statusLabel(status)}'),
                    if (submitted && details.isNotEmpty)
                      Text('Details: $details'),
                    if (!submitted && status != 'pending')
                      Text(_decisionMessage(status)),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'warned':
        return 'Warning Issued';
      case 'suspended':
        return 'Account Suspended';
      case 'dismissed':
        return 'Dismissed';
      default:
        return 'Pending Review';
    }
  }

  String _decisionMessage(String status) {
    switch (status) {
      case 'warned':
        return 'An administrator issued a warning.';
      case 'suspended':
        return 'An administrator suspended this account.';
      case 'dismissed':
        return 'The report was dismissed.';
      default:
        return '';
    }
  }
}
