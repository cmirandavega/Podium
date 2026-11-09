import 'package:flutter/material.dart';

import '../../models/league.dart';
import '../../models/team.dart';
import '../../services/team_service.dart';
import '../../theme.dart';
import 'team_screen.dart';

/// Every team in a league; tap one to see its roster.
class LeagueTeamsScreen extends StatelessWidget {
  const LeagueTeamsScreen({super.key, required this.league, required this.viewerId});

  final League league;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teams')),
      body: StreamBuilder<List<Team>>(
        stream: TeamService().watchTeamsInLeague(league.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final teams = [...snapshot.data!]..sort((a, b) => a.teamName.compareTo(b.teamName));
          return ListView(
            children: [
              for (final team in teams)
                ListTile(
                  leading: Icon(
                    team.ownerId == viewerId ? Icons.star : Icons.shield_outlined,
                    color: team.ownerId == viewerId ? PodiumColors.gold : PodiumColors.muted,
                  ),
                  title: Text(team.teamName),
                  subtitle: Text(team.record, style: const TextStyle(color: PodiumColors.muted)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TeamScreen(league: league, teamId: team.id, viewerId: viewerId),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
