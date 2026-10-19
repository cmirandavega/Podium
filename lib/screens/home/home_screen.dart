
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/podium_mark.dart';
import '../admin/admin_screen.dart';
import '../profile/profile_screen.dart';
import '../scores/scores_screen.dart';

import '../../services/user_service.dart';
import '../reports/report_user_screen.dart';
import '/screens/mock_draft_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PodiumMark(scale: 0.5),
            SizedBox(width: 10),
            Text('Podium', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          if (user.isAdmin)
            IconButton(
              tooltip: 'Admin tools',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminScreen(currentUser: user),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Live scoring',
            icon: const Icon(Icons.sports_football_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ScoresScreen())),
          ),
          NotificationBell(uid: user.uid),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProfileScreen(user: user)),
            ),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Welcome, ${user.nameToShow}',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '@${user.username}',
              style: const TextStyle(color: PodiumColors.muted),
            ),
            const SizedBox(height: 32),

            OutlinedButton.icon(
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Report a User'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: const Text('Select User to Report'),
                      ),
                      body: StreamBuilder<List<AppUser>>(
                        stream: UserService().watchAllUsers(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Center(
                              child: Text('Unable to load users.'),
                            );
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final users = snapshot.data!
                              .where(
                                (other) =>
                                    other.uid != user.uid && !other.isAdmin,
                              )
                              .toList();

                          if (users.isEmpty) {
                            return const Center(
                              child: Text('No users available to report.'),
                            );
                          }

                          return ListView.builder(
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final other = users[index];

                              return ListTile(
                                leading: const Icon(Icons.person_outline),
                                title: Text(other.nameToShow),
                                subtitle: Text('@${other.username}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ReportUserScreen(reportedUser: other),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            OutlinedButton.icon(
              icon: const Icon(Icons.sports_esports_outlined),
              label: const Text('Mock Draft Simulator'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MockDraftScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            Text(
              'My leagues',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            // Placeholder: the league use case replaces this with the user's leagues.
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: PodiumColors.field,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PodiumColors.line),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "You're not in any leagues yet.",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Create a league or join one with an invite to start building your roster.',
                    style: TextStyle(color: PodiumColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
