import 'package:flutter/material.dart';

import '../../models/league.dart';
import '../../models/matchup.dart';
import '../../models/team.dart';
import '../../models/wager.dart';
import '../../services/league_service.dart';
import '../../services/matchup_service.dart';
import '../../services/team_service.dart';
import '../../services/wager_service.dart';
import '../../theme.dart';

/// Use Case 13: wager Podium currency against league members on this
/// week's matchup winners.
class WagersScreen extends StatefulWidget {
  const WagersScreen({super.key, required this.leagueId, required this.userId});

  final String leagueId;
  final String userId;

  @override
  State<WagersScreen> createState() => _WagersScreenState();
}

class _WagersScreenState extends State<WagersScreen> {
  final _service = WagerService();
  late final Stream<League?> _league = LeagueService().watchLeague(widget.leagueId);
  late final Stream<List<LeagueMember>> _members = LeagueService().watchMembers(widget.leagueId);
  late final Stream<List<Matchup>> _games = MatchupService().watchMatchups(widget.leagueId);
  late final Stream<List<Team>> _teams = TeamService().watchTeamsInLeague(widget.leagueId);
  late final Stream<List<Wager>> _wagers = _service.watchLeagueWagers(widget.leagueId);
  bool _busy = false;

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      _toast(done);
    } catch (error) {
      _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _newWager(League league, LeagueMember me, List<Matchup> games, Map<String, Team> teams) async {
    final open = games.where((g) => g.week == league.currentWeek && !g.isFinal && !g.isBye).toList();
    if (open.isEmpty) {
      _toast('No games to wager on this week.');
      return;
    }
    // The dialog owns its text field and returns the choice once it closes.
    final choice = await showDialog<_WagerChoice>(
      context: context,
      builder: (_) => _NewWagerDialog(league: league, me: me, games: open, teams: teams),
    );
    if (choice == null) return;
    await _run(
      () => _service.create(
        league: league,
        me: me,
        matchup: choice.game,
        pickTeamId: choice.pickTeamId,
        amount: choice.amount,
      ),
      'Wager posted. It goes live when someone takes the other side.',
    );
  }

  String _describe(Wager w, Map<String, Team> teams, Map<String, Matchup> games) {
    final pick = teams[w.pickTeamId]?.teamName ?? 'Team';
    final game = games[w.matchupId];
    final other = game == null ? 'the other team' : (teams[game.homeTeamId == w.pickTeamId ? game.awayTeamId : game.homeTeamId]?.teamName ?? 'the other team');
    final mine = w.creatorId == widget.userId;
    final opponent = w.opponentId == widget.userId;
    return switch (w.status) {
      'open' => '@${w.creatorName} takes $pick for ${w.amount}. Take $other?',
      'matched' => '@${w.creatorName} ($pick) vs @${w.opponentName} ($other) · ${w.amount} each',
      'won' => w.winnerId == widget.userId
          ? 'You won ${w.amount * 2} coins ($pick vs $other)'
          : (mine || opponent ? 'You lost ${w.amount} coins ($pick vs $other)' : '${w.winnerId == w.creatorId ? '@${w.creatorName}' : '@${w.opponentName}'} won ${w.amount * 2} coins'),
      'push' => 'Tie game. Stakes returned.',
      'void' => 'Nobody took this wager. Stake returned.',
      'cancelled' => 'Withdrawn by @${w.creatorName}.',
      _ => w.status,
    };
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
        return StreamBuilder<List<LeagueMember>>(
          stream: _members,
          builder: (context, memberSnap) {
            final members = {for (final m in memberSnap.data ?? const <LeagueMember>[]) m.userId: m};
            final me = members[widget.userId];
            return StreamBuilder<List<Team>>(
              stream: _teams,
              builder: (context, teamSnap) {
                final teams = {for (final t in teamSnap.data ?? const <Team>[]) t.id: t};
                return StreamBuilder<List<Matchup>>(
                  stream: _games,
                  builder: (context, gameSnap) {
                    final gameList = gameSnap.data ?? const <Matchup>[];
                    final games = {for (final g in gameList) g.id: g};
                    return Scaffold(
                      appBar: AppBar(title: const Text('Prediction Wagers')),
                      floatingActionButton: me == null
                          ? null
                          : FloatingActionButton.extended(
                              icon: const Icon(Icons.add),
                              label: const Text('New wager'),
                              onPressed: _busy ? null : () => _newWager(league, me, gameList, teams),
                            ),
                      body: StreamBuilder<List<Wager>>(
                        stream: _wagers,
                        builder: (context, wagerSnap) {
                          final wagers = wagerSnap.data ?? const <Wager>[];
                          final offers = wagers.where((w) => w.isOpen && w.creatorId != widget.userId).toList();
                          final rest = wagers.where((w) => !(w.isOpen && w.creatorId != widget.userId)).toList();
                          return ListView(
                            padding: const EdgeInsets.only(bottom: 96),
                            children: [
                              Container(
                                margin: const EdgeInsets.all(16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: PodiumColors.field,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: PodiumColors.gold),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.toll_outlined, color: PodiumColors.gold, size: 32),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${me?.coins ?? '-'} Podium coins',
                                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                                        ),
                                        const Text('No cash value', style: TextStyle(color: PodiumColors.muted)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (league.lineupLocked)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('Wagers are closed while lineups are locked.',
                                      style: TextStyle(color: PodiumColors.muted)),
                                ),
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                                child: Text('Open offers', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              ),
                              if (offers.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('No open offers.', style: TextStyle(color: PodiumColors.muted)),
                                ),
                              for (final w in offers)
                                ListTile(
                                  title: Text(_describe(w, teams, games)),
                                  trailing: FilledButton(
                                    style: FilledButton.styleFrom(minimumSize: const Size(72, 36)),
                                    onPressed: _busy || me == null || games[w.matchupId] == null
                                        ? null
                                        : () => _run(
                                              () => _service.accept(
                                                league: league,
                                                me: me,
                                                wager: w,
                                                matchup: games[w.matchupId]!,
                                              ),
                                              'Wager matched. Good luck!',
                                            ),
                                    child: const Text('Take'),
                                  ),
                                ),
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
                                child: Text('League wagers', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              ),
                              for (final w in rest)
                                ListTile(
                                  leading: Icon(
                                    w.isSettled ? Icons.check_circle_outline : Icons.hourglass_top,
                                    color: w.winnerId == widget.userId ? PodiumColors.gold : PodiumColors.muted,
                                  ),
                                  title: Text(_describe(w, teams, games)),
                                  subtitle: Text('Week ${w.week}', style: const TextStyle(color: PodiumColors.muted)),
                                  trailing: w.isOpen && w.creatorId == widget.userId
                                      ? TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _run(() => _service.cancel(league: league, wager: w), 'Wager withdrawn.'),
                                          child: const Text('Withdraw'),
                                        )
                                      : null,
                                ),
                            ],
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
      },
    );
  }
}

typedef _WagerChoice = ({Matchup game, String pickTeamId, int amount});

/// The "New wager" form. As its own widget it disposes the amount field only
/// after the dialog has fully closed.
class _NewWagerDialog extends StatefulWidget {
  const _NewWagerDialog({required this.league, required this.me, required this.games, required this.teams});

  final League league;
  final LeagueMember me;
  final List<Matchup> games;
  final Map<String, Team> teams;

  @override
  State<_NewWagerDialog> createState() => _NewWagerDialogState();
}

class _NewWagerDialogState extends State<_NewWagerDialog> {
  final _amount = TextEditingController(text: '50');
  late Matchup _game = widget.games.first;
  late String _pick = _game.homeTeamId;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String _name(String? teamId) => widget.teams[teamId]?.teamName ?? 'Team';

  void _submit() {
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    final problem = WagerService.validate(
      league: widget.league,
      matchup: _game,
      amount: amount,
      balance: widget.me.coins,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.pop<_WagerChoice>(context, (game: _game, pickTeamId: _pick, amount: amount));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Wager on week ${widget.league.currentWeek}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _game.id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Game'),
              items: [
                for (final g in widget.games)
                  DropdownMenuItem(
                    value: g.id,
                    child: Text('${_name(g.homeTeamId)} vs ${_name(g.awayTeamId)}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() {
                _game = widget.games.firstWhere((g) => g.id == v);
                _pick = _game.homeTeamId;
              }),
            ),
            const SizedBox(height: 12),
            const Text('Your pick to win'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final id in [_game.homeTeamId, _game.awayTeamId!])
                  ChoiceChip(
                    label: Text(_name(id)),
                    selected: _pick == id,
                    onSelected: (_) => setState(() => _pick = id),
                  ),
              ],
            ),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Coins (you have ${widget.me.coins})', errorText: _error),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 8),
            const Text(
              'Another member takes the other side for the same amount. The winner collects both stakes. '
              'Podium currency has no cash value and can\'t be bought or withdrawn.',
              style: TextStyle(color: PodiumColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: const Text('Place wager')),
      ],
    );
  }
}
