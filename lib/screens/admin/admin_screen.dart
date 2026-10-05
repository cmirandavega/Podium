import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/user_service.dart';
import '../../theme.dart';

/// Admin-only screen: suspend or reactivate accounts.
/// The button to open it only appears for admins, and Firestore Security
/// Rules reject status changes from anyone who is not an admin.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _users = UserService();
  late final Stream<List<AppUser>> _allUsers = _users.watchAllUsers();

  Future<void> _setActive(AppUser user, bool active) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _users.setStatus(user.uid, active ? 'active' : 'suspended');
      messenger.showSnackBar(SnackBar(
        content: Text(active
            ? '@${user.username} reactivated.'
            : '@${user.username} suspended.'),
      ));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Status not changed. Check your connection and try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin tools')),
      body: StreamBuilder<List<AppUser>>(
        stream: _allUsers,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Users did not load. Check your connection.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1, color: PodiumColors.line),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Text(
                    '${users.length} accounts. Turn off Active to suspend an account; '
                    'suspended players are signed out right away.',
                    style: const TextStyle(color: PodiumColors.muted),
                  ),
                );
              }
              final user = users[index - 1];
              final isSelf = user.uid == widget.currentUser.uid;
              return SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: Text(user.nameToShow),
                subtitle: Text(
                  '@${user.username}${user.isAdmin ? ', admin' : ''}${isSelf ? ' (you)' : ''}',
                  style: const TextStyle(color: PodiumColors.muted),
                ),
                value: !user.isSuspended,
                onChanged: isSelf ? null : (active) => _setActive(user, active),
                secondary: Icon(
                  user.isSuspended ? Icons.block : Icons.check_circle_outline,
                  color: user.isSuspended ? PodiumColors.danger : PodiumColors.gold,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
