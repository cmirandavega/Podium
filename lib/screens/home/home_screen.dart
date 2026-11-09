
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
import '../leagues/league_dashboard_screen.dart';
import '../leagues/league_sports_screen.dart';
import '../../services/league_feature_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/push_registration_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    // Registers this device once; errors are ignored when push is not configured.
    PushRegistrationService.register(user.uid);
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
            OutlinedButton.icon(
              icon: const Icon(Icons.add), label: const Text('Create League'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LeagueSportsScreen())),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: LeagueFeatureService.instance.leagues(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text('Unable to load leagues: ${snapshot.error}');
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final leagues = snapshot.data!.docs;
                if (leagues.isEmpty) return const Text('No leagues yet. Create one to begin.');
                return Column(children: leagues.map((league) => Card(child: ListTile(
                  title: Text('${league.data()['name'] ?? league.id}'),
                  subtitle: Text((league.data()['sports'] as List<dynamic>? ?? []).join(', ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LeagueDashboardScreen(leagueId: league.id))),
                ))).toList());
              },
            ),
          ],
        ),
      ),
    );
  }
}
