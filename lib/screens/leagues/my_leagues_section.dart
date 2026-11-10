import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/league.dart';
import '../../services/league_service.dart';
import '../../theme.dart';
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
        Text(
          'My leagues',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<League>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Unable to load your leagues.');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final leagues = snapshot.data!;
            if (leagues.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: PodiumColors.field,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PodiumColors.line),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("You're not in any leagues yet.",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    Text(
                      'Create a league or join one with an invite code to start building your roster.',
                      style: TextStyle(color: PodiumColors.muted),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final league in leagues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: PodiumColors.field,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: PodiumColors.line),
                        ),
                        leading: const Icon(Icons.emoji_events_outlined, color: PodiumColors.gold),
                        title: Text(league.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${league.sports.join(' · ')}  •  ${league.memberIds.length}/${league.maxTeams} teams',
                          style: const TextStyle(color: PodiumColors.muted),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(LeagueHomeScreen(leagueId: league.id, user: widget.user)),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
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
