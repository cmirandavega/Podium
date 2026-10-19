import 'package:flutter/material.dart';

import '../screens/notifications/notifications_screen.dart';
import '../services/notification_service.dart';
import '../theme.dart';

/// App bar bell with a live unread count. Turns gold and filled when
/// there are unread notifications, and back to an outline once they're read.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, required this.uid});

  final String uid;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  late final Stream<int> _unread = NotificationService().watchUnreadCount(widget.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unread,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final hasUnread = count > 0;
        return IconButton(
          tooltip: hasUnread ? 'Notifications, $count unread' : 'Notifications',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => NotificationsScreen(uid: widget.uid)),
          ),
          icon: Badge(
            isLabelVisible: hasUnread,
            label: Text(count > 9 ? '9+' : '$count'),
            backgroundColor: PodiumColors.gold,
            textColor: PodiumColors.navy,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                hasUnread ? Icons.notifications_active : Icons.notifications_outlined,
                key: ValueKey(hasUnread),
                color: hasUnread ? PodiumColors.gold : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
