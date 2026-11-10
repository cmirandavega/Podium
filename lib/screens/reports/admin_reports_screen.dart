import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/user_report.dart';
import '../../services/report_service.dart';
import '../../services/user_service.dart';
import '../../theme.dart';
import '../../widgets/podium_ui.dart';

/// Use Case 14: admins review user reports. Each report shows who was
/// reported (name, username, standing, and how many reports they have),
/// who reported them, and the reported chat message when there is one.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final _service = ReportService();
  late final Stream<List<UserReport>> _reports = _service.watchReports();
  late final Stream<List<AppUser>> _users = UserService().watchAllUsers();
  final Set<String> _busy = {};

  Future<void> _review(UserReport report, String status) async {
    setState(() => _busy.add(report.id));
    try {
      await _service.reviewReport(reportId: report.id, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Report marked as $status.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Review failed: $error')));
    } finally {
      if (mounted) setState(() => _busy.remove(report.id));
    }
  }

  Future<void> _confirmSuspend(UserReport report, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Suspend $name?'),
        content: const Text('Their account is suspended and they are signed out right away.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: PodiumColors.dangerText),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _review(report, 'suspended');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('User reports'),
          bottom: const TabBar(tabs: [Tab(text: 'Pending'), Tab(text: 'Reviewed')]),
        ),
        body: StreamBuilder<List<AppUser>>(
          stream: _users,
          builder: (context, userSnap) {
            final users = {for (final u in userSnap.data ?? const <AppUser>[]) u.uid: u};
            return StreamBuilder<List<UserReport>>(
              stream: _reports,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Unable to load reports.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final reports = snapshot.data!;
                final counts = <String, int>{};
                for (final r in reports) {
                  counts[r.reportedUserId] = (counts[r.reportedUserId] ?? 0) + 1;
                }
                final pending = reports.where((r) => r.status == 'pending').toList();
                final reviewed = reports.where((r) => r.status != 'pending').toList();
                return TabBarView(
                  children: [
                    _list(pending, users, counts, 'No pending reports. Nice and quiet.'),
                    _list(reviewed, users, counts, 'No reviewed reports yet.'),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _list(List<UserReport> reports, Map<String, AppUser> users, Map<String, int> counts, String empty) {
    if (reports.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [EmptyCard(icon: Icons.flag_outlined, title: 'All clear', message: empty)],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: reports.length,
      itemBuilder: (context, i) {
        final r = reports[i];
        return _ReportCard(
          report: r,
          reported: users[r.reportedUserId],
          reporter: users[r.reporterId],
          reviewer: r.reviewedBy == null ? null : users[r.reviewedBy],
          totalReports: counts[r.reportedUserId] ?? 1,
          busy: _busy.contains(r.id),
          onDismiss: () => _review(r, 'dismissed'),
          onWarn: () => _review(r, 'warned'),
          onSuspend: () => _confirmSuspend(r, users[r.reportedUserId]?.nameToShow ?? 'this user'),
        );
      },
    );
  }
}

/// A chat message pulled out of a report made from league chat.
typedef ReportedMessage = ({String league, String text});

/// Chat reports store the message in details as
/// League "<name>" chat: "<message>" (see ChatService.reportMessage).
ReportedMessage? reportedMessageOf(UserReport report) {
  final match = RegExp(r'^League "(.*?)" chat: "([\s\S]*)"$').firstMatch(report.details.trim());
  if (match == null) return null;
  return (league: match.group(1)!, text: match.group(2)!);
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.reported,
    required this.reporter,
    required this.reviewer,
    required this.totalReports,
    required this.busy,
    required this.onDismiss,
    required this.onWarn,
    required this.onSuspend,
  });

  final UserReport report;
  final AppUser? reported;
  final AppUser? reporter;
  final AppUser? reviewer;
  final int totalReports;
  final bool busy;
  final VoidCallback onDismiss;
  final VoidCallback onWarn;
  final VoidCallback onSuspend;

  static String _when(DateTime? t) {
    if (t == null) return 'just now';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${t.month}/${t.day}/${t.year}';
  }

  Widget _standing(AppUser? user) {
    if (user == null) return const StatusPill(label: 'UNKNOWN');
    if (user.isSuspended) {
      return const StatusPill(label: 'SUSPENDED', color: PodiumColors.dangerText, background: PodiumColors.dangerTint);
    }
    if (user.isWarned) return const StatusPill(label: 'WARNED', color: PodiumColors.bronzeText, background: PodiumColors.bronzeTint);
    return const StatusPill(label: 'GOOD STANDING');
  }

  Widget _outcome() => switch (report.status) {
        'suspended' => const StatusPill(label: 'SUSPENDED', color: PodiumColors.dangerText, background: PodiumColors.dangerTint),
        'warned' => const StatusPill(label: 'WARNED', color: PodiumColors.bronzeText, background: PodiumColors.bronzeTint),
        'dismissed' => const StatusPill(label: 'DISMISSED'),
        _ => const StatusPill.gold('PENDING'),
      };

  @override
  Widget build(BuildContext context) {
    final message = reportedMessageOf(report);
    final name = reported?.nameToShow ?? 'Unknown user';
    final pending = report.status == 'pending';

    return PodiumCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      borderColor: pending ? PodiumColors.gold : PodiumColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Who was reported.
          Row(
            children: [
              InitialsAvatar(
                name: name,
                size: 46,
                ring: totalReports > 1 ? PodiumColors.danger : PodiumColors.line,
                ringWidth: 2,
                foreground: PodiumColors.chalk,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    SelectableText(
                      reported == null ? report.reportedUserId : '@${reported!.username}',
                      style: const TextStyle(fontSize: 12, color: PodiumColors.muted),
                    ),
                  ],
                ),
              ),
              _standing(reported),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _outcome(),
              StatusPill.gold(report.reason.toUpperCase()),
              if (totalReports > 1)
                StatusPill(
                  label: '$totalReports REPORTS TOTAL',
                  color: PodiumColors.dangerText,
                  background: PodiumColors.dangerTint,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // The reported message, or the reporter's details.
          if (message != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: PodiumColors.navy,
                borderRadius: BorderRadius.circular(PodiumRadii.control),
                border: Border.all(color: PodiumColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.forum_outlined, size: 16, color: PodiumColors.silver),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'REPORTED MESSAGE · ${message.league.toUpperCase()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PodiumText.overline.copyWith(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 3, height: 20, color: PodiumColors.danger),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SelectableText(
                          message.text,
                          style: const TextStyle(fontSize: 15, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else if (report.details.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: PodiumColors.navy,
                borderRadius: BorderRadius.circular(PodiumRadii.control),
                border: Border.all(color: PodiumColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('REPORTER\'S DETAILS', style: PodiumText.overline.copyWith(fontSize: 11)),
                  const SizedBox(height: 8),
                  SelectableText(report.details, style: const TextStyle(fontSize: 14, height: 1.45)),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Who reported, and when.
          Text(
            'Reported by ${reporter == null ? 'a member' : '@${reporter!.username}'} · ${_when(report.createdAt)}'
            '${!pending && report.reviewedAt != null ? ' · reviewed ${_when(report.reviewedAt)}'
                '${reviewer == null ? '' : ' by @${reviewer!.username}'}' : ''}',
            style: PodiumText.caption,
          ),

          if (pending) ...[
            const SizedBox(height: 14),
            if (busy)
              const LinearProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                      onPressed: onDismiss,
                      child: const Text('Dismiss'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        foregroundColor: PodiumColors.bronzeText,
                        side: const BorderSide(color: PodiumColors.bronze),
                      ),
                      onPressed: onWarn,
                      child: const Text('Warn'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        backgroundColor: PodiumColors.danger,
                        foregroundColor: PodiumColors.navy,
                      ),
                      onPressed: reported?.isAdmin == true ? null : onSuspend,
                      child: const Text('Suspend'),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
