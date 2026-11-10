import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/league.dart';
import '../../services/league_service.dart';
import '../../theme.dart';
import '../../widgets/podium_ui.dart';
import 'create_league_screen.dart';
import 'join_league_screen.dart';
import 'league_home_screen.dart';

/// "My leagues" on the home screen: the user's leagues plus create and join.
class MyLeaguesSection extends StatefulWidget {
  const MyLeaguesSection({super.key, required this.user});

  final AppUser user;

  @override
  State<MyLeaguesSection> createState() => _MyLeaguesSectionState();
}

class _MyLeaguesSectionState extends State<MyLeaguesSection> {
  late final Stream<List<League>> _stream = LeagueService().watchMyLeagues(widget.user.uid);

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('My leagues'),
        const SizedBox(height: 10),
        StreamBuilder<List<League>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Unable to load your leagues.');
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final leagues = snapshot.data!;
            if (leagues.isEmpty) {
              return const EmptyCard(
                icon: Icons.emoji_events_outlined,
                title: "You're not in any leagues yet",
                message: 'Create a league or join one with an invite code to start building your roster.',
              );
            }
            return Column(
              children: [
                for (final league in leagues)
                  _LeagueCard(
                    league: league,
                    onTap: () => _open(LeagueHomeScreen(leagueId: league.id, user: widget.user)),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Create'),
                onPressed: () => _open(CreateLeagueScreen(user: widget.user)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Join'),
                onPressed: () => _open(JoinLeagueScreen(user: widget.user)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LeagueCard extends StatelessWidget {
  const _LeagueCard({required this.league, required this.onTap});

  final League league;
  final VoidCallback onTap;

  Widget get _phasePill => switch (league.phase) {
        'regular' => StatusPill.gold('WEEK ${league.currentWeek}'),
        'playoffs' => const StatusPill.gold('PLAYOFFS'),
        'complete' => const StatusPill(label: 'FINAL'),
        _ => const StatusPill(label: 'PRESEASON'),
      };

  @override
  Widget build(BuildContext context) {
    return PodiumCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      onTap: onTap,
      child: Row(
        children: [
          const TintedIcon(icon: Icons.emoji_events_outlined, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  league.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${league.sports.join(' · ')}  •  ${league.memberIds.length}/${league.maxTeams} teams',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: PodiumColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _phasePill,
          const Icon(Icons.chevron_right, color: PodiumColors.muted),
        ],
      ),
    );
  }
}
