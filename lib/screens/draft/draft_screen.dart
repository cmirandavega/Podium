import 'package:flutter/material.dart';

import '../../models/draft.dart';
import '../../models/league.dart';
import '../../models/player_stat.dart';
import '../../models/scoring_period.dart';
import '../../models/team.dart';
import '../../services/draft_service.dart';
import '../../services/league_service.dart';
import '../../services/scoring_service.dart';
import '../../services/team_service.dart';
import '../../theme.dart';

/// Use Case 3: the live snake draft. Everyone watches the same board; only
/// the team on the clock can pick. The commissioner starts the draft and can
/// auto-pick for whoever is on the clock. Bot teams pick on their own while
/// the commissioner has this screen open.
class DraftScreen extends StatefulWidget {
  const DraftScreen({super.key, required this.leagueId, required this.userId});

  final String leagueId;
  final String userId;

  @override
  State<DraftScreen> createState() => _DraftScreenState();
}

class _DraftScreenState extends State<DraftScreen> {
  final _service = DraftService();
  final _scoring = ScoringService();
  final _search = TextEditingController();
  late final Stream<League?> _league = LeagueService().watchLeague(widget.leagueId);
  late final Stream<Draft?> _draft = _service.watchDraft(widget.leagueId);
  late final Stream<List<DraftPick>> _picks = _service.watchPicks(widget.leagueId);
  late final Stream<List<Team>> _teams = TeamService().watchTeamsInLeague(widget.leagueId);
  late final Stream<Set<String>> _taken = TeamService().watchTakenPlayerIds(widget.leagueId);
  late final Stream<List<ScoringPeriod>> _periods = _scoring.watchPeriods();

  Stream<List<PlayerWeek>>? _rankings;
  String? _rankingPeriodId;
  String _position = 'All';
  bool _showBoard = false;
  bool _busy = false;
  int? _botPickScheduledFor;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(League league, PlayerWeek player, {bool auto = false}) =>
      _run(() => _service.makePick(league: league, player: player, auto: auto));

  /// Players are ranked by points in the latest loaded week of the season.
  void _ensureRankings(League league, List<ScoringPeriod> periods) {
    final season = periods.where((p) => p.season == league.season).toList();
    if (season.isEmpty || _rankingPeriodId == season.first.id) return;
    _rankingPeriodId = season.first.id;
    _rankings = _scoring.watchWeek(season.first.id);
  }

  /// On the commissioner's device, bot teams pick the best available player
  /// a moment after they come on the clock.
  void _maybeRunBot(League league, Draft draft, Map<String, Team> teams, List<PlayerWeek> available) {
    if (!league.isCommissioner(widget.userId) || !draft.isLive || available.isEmpty) return;
    final owner = teams[draft.currentTeamId]?.ownerId ?? '';
    if (!owner.startsWith('bot_') || _botPickScheduledFor == draft.pickNumber) return;
    _botPickScheduledFor = draft.pickNumber;
    final choice = available.first;
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _pick(league, choice, auto: true);
    });
  }

  Widget _clock(League league, Draft draft, Map<String, Team> teams) {
    final current = teams[draft.currentTeamId];
    final mine = draft.currentTeamId == Team.idFor(league.id, widget.userId);
    final upcoming = draft.upcoming(4).map((id) => teams[id]?.teamName ?? 'Team').join('  →  ');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mine ? PodiumColors.gold.withValues(alpha: 0.2) : PodiumColors.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mine ? PodiumColors.gold : PodiumColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Round ${draft.round} · Pick ${draft.pickInRound} · ${draft.pickNumber + 1} of ${draft.totalPicks}',
            style: const TextStyle(color: PodiumColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            mine ? "You're on the clock!" : '${current?.teamName ?? 'Team'} is on the clock',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: mine ? PodiumColors.gold : PodiumColors.chalk,
            ),
          ),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Up next: $upcoming', style: const TextStyle(color: PodiumColors.muted, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _players(League league, Draft draft, List<PlayerWeek> available, int week) {
    final mine = draft.currentTeamId == Team.idFor(league.id, widget.userId);
    final positions = {'All', for (final p in available) if (p.position != null) p.position!}.toList();
    final query = _search.text.trim().toLowerCase();
    final shown = available
        .where((p) => _position == 'All' || p.position == _position)
        .where((p) => query.isEmpty || p.fullName.toLowerCase().contains(query) || p.realTeam.toLowerCase().contains(query))
        .take(150)
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(labelText: 'Search players', prefixIcon: Icon(Icons.search)),
            onChanged: (_) => setState(() {}),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final pos in positions)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(pos),
                    selected: _position == pos,
                    onSelected: (_) => setState(() => _position = pos),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Ranked by points in week $week', style: const TextStyle(color: PodiumColors.muted, fontSize: 12)),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: shown.length,
            itemBuilder: (context, i) {
              final p = shown[i];
              return ListTile(
                title: Text(p.fullName),
                subtitle: Text(
                  '${p.position ?? '?'} · ${p.realTeam} · ${p.sport}',
                  style: const TextStyle(color: PodiumColors.muted),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(p.points.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(64, 36)),
                      onPressed: mine && !_busy && draft.isLive ? () => _pick(league, p) : null,
                      child: const Text('Pick'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _board(List<DraftPick> picks, Map<String, Team> teams) {
    if (picks.isEmpty) {
      return const Center(child: Text('No picks yet.', style: TextStyle(color: PodiumColors.muted)));
    }
    return ListView.builder(
      itemCount: picks.length,
      itemBuilder: (context, i) {
        final p = picks[i];
        final mine = p.teamId.endsWith('_${widget.userId}');
        return ListTile(
          leading: Text('${p.pickNumber + 1}', style: const TextStyle(color: PodiumColors.muted)),
          title: Text(p.playerName, style: TextStyle(color: mine ? PodiumColors.gold : PodiumColors.chalk)),
          subtitle: Text(
            '${teams[p.teamId]?.teamName ?? 'Team'} · Round ${p.round} · ${p.position} · ${p.sport}${p.auto ? ' · auto' : ''}',
            style: const TextStyle(color: PodiumColors.muted),
          ),
        );
      },
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
        final isCommissioner = league.isCommissioner(widget.userId);
        return StreamBuilder<Draft?>(
          stream: _draft,
          builder: (context, draftSnap) {
            final draft = draftSnap.data;
            return StreamBuilder<List<Team>>(
              stream: _teams,
              builder: (context, teamSnap) {
                final teams = {for (final t in teamSnap.data ?? const <Team>[]) t.id: t};
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Draft'),
                    actions: [
                      if (draft != null)
                        TextButton(
                          onPressed: () => setState(() => _showBoard = !_showBoard),
                          child: Text(_showBoard ? 'Players' : 'Draft board'),
                        ),
                    ],
                  ),
                  body: draft == null
                      ? _notStarted(league, isCommissioner, teams.length)
                      : StreamBuilder<List<ScoringPeriod>>(
                          stream: _periods,
                          builder: (context, periodSnap) {
                            if (periodSnap.hasData) _ensureRankings(league, periodSnap.data!);
                            return StreamBuilder<Set<String>>(
                              stream: _taken,
                              builder: (context, takenSnap) {
                                return StreamBuilder<List<PlayerWeek>>(
                                  stream: _rankings,
                                  builder: (context, rankSnap) {
                                    final taken = takenSnap.data ?? const <String>{};
                                    final available = (rankSnap.data ?? const <PlayerWeek>[])
                                        .where((p) => league.sports.contains(p.sport) && !taken.contains(p.playerId))
                                        .toList();
                                    if (rankSnap.hasData && takenSnap.hasData) {
                                      _maybeRunBot(league, draft, teams, available);
                                    }
                                    final week = int.tryParse(_rankingPeriodId?.split('_w').last ?? '') ?? 1;
                                    return Column(
                                      children: [
                                        if (draft.isLive) _clock(league, draft, teams),
                                        if (draft.isComplete)
                                          const Padding(
                                            padding: EdgeInsets.all(16),
                                            child: Text(
                                              'The draft is complete. Rosters are set, and the commissioner can start the season from Matchups.',
                                              style: TextStyle(color: PodiumColors.gold),
                                            ),
                                          ),
                                        if (draft.isLive && isCommissioner)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: OutlinedButton.icon(
                                              icon: const Icon(Icons.bolt),
                                              label: Text('Auto-pick for ${teams[draft.currentTeamId]?.teamName ?? 'this team'}'),
                                              onPressed: _busy || available.isEmpty
                                                  ? null
                                                  : () => _pick(league, available.first, auto: true),
                                            ),
                                          ),
                                        if (_busy) const LinearProgressIndicator(),
                                        Expanded(
                                          child: _showBoard || draft.isComplete
                                              ? StreamBuilder<List<DraftPick>>(
                                                  stream: _picks,
                                                  builder: (context, pickSnap) =>
                                                      _board(pickSnap.data ?? const <DraftPick>[], teams),
                                                )
                                              : _players(league, draft, available, week),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _notStarted(League league, bool isCommissioner, int teamCount) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.format_list_numbered, size: 48, color: PodiumColors.gold),
        const SizedBox(height: 12),
        Text(
          'Snake draft · ${league.rosterSize} rounds · $teamCount teams',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'The order is random. It reverses every round (1 to N, then N to 1). Only the team on the clock can pick.',
          textAlign: TextAlign.center,
          style: TextStyle(color: PodiumColors.muted),
        ),
        const SizedBox(height: 24),
        if (isCommissioner)
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: Text(league.memberIds.length < league.maxTeams
                ? 'Start draft (${league.memberIds.length}/${league.maxTeams} teams joined)'
                : 'Start draft'),
            onPressed: _busy ? null : () => _run(() => _service.startDraft(league)),
          )
        else
          const Text(
            'Waiting for the commissioner to start the draft.',
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}
