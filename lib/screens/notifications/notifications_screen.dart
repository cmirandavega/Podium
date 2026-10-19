import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import '../../theme.dart';

/// Use Case 6: the signed-in user's notification inbox.
/// Reading the list is database to GUI; marking as read is GUI to database.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.uid});

  final String uid;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();
  late final Stream<List<AppNotification>> _stream = _service.watchForUser(widget.uid);

  Future<void> _run(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Not updated. Check your connection and try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: _stream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <AppNotification>[];
        final unread = items.where((n) => !n.isRead).length;

        Widget body;
        if (snapshot.hasError) {
          body = const _Message(
            title: 'Notifications did not load.',
            body: 'Check your connection and try again.',
          );
        } else if (!snapshot.hasData) {
          body = const Center(child: CircularProgressIndicator());
        } else if (items.isEmpty) {
          body = const _Message(
            title: 'No notifications yet.',
            body: 'Trade offers, lineup reminders, and league updates will show up here.',
          );
        } else {
          body = ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: PodiumColors.line),
            itemBuilder: (context, index) {
              final n = items[index];
              return _NotificationTile(
                notification: n,
                onTap: n.isRead ? null : () => _run(() => _service.markAsRead(n.id)),
              );
            },
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (unread > 0)
                TextButton(
                  onPressed: () => _run(() => _service.markAllAsRead(items)),
                  child: const Text('Mark all as read'),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(child: body),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, this.onTap});

  final AppNotification notification;
  final VoidCallback? onTap;

  static IconData _iconFor(String type) {
    switch (type) {
      case 'welcome':
        return Icons.celebration_outlined;
      case 'profile_updated':
        return Icons.person_outline;
      case 'account_status':
        return Icons.shield_outlined;
      case 'trade_offer':
        return Icons.swap_horiz;
      case 'lineup_lock':
        return Icons.lock_clock_outlined;
      case 'chat_mention':
        return Icons.chat_bubble_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  static String _timeAgo(DateTime? time) {
    if (time == null) return 'Just now';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return diff.inDays == 1 ? 'Yesterday' : '${diff.inDays} days ago';
    return '${time.month}/${time.day}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      onTap: onTap,
      leading: Icon(_iconFor(n.type), color: n.isRead ? PodiumColors.muted : PodiumColors.gold),
      title: Text(
        n.message,
        style: TextStyle(
          fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w600,
          color: n.isRead ? PodiumColors.muted : PodiumColors.chalk,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(_timeAgo(n.createdAt), style: const TextStyle(color: PodiumColors.muted)),
      ),
      trailing: n.isRead
          ? null
          : Semantics(
              label: 'Unread',
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: PodiumColors.gold, shape: BoxShape.circle),
              ),
            ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none, size: 48, color: PodiumColors.muted),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: PodiumColors.muted)),
          ],
        ),
      ),
    );
  }
}
