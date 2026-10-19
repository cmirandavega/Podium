import 'package:flutter/material.dart';

import '../../models/user_report.dart';
import '../../services/report_service.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final _service = ReportService();
  late final Stream<List<UserReport>> _reports = _service.watchReports();

  Future<void> _review(UserReport report, String status) async {
    try {
      await _service.reviewReport(reportId: report.id, status: status);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Report marked as $status.')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Review failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Reports')),
      body: StreamBuilder<List<UserReport>>(
        stream: _reports,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load reports.'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data!;

          if (reports.isEmpty) {
            return const Center(child: Text('No reports submitted yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.reason,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        'Reported user ID: ${report.reportedUserId}',
                      ),
                      Text('Details: ${report.details}'),
                      Text('Status: ${report.status}'),
                      const SizedBox(height: 12),
                      if (report.status == 'pending')
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () => _review(report, 'dismissed'),
                              child: const Text('Dismiss'),
                            ),
                            OutlinedButton(
                              onPressed: () => _review(report, 'warned'),
                              child: const Text('Warn'),
                            ),
                            FilledButton(
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Suspend user?'),
                                    content: const Text(
                                      'This will suspend the reported account.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: const Text('Suspend'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed == true) {
                                  await _review(report, 'suspended');
                                }
                              },
                              child: const Text('Suspend'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
