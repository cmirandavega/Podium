import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../theme.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/podium_ui.dart';
import '../admin/admin_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../leagues/my_leagues_section.dart';
import '../mock_draft_screen.dart';
import '../profile/profile_screen.dart';
import '../reports/report_user_screen.dart';
import '../scores/scores_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.user});

  final AppUser user;

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String get _firstName {
    final name = user.nameToShow.trim();
    return name.isEmpty ? 'there' : name.split(' ').first;
  }

  String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLine = '${_weekdays[now.weekday - 1]} · ${_months[now.month - 1]} ${now.day}'.toUpperCase();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: const PodiumWordmark(size: 22),
        actions: [
          if (user.isAdmin)
            IconButton(
              tooltip: 'Admin tools',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => _push(context, AdminScreen(currentUser: user)),
            ),
          IconButton(
            tooltip: 'Live scoring',
            icon: const Icon(Icons.sports_football_outlined),
            onPressed: () => _push(context, const ScoresScreen()),
          ),
          NotificationBell(uid: user.uid),
          PopupMenuButton<String>(
            tooltip: 'Account',
            icon: InitialsAvatar(
              name: user.nameToShow,
              size: 34,
              ring: PodiumColors.gold,
              foreground: PodiumColors.chalk,
            ),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  _push(context, ProfileScreen(user: user));
                case 'report':
                  _openReportPicker(context);
                case 'logout':
                  AuthService().signOut();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'profile',
                child: ListTile(leading: Icon(Icons.person_outline), title: Text('Profile')),
              ),
              PopupMenuItem(
                value: 'report',
                child: ListTile(leading: Icon(Icons.flag_outlined), title: Text('Report a user')),
              ),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(leading: Icon(Icons.logout), title: Text('Log out')),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(dateLine, style: PodiumText.overline),
            const SizedBox(height: 6),
            Text(
              '${_greeting(now)}, $_firstName',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 2),
            Text('@${user.username}', style: const TextStyle(color: PodiumColors.muted)),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: QuickActionTile(
                    icon: Icons.sports_football_outlined,
                    label: 'Live scores',
                    caption: 'Every sport',
                    onTap: () => _push(context, const ScoresScreen()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: QuickActionTile(
                    icon: Icons.emoji_events_outlined,
                    label: 'Leaderboard',
                    caption: 'Top teams',
                    color: PodiumColors.silver,
                    tint: PodiumColors.silverTint,
                    onTap: () => _push(context, const LeaderboardScreen()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: QuickActionTile(
                    icon: Icons.grid_view_rounded,
                    label: 'Mock draft',
                    caption: 'Practice',
                    color: PodiumColors.bronzeText,
                    tint: PodiumColors.bronzeTint,
                    onTap: () => _push(context, const MockDraftScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            MyLeaguesSection(user: user),
            const SizedBox(height: 26),
            PodiumCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              radius: PodiumRadii.tile,
              onTap: () => _openReportPicker(context),
              child: const Row(
                children: [
                  TintedIcon(
                    icon: Icons.flag_outlined,
                    color: PodiumColors.dangerText,
                    background: PodiumColors.dangerTint,
                    size: 36,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Report a user', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text(
                          'Flag harassment or cheating for admin review',
                          style: TextStyle(fontSize: 12, color: PodiumColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: PodiumColors.muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pick another (non-admin) user, then open the report form.
  void _openReportPicker(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Who are you reporting?')),
          body: StreamBuilder<List<AppUser>>(
            stream: UserService().watchAllUsers(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Unable to load users.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final users = snapshot.data!
                  .where((other) => other.uid != user.uid && !other.isAdmin)
                  .toList();
              if (users.isEmpty) {
                return const Center(child: Text('No users available to report.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                itemCount: users.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final other = users[index];
                  return PodiumCard(
                    radius: PodiumRadii.tile,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ReportUserScreen(reportedUser: other)),
                    ),
                    child: Row(
                      children: [
                        InitialsAvatar(name: other.nameToShow),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(other.nameToShow, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('@${other.username}',
                                  style: const TextStyle(fontSize: 12, color: PodiumColors.muted)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: PodiumColors.muted),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
