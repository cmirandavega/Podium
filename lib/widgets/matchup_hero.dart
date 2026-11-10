import 'package:flutter/material.dart';

import '../models/league.dart';
import '../models/matchup.dart';
import '../models/team.dart';
import '../services/live_score_service.dart';
import '../services/matchup_service.dart';
import '../services/team_service.dart';
import '../theme.dart';
import 'podium_ui.dart';

/// The signed-in user's game this week, scoreboard style: final scores once
/// the week is scored, live scores while lineups are locked, and records
/// before that.
class MatchupHeroCard extends StatefulWidget {
  const MatchupHeroCard({
    super.key,
    required this.league,
    required this.userId,
    required this.onOpen,
  });

  final League league;
  final String userId;
  final VoidCallback onOpen;

  @override
  State<MatchupHeroCard> createState() => _MatchupHeroCardState();
}

class _MatchupHeroCardState extends State<MatchupHeroCard> {
  late final Stream<List<Team>> _teams = TeamService().watchTeamsInLeague(widget.league.id);
  late final Stream<List<Matchup>> _games = MatchupService().watchMatchups(widget.league.id);
  final _live = LiveScoreService();
  Future<({double home, double away})>? _liveFuture;
  String? _liveKey;

  /// Starts (or reuses) the live score lookup for [game].
  Future<({double home, double away})> _liveFor(Matchup game) {
    final key = '${game.id}_${widget.league.lineupLocked}';
    if (_liveKey != key || _liveFuture == null) {
      _liveKey = key;
      _liveFuture = _live.liveScores(widget.league, game);
    }
    return _liveFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final league = widget.league;
    final myTeamId = Team.idFor(league.id, widget.userId);
    return StreamBuilder<List<Team>>(
      stream: _teams,
      builder: (context, teamSnap) {
        final teams = {for (final t in teamSnap.data ?? const <Team>[]) t.id: t};
        return StreamBuilder<List<Matchup>>(
          stream: _games,
          builder: (context, gameSnap) {
            Matchup? game;
            for (final g in gameSnap.data ?? const <Matchup>[]) {
              if (g.week == league.currentWeek && g.involves(myTeamId)) game = g;
            }
            if (game == null) {
              return PodiumCard(
                onTap: widget.onOpen,
                child: const Row(
                  children: [
                    TintedIcon(icon: Icons.sports_score_outlined),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Your matchup shows here once the commissioner starts the season.',
                        style: TextStyle(color: PodiumColors.silver),
                      ),
                    ),
                  ],
                ),
              );
            }

            final isHome = game.homeTeamId == myTeamId;
            final oppId = isHome ? game.awayTeamId : game.homeTeamId;
            final me = teams[myTeamId];
            final opp = oppId == null ? null : teams[oppId];

            if (game.isBye) {
              return PodiumCard(
                onTap: widget.onOpen,
                child: Row(
                  children: [
                    const TintedIcon(icon: Icons.weekend_outlined),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Bye week. ${me?.teamName ?? 'Your team'} sits out week ${league.currentWeek}.',
                        style: const TextStyle(color: PodiumColors.silver),
                      ),
                    ),
                  ],
                ),
              );
            }

            if (game.isFinal) {
              return _card(
                game: game,
                me: me,
                opp: opp,
                myScore: isHome ? game.homeScore : game.awayScore,
                oppScore: isHome ? game.awayScore : game.homeScore,
                pill: game.winnerTeamId == myTeamId
                    ? const StatusPill.gold('WIN')
                    : StatusPill(label: game.winnerTeamId == null ? 'TIE' : 'FINAL'),
                footer: 'Final',
              );
            }

            if (league.lineupLocked) {
              final current = game;
              return FutureBuilder<({double home, double away})>(
                future: _liveFor(current),
                builder: (context, live) {
                  final scores = live.data;
                  return _card(
                    game: current,
                    me: me,
                    opp: opp,
                    myScore: scores == null ? null : (isHome ? scores.home : scores.away),
                    oppScore: scores == null ? null : (isHome ? scores.away : scores.home),
                    pill: const StatusPill.live(),
                    footer: live.hasError ? 'Scores unavailable' : 'Lineups locked',
                  );
                },
              );
            }

            return _card(
              game: game,
              me: me,
              opp: opp,
              myScore: null,
              oppScore: null,
              pill: const StatusPill(label: 'UPCOMING'),
              footer: 'Lineups open',
            );
          },
        );
      },
    );
  }

  Widget _card({
    required Matchup game,
    required Team? me,
    required Team? opp,
    required double? myScore,
    required double? oppScore,
    required Widget pill,
    required String footer,
  }) {
    final hasScores = myScore != null && oppScore != null;
    final total = hasScores ? myScore! + oppScore! : 0.0;
    final share = total > 0 ? myScore! / total : 0.5;
    final diff = hasScores ? myScore! - oppScore! : 0.0;
    final week = widget.league.currentWeek;

    return PodiumCard(
      onTap: widget.onOpen,
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              pill,
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  game.isPlayoff ? 'Playoffs · week $week' : 'Week $week matchup',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: PodiumColors.muted, fontWeight: FontWeight.w500),
                ),
              ),
              Text(footer, style: const TextStyle(fontSize: 12, color: PodiumColors.muted)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _side(
                  score: hasScores ? formatPoints(myScore!) : (me?.record ?? '0-0'),
                  name: me?.teamName ?? 'Your team',
                  detail: 'You · ${me?.record ?? '0-0'}',
                  color: PodiumColors.gold,
                  end: false,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'VS',
                  style: PodiumText.score(size: 15, color: PodiumColors.muted, weight: FontWeight.w600)
                      .copyWith(letterSpacing: 1.5),
                ),
              ),
              Expanded(
                child: _side(
                  score: hasScores ? formatPoints(oppScore!) : (opp?.record ?? '0-0'),
                  name: opp?.teamName ?? 'Opponent',
                  detail: opp?.record ?? '0-0',
                  color: PodiumColors.chalk,
                  end: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                hasScores ? 'Point share' : 'Records',
                style: const TextStyle(fontSize: 12, color: PodiumColors.muted),
              ),
              const Spacer(),
              Text(
                hasScores
                    ? (diff >= 0 ? 'Up ${formatPoints(diff)}' : 'Down ${formatPoints(-diff)}')
                    : '${(share * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: diff >= 0 ? PodiumColors.gold : PodiumColors.dangerText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProbabilityBar(value: hasScores ? share : _recordShare(me, opp)),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.league.lineupLocked || game.isFinal
                      ? '${widget.league.starterCount} starters a side'
                      : 'Set your starters before lineups lock',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: PodiumColors.muted),
                ),
              ),
              const Text(
                'View matchup',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PodiumColors.gold),
              ),
              const Icon(Icons.chevron_right, size: 18, color: PodiumColors.gold),
            ],
          ),
        ],
      ),
    );
  }

  /// Before any points: the two teams' win percentages as a rough edge.
  double _recordShare(Team? me, Team? opp) {
    final a = me?.winPct ?? 0;
    final b = opp?.winPct ?? 0;
    return a + b == 0 ? 0.5 : a / (a + b);
  }

  Widget _side({
    required String score,
    required String name,
    required String detail,
    required Color color,
    required bool end,
  }) {
    return Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(score, style: PodiumText.score(size: 46, color: color)),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: end ? TextAlign.right : TextAlign.left,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(detail, style: PodiumText.caption),
      ],
    );
  }
}
