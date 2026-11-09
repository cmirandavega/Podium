import 'package:flutter/material.dart';

import '../../models/team.dart';
import '../../models/weekly_report.dart';
import '../../services/matchup_service.dart';
import '../../services/team_service.dart';
import '../../theme.dart';

/// Use Case 5: a recap of each scored week for one team: points, matchup
/// result, how close the lineup was to the best possible one, and how the
/// team moved in the standings.
class WeeklyAnalysisScreen extends StatelessWidget {
  const WeeklyAnalysisScreen({super.key, required this.leagueId, required this.teamId});

  final String leagueId;
  final String teamId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Analysis')),
      body: StreamBuilder<List<Team>>(
        stream: TeamService().watchTeamsInLeague(leagueId),
        builder: (context, teamSnap) {
          final names = {for (final t in teamSnap.data ?? const <Team>[]) t.id: t.teamName};
          return StreamBuilder<List<WeeklyReport>>(
            stream: MatchupService().watchReports(teamId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final reports = snapshot.data!;
              if (reports.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Your first recap appears after the commissioner scores week 1.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: PodiumColors.muted),
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [for (final r in reports) _ReportCard(report: r, names: names)],
              );
            },
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.names});

  final WeeklyReport report;
  final Map<String, String> names;

  String get _headline => switch (report.result) {
        'W' => 'Won vs ${names[report.opponentTeamId] ?? 'opponent'}',
        'L' => 'Lost to ${names[report.opponentTeamId] ?? 'opponent'}',
        'T' => 'Tied ${names[report.opponentTeamId] ?? 'opponent'}',
        _ => 'Bye week',
      };

  Color get _color => switch (report.result) {
        'W' => PodiumColors.gold,
        'L' => PodiumColors.danger,
        _ => PodiumColors.silver,
      };

  @override
  Widget build(BuildContext context) {
    final efficiency = (report.rosterEfficiency * 100).clamp(0, 100).toStringAsFixed(0);
    final rankText = report.rankChange > 0
        ? 'Up ${report.rankChange} to #${report.rank}'
        : report.rankChange < 0
            ? 'Down ${-report.rankChange} to #${report.rank}'
            : 'Held at #${report.rank}';

    Widget stat(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: PodiumColors.muted, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        );

    return Card(
      color: PodiumColors.field,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Week ${report.week}', style: const TextStyle(color: PodiumColors.muted)),
            const SizedBox(height: 4),
            Text(_headline, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _color)),
            if (report.opponentPoints != null)
              Text(
                '${report.pointsEarned.toStringAsFixed(1)} - ${report.opponentPoints!.toStringAsFixed(1)}',
                style: const TextStyle(color: PodiumColors.muted),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                stat('Points', report.pointsEarned.toStringAsFixed(1)),
                stat('Lineup efficiency', '$efficiency%'),
                stat('Standings', rankText),
              ],
            ),
            const SizedBox(height: 12),
            if (report.topScorerName != null)
              Text('Top scorer: ${report.topScorerName} (${report.topScorerPoints?.toStringAsFixed(1)} pts)'),
            if (report.missedPoints > 0.05)
              Text(
                'Missed opportunity: the best possible lineup scored '
                '${report.optimalPoints.toStringAsFixed(1)}, '
                '${report.missedPoints.toStringAsFixed(1)} more than yours.'
                '${report.bestBenchName != null ? ' ${report.bestBenchName} scored ${report.bestBenchPoints?.toStringAsFixed(1)} on your bench.' : ''}',
                style: const TextStyle(color: PodiumColors.muted),
              )
            else
              const Text('You started your best possible lineup.', style: TextStyle(color: PodiumColors.muted)),
          ],
        ),
      ),
    );
  }
}
