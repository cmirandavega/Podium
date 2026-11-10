import 'package:flutter/material.dart';

import '../../models/league.dart';
import '../../models/matchup.dart';
import '../../models/team.dart';
import '../../services/league_service.dart';
import '../../services/matchup_service.dart';
import '../../services/team_service.dart';
import '../../theme.dart';
import '../../widgets/podium_ui.dart';
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
    return PodiumCard(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      borderColor: PodiumColors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_outlined, color: PodiumColors.gold, size: 18),
              const SizedBox(width: 8),
              Text('COMMISSIONER', style: PodiumText.overline.copyWith(color: PodiumColors.gold)),
            ],
          ),
          const SizedBox(height: 12),
          ...buttons,
          if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        ],
      ),
    );
  }

  Widget _game(Matchup m, Map<String, Team> teams) {
    final myTeamId = Team.idFor(widget.leagueId, widget.userId);
    final mine = m.involves(myTeamId);
    String name(String? id) => id == null ? 'Bye' : (teams[id]?.teamName ?? 'Team');

    Widget side(String? id, double score) {
      final isMe = id == myTeamId;
      final won = m.isFinal && m.winnerTeamId != null && m.winnerTeamId == id;
      final lost = m.isFinal && m.winnerTeamId != null && m.winnerTeamId != id;
      final showScore = m.isFinal && !(m.isBye && id == m.awayTeamId);
      return Row(
        children: [
          InitialsAvatar(
            name: name(id),
            size: 34,
            ring: isMe ? PodiumColors.gold : PodiumColors.line,
            ringWidth: isMe ? 2 : 1.5,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name(id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: won || isMe ? FontWeight.w700 : FontWeight.w500,
                    color: lost ? PodiumColors.muted : PodiumColors.chalk,
                  ),
                ),
                if (id != null && teams[id] != null)
                  Text(
                    isMe ? 'You · ${teams[id]!.record}' : teams[id]!.record,
                    style: PodiumText.caption,
                  ),
              ],
            ),
          ),
          Text(
            showScore ? formatPoints(score) : '–',
            style: PodiumText.score(
              size: 28,
              weight: won ? FontWeight.w700 : FontWeight.w600,
              color: won ? (isMe ? PodiumColors.gold : PodiumColors.chalk) : PodiumColors.muted,
            ),
          ),
        ],
      );
    }

    final Widget pill;
    if (m.isFinal) {
      pill = StatusPill(label: m.isBye ? 'BYE' : (m.winnerTeamId == null ? 'FINAL · TIE' : 'FINAL'));
    } else {
      pill = const StatusPill(label: 'SCHEDULED');
    }
    final total = m.homeScore + m.awayScore;

    return PodiumCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      borderColor: mine ? PodiumColors.gold : PodiumColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              pill,
              const SizedBox(width: 8),
              if (m.isPlayoff)
                StatusPill.gold(m.round >= 2 ? 'CHAMPIONSHIP' : 'SEMIFINAL'),
              const Spacer(),
              if (mine) const Text('Your game', style: TextStyle(fontSize: 12, color: PodiumColors.gold, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          side(m.homeTeamId, m.homeScore),
          const SizedBox(height: 12),
          side(m.awayTeamId, m.awayScore),
          if (m.isFinal && !m.isBye && total > 0) ...[
            const SizedBox(height: 14),
            SplitBar(leftShare: m.homeScore / total, height: 6),
          ],
        ],
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
                        PodiumCard(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          borderColor: PodiumColors.gold,
                          child: Row(
                            children: [
                              const TintedIcon(icon: Icons.emoji_events, size: 48),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('CHAMPION', style: PodiumText.overline.copyWith(color: PodiumColors.gold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${teams[league.championTeamId]?.teamName ?? 'Champion'} won the league!',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                    ),
                                  ],
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
                          height: 56,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
