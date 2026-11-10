import 'package:flutter/material.dart';

import '../../models/league.dart';
import '../../models/matchup.dart';
import '../../models/team.dart';
import '../../services/league_service.dart';
import '../../services/matchup_service.dart';
import '../../services/team_service.dart';
import '../../theme.dart';
import 'standings_screen.dart';

/// Use Case 15: the weekly schedule and results. The commissioner starts
/// the season, locks lineups, and scores each week here.
class MatchupsScreen extends StatefulWidget {
  const MatchupsScreen({
    super.key,
    required this.leagueId,
    required this.userId,
    this.matchups,
  });

  final String leagueId;
  final String userId;

  /// Optional service override, so features like wagers can hook into scoring.
  final MatchupService? matchups;

  @override
  State<MatchupsScreen> createState() => _MatchupsScreenState();
}

class _MatchupsScreenState extends State<MatchupsScreen> {
  late final MatchupService _service = widget.matchups ?? MatchupService();
  late final Stream<League?> _league = LeagueService().watchLeague(widget.leagueId);
  late final Stream<List<Matchup>> _games = _service.watchMatchups(widget.leagueId);
  late final Stream<List<Team>> _teams = TeamService().watchTeamsInLeague(widget.leagueId);
  int? _week;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _commissionerPanel(League league) {
    final List<Widget> buttons;
    switch (league.phase) {
      case 'preseason':
        buttons = [
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start season'),
            onPressed: _busy
                ? null
                : () => _run(() => _service.startSeason(league), 'Season started. Week 1 is set.'),
          ),
        ];
      case 'regular':
      case 'playoffs':
        buttons = [
          if (!league.lineupLocked)
            FilledButton.icon(
              icon: const Icon(Icons.lock_outline),
              label: Text('Lock lineups for week ${league.currentWeek}'),
              onPressed: _busy
                  ? null
                  : () => _run(() => _service.setLineupsLocked(league, true), 'Lineups locked.'),
            )
          else ...[
            FilledButton.icon(
              icon: const Icon(Icons.scoreboard_outlined),
              label: Text('Score week ${league.currentWeek}'),
              onPressed: _busy
                  ? null
                  : () => _run(() => _service.scoreCurrentWeek(league), 'Week ${league.currentWeek} is final.'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(() => _service.setLineupsLocked(league, false), 'Lineups unlocked.'),
              child: const Text('Unlock lineups'),
            ),
          ],
        ];
      default:
        buttons = const [];
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PodiumColors.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PodiumColors.gold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Commissioner', style: TextStyle(color: PodiumColors.gold, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...buttons,
          if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        ],
      ),
    );
  }

  Widget _game(Matchup m, Map<String, Team> teams) {
    String name(String? id) => id == null ? 'Bye' : (teams[id]?.teamName ?? 'Team');
    TextStyle style(String? id) => TextStyle(
          fontWeight: m.isFinal && m.winnerTeamId == id ? FontWeight.w700 : FontWeight.w400,
          color: m.involves(Team.idFor(widget.leagueId, widget.userId)) && id == Team.idFor(widget.leagueId, widget.userId)
              ? PodiumColors.gold
              : PodiumColors.chalk,
        );
    return Card(
      color: PodiumColors.field,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.isPlayoff)
              Text(
                m.round >= 2 ? 'Championship' : 'Playoff semifinal',
                style: const TextStyle(color: PodiumColors.gold, fontSize: 12),
              ),
            Row(
              children: [
                Expanded(child: Text(name(m.homeTeamId), style: style(m.homeTeamId))),
                Text(m.isFinal ? m.homeScore.toStringAsFixed(1) : '-', style: style(m.homeTeamId)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: Text(name(m.awayTeamId), style: style(m.awayTeamId))),
                Text(m.isFinal && !m.isBye ? m.awayScore.toStringAsFixed(1) : '-', style: style(m.awayTeamId)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              m.isFinal
                  ? (m.isBye ? 'Bye week' : (m.winnerTeamId == null ? 'Final · Tie' : 'Final'))
                  : 'Scheduled',
              style: const TextStyle(color: PodiumColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<League?>(
      stream: _league,
      builder: (context, leagueSnap) {
        final league = leagueSnap.data;
        if (league == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Matchups'),
            actions: [
              IconButton(
                tooltip: 'Standings',
                icon: const Icon(Icons.format_list_numbered),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => StandingsScreen(league: league, userId: widget.userId)),
                ),
              ),
            ],
          ),
          body: StreamBuilder<List<Team>>(
            stream: _teams,
            builder: (context, teamSnap) {
              final teams = {for (final t in teamSnap.data ?? const <Team>[]) t.id: t};
              return StreamBuilder<List<Matchup>>(
                stream: _games,
                builder: (context, gameSnap) {
                  final games = gameSnap.data ?? const <Matchup>[];
                  final weeks = {for (final g in games) g.week}.toList()..sort();
                  final selected = _week ?? (weeks.contains(league.currentWeek) ? league.currentWeek : (weeks.isEmpty ? null : weeks.last));
                  final shown = games.where((g) => g.week == selected).toList();

                  return ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      if (league.isCommissioner(widget.userId)) _commissionerPanel(league),
                      if (league.phase == 'complete' && league.championTeamId != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.emoji_events, color: PodiumColors.gold, size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${teams[league.championTeamId]?.teamName ?? 'Champion'} won the league!',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (league.lineupLocked)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Text('Lineups are locked for this week.', style: TextStyle(color: PodiumColors.muted)),
                        ),
                      if (games.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            "The schedule appears when the commissioner starts the season.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: PodiumColors.muted),
                          ),
                        )
                      else ...[
                        SizedBox(
                          height: 52,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            children: [
                              for (final w in weeks)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text('Week $w'),
                                    selected: selected == w,
                                    onSelected: (_) => setState(() => _week = w),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        for (final g in shown) _game(g, teams),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
