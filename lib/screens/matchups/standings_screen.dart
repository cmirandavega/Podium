import 'package:flutter/material.dart';

import '../../models/league.dart';
import '../../models/team.dart';
import '../../services/season_engine.dart';
import '../../services/team_service.dart';
import '../../theme.dart';

/// Use Case 11: league standings, ranked by win-loss record with total
/// points as the tiebreaker. Updates live as weeks are scored.
class StandingsScreen extends StatelessWidget {
  const StandingsScreen({super.key, required this.league, required this.userId});

  final League league;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Standings')),
      body: StreamBuilder<List<Team>>(
        stream: TeamService().watchTeamsInLeague(league.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final teams = SeasonEngine.standings(snapshot.data!);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Row(
                children: [
                  SizedBox(width: 32, child: Text('#', style: TextStyle(color: PodiumColors.muted))),
                  Expanded(child: Text('Team', style: TextStyle(color: PodiumColors.muted))),
                  SizedBox(width: 64, child: Text('W-L', style: TextStyle(color: PodiumColors.muted))),
                  SizedBox(
                    width: 72,
                    child: Text('Points', textAlign: TextAlign.right, style: TextStyle(color: PodiumColors.muted)),
                  ),
                ],
              ),
              const Divider(),
              for (var i = 0; i < teams.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: switch (i) {
                              0 => PodiumColors.gold,
                              1 => PodiumColors.silver,
                              2 => PodiumColors.bronze,
                              _ => PodiumColors.chalk,
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          teams[i].teamName,
                          style: TextStyle(
                            fontWeight: teams[i].ownerId == userId ? FontWeight.w700 : FontWeight.w400,
                            color: teams[i].ownerId == userId ? PodiumColors.gold : PodiumColors.chalk,
                          ),
                        ),
                      ),
                      SizedBox(width: 64, child: Text(teams[i].record)),
                      SizedBox(
                        width: 72,
                        child: Text(teams[i].pointsFor.toStringAsFixed(1), textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                ),
                if (league.playoffTeams > 0 && i == league.playoffTeams - 1 && i < teams.length - 1)
                  const Row(
                    children: [
                      Expanded(child: Divider(color: PodiumColors.gold)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('Playoff line', style: TextStyle(color: PodiumColors.gold, fontSize: 12)),
                      ),
                      Expanded(child: Divider(color: PodiumColors.gold)),
                    ],
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
