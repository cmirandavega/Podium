import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/league.dart';
import '../../models/matchup.dart';
import '../../models/roster_slot.dart';
import '../../models/team.dart';
import '../../services/live_score_service.dart';
import '../../services/matchup_service.dart';
import '../../services/team_service.dart';
import '../../services/wager_service.dart';
import '../../theme.dart';
import '../../widgets/podium_ui.dart';
import '../matchups/matchups_screen.dart';
import 'shell_widgets.dart';

/// Matchup: this week's head-to-head with a player-by-player lineup
/// comparison. Points show once lineups lock (live) or the week is final.
class MatchupTab extends StatefulWidget {
  const MatchupTab({
    super.key,
    required this.user,
    required this.league,
    required this.leagues,
    required this.onSelectLeague,
  });

  final AppUser user;
  final League league;
  final List<League> leagues;
  final ValueChanged<String> onSelectLeague;

  @override
  State<MatchupTab> createState() => _MatchupTabState();
}

class _MatchupTabState extends State<MatchupTab> {
  late final Stream<List<Matchup>> _games = MatchupService().watchMatchups(widget.league.id);
  late final Stream<List<Team>> _teams = TeamService().watchTeamsInLeague(widget.league.id);

  void _openSchedule() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MatchupsScreen(
          leagueId: widget.league.id,
          userId: widget.user.uid,
          // Same hook as the league hub: scoring a week settles its wagers.
          matchups: MatchupService(onWeekScored: WagerService().settleInBatch),
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final league = widget.league;
    final myTeamId = Team.idFor(league.id, widget.user.uid);
    final inSeason = league.phase == 'regular' || league.phase == 'playoffs';

    return SafeArea(
      bottom: false,
      child: StreamBuilder<List<Team>>(
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
              final current = game;
              final live = inSeason && league.lineupLocked && current != null && !current.isFinal;

              return ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  ShellHeader(
                    title: inSeason ? 'Week ${league.currentWeek} Matchup' : 'Matchup',
                    below: LeagueSwitcher(
                      leagues: widget.leagues,
                      active: league,
                      onSelect: widget.onSelectLeague,
                    ),
                    trailing: [
                      if (live) const StatusPill.live(),
                      IconButton(
                        tooltip: 'All games and schedule',
                        icon: const Icon(Icons.calendar_month_outlined),
                        onPressed: _openSchedule,
                      ),
                    ],
                  ),
                  if (league.isCommissioner(widget.user.uid) && inSeason)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: PodiumCard(
                        radius: PodiumRadii.tile,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        borderColor: PodiumColors.gold,
                        onTap: _openSchedule,
                        child: Row(
                          children: [
                            const Icon(Icons.workspace_premium_outlined, color: PodiumColors.gold, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                league.lineupLocked
                                    ? 'Commissioner: score week ${league.currentWeek}'
                                    : 'Commissioner: lock lineups for week ${league.currentWeek}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: PodiumColors.gold),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: !inSeason
                        ? EmptyCard(
                            icon: Icons.sports_score_outlined,
                            title: league.phase == 'complete' ? 'Season complete' : 'Season not started',
                            message: league.phase == 'complete'
                                ? 'Check the Leaders tab for final standings.'
                                : 'Matchups start when the commissioner starts the season.',
                          )
                        : current == null
                            ? const EmptyCard(
                                icon: Icons.sports_score_outlined,
                                title: 'No game this week',
                                message: 'Your team has no matchup scheduled for this week.',
                              )
                            : current.isBye
                                ? const EmptyCard(
                                    icon: Icons.weekend_outlined,
                                    title: 'Bye week',
                                    message: 'Your team sits this week out.',
                                  )
                                : _GameDetail(
                                    key: ValueKey('detail_${current.id}'),
                                    league: league,
                                    game: current,
                                    myTeamId: myTeamId,
                                    teams: teams,
                                  ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Scoreboard plus the lineup comparison for one game.
class _GameDetail extends StatefulWidget {
  const _GameDetail({
    super.key,
    required this.league,
    required this.game,
    required this.myTeamId,
    required this.teams,
  });

  final League league;
  final Matchup game;
  final String myTeamId;
  final Map<String, Team> teams;

  @override
  State<_GameDetail> createState() => _GameDetailState();
}

class _GameDetailState extends State<_GameDetail> {
  late final String _oppId =
      widget.game.homeTeamId == widget.myTeamId ? widget.game.awayTeamId! : widget.game.homeTeamId;
  late final Stream<List<RosterSlot>> _myRoster = TeamService().watchRoster(widget.myTeamId);
  late final Stream<List<RosterSlot>> _oppRoster = TeamService().watchRoster(_oppId);
  final _live = LiveScoreService();
  Future<Map<String, double>>? _points;
  bool _bench = false;

  /// Player points, once the week is locked or final. Never before, so
  /// lineups can't be set with the answers in hand.
  Future<Map<String, double>>? get _pointsFuture {
    final showPoints = widget.game.isFinal || widget.league.lineupLocked;
    if (!showPoints) return null;
    return _points ??= _live.pointsForWeek(widget.league, widget.game.week);
  }

  @override
  Widget build(BuildContext context) {
    final league = widget.league;
    final me = widget.teams[widget.myTeamId];
    final opp = widget.teams[_oppId];
    return StreamBuilder<List<RosterSlot>>(
      stream: _myRoster,
      builder: (context, mySnap) {
        return StreamBuilder<List<RosterSlot>>(
          stream: _oppRoster,
          builder: (context, oppSnap) {
            return FutureBuilder<Map<String, double>>(
              future: _pointsFuture,
              builder: (context, pointSnap) {
                final points = pointSnap.data;
                final myRoster = mySnap.data ?? const <RosterSlot>[];
                final oppRoster = oppSnap.data ?? const <RosterSlot>[];

                double? myScore;
                double? oppScore;
                final isHome = widget.game.homeTeamId == widget.myTeamId;
                if (widget.game.isFinal) {
                  myScore = isHome ? widget.game.homeScore : widget.game.awayScore;
                  oppScore = isHome ? widget.game.awayScore : widget.game.homeScore;
                } else if (points != null) {
                  myScore = LiveScoreService.starterPoints(
                      roster: myRoster, points: points, starterCount: league.starterCount);
                  oppScore = LiveScoreService.starterPoints(
                      roster: oppRoster, points: points, starterCount: league.starterCount);
                }

                final myList = myRoster.where((s) => s.isStarter != _bench).toList();
                final oppList = oppRoster.where((s) => s.isStarter != _bench).toList();
                final rows = myList.length > oppList.length ? myList.length : oppList.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Scoreboard(
                      me: me,
                      opp: opp,
                      myScore: myScore,
                      oppScore: oppScore,
                      status: widget.game.isFinal
                          ? 'Final'
                          : (league.lineupLocked ? 'Live · lineups locked' : 'Lineups open'),
                    ),
                    const SizedBox(height: 16),
                    _Segmented(
                      bench: _bench,
                      onChanged: (v) => setState(() => _bench = v),
                    ),
                    const SizedBox(height: 12),
                    PodiumCard(
                      padding: EdgeInsets.zero,
                      radius: PodiumRadii.tile + 2,
                      child: rows == 0
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                _bench ? 'No one on either bench.' : 'No starters set yet.',
                                style: const TextStyle(color: PodiumColors.muted),
                              ),
                            )
                          : Column(
                              children: [
                                for (var i = 0; i < rows; i++) ...[
                                  if (i > 0) const Divider(),
                                  _LineupRow(
                                    mine: i < myList.length ? myList[i] : null,
                                    theirs: i < oppList.length ? oppList[i] : null,
                                    points: points,
                                  ),
                                ],
                              ],
                            ),
                    ),
                    if (points == null && !widget.game.isFinal)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'Player points appear once the commissioner locks lineups.',
                          textAlign: TextAlign.center,
                          style: PodiumText.caption,
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({
    required this.me,
    required this.opp,
    required this.myScore,
    required this.oppScore,
    required this.status,
  });

  final Team? me;
  final Team? opp;
  final double? myScore;
  final double? oppScore;
  final String status;

  @override
  Widget build(BuildContext context) {
    final a = myScore;
    final b = oppScore;
    final hasScores = a != null && b != null;
    final total = (a ?? 0) + (b ?? 0);
    final share = total > 0 ? (a ?? 0) / total : 0.5;

    Widget side({required Team? team, required String fallback, required double? score, required bool mine}) {
      final name = team?.teamName ?? fallback;
      return Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: mine ? TextDirection.ltr : TextDirection.rtl,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: mine ? PodiumColors.gold : PodiumColors.silver,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  InitialsAvatar.initialsOf(name),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: PodiumColors.navy),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: mine ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      mine ? 'You · ${team?.record ?? '0-0'}' : (team?.record ?? '0-0'),
                      style: const TextStyle(fontSize: 11, color: PodiumColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              score == null ? '–' : formatPoints(score),
              style: PodiumText.score(size: 52, color: mine ? PodiumColors.gold : PodiumColors.chalk),
            ),
          ),
        ],
      );
    }

    return PodiumCard(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: side(team: me, fallback: 'Your team', score: a, mine: true)),
              const SizedBox(width: 12),
              Expanded(child: side(team: opp, fallback: 'Opponent', score: b, mine: false)),
            ],
          ),
          const SizedBox(height: 16),
          SplitBar(leftShare: share),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                hasScores ? '${(share * 100).round()}%' : status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: hasScores ? PodiumColors.gold : PodiumColors.muted,
                ),
              ),
              const Spacer(),
              Text(
                hasScores ? status : '',
                style: const TextStyle(fontSize: 12, color: PodiumColors.muted),
              ),
              if (hasScores) ...[
                const SizedBox(width: 8),
                Text(
                  '${((1 - share) * 100).round()}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PodiumColors.silver),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.bench, required this.onChanged});

  final bool bench;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool value) {
      final on = bench == value;
      return Expanded(
        child: Material(
          color: on ? PodiumColors.line : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onChanged(value),
            child: Container(
              height: 40,
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: on ? PodiumColors.chalk : PodiumColors.muted,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PodiumColors.field,
        borderRadius: BorderRadius.circular(PodiumRadii.control),
        border: Border.all(color: PodiumColors.line),
      ),
      child: Row(children: [seg('Starters', false), seg('Bench', true)]),
    );
  }
}

/// One row: my player | position | their player.
class _LineupRow extends StatelessWidget {
  const _LineupRow({required this.mine, required this.theirs, required this.points});

  final RosterSlot? mine;
  final RosterSlot? theirs;
  final Map<String, double>? points;

  @override
  Widget build(BuildContext context) {
    final p = points;
    final a = mine;
    final b = theirs;
    final ap = a == null || p == null ? null : (p[a.playerId] ?? 0);
    final bp = b == null || p == null ? null : (p[b.playerId] ?? 0);
    final aWins = ap != null && bp != null && ap > bp;
    final bWins = ap != null && bp != null && bp > ap;
    final pos = (a?.slotPosition.isNotEmpty ?? false) ? a!.slotPosition : (b?.slotPosition ?? '');

    TextStyle ptsStyle(bool win) => PodiumText.score(
          size: 20,
          weight: win ? FontWeight.w700 : FontWeight.w600,
          color: win ? PodiumColors.gold : PodiumColors.muted,
        );

    Widget player(RosterSlot? s, double? pts, bool win, bool end) {
      if (s == null) {
        return Text('—', textAlign: end ? TextAlign.right : TextAlign.left, style: PodiumText.caption);
      }
      final details = [s.realTeam, s.sport].where((x) => x.isNotEmpty).join(' · ');
      final name = Text(
        s.playerName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: end ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      );
      final score = Text(pts == null ? '–' : formatPoints(pts), style: ptsStyle(win));
      return Column(
        crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            children: end
                ? [score, const SizedBox(width: 6), Expanded(child: name)]
                : [Expanded(child: name), const SizedBox(width: 6), score],
          ),
          Text(details, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: PodiumColors.muted)),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(child: player(a, ap, aWins, false)),
          Container(
            width: 46,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(vertical: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: PodiumColors.navy, borderRadius: BorderRadius.circular(6)),
            child: Text(
              pos.isEmpty ? '·' : pos,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: PodiumColors.silver),
            ),
          ),
          Expanded(child: player(b, bp, bWins, true)),
        ],
      ),
    );
  }
}
