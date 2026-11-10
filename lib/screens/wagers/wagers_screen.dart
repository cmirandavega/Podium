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
import '../../widgets/podium_ui.dart';

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

  String _otherTeam(Wager w, Map<String, Team> teams, Map<String, Matchup> games) {
    final game = games[w.matchupId];
    if (game == null) return 'the other team';
    final otherId = game.homeTeamId == w.pickTeamId ? game.awayTeamId : game.homeTeamId;
    return teams[otherId]?.teamName ?? 'the other team';
  }

  Widget _offerCard(League league, LeagueMember? me, Wager w, Map<String, Team> teams, Map<String, Matchup> games) {
    final pick = teams[w.pickTeamId]?.teamName ?? 'Team';
    final other = _otherTeam(w, teams, games);
    return PodiumCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InitialsAvatar(name: w.creatorName, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text('@${w.creatorName}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              StatusPill(label: 'WEEK ${w.week}'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PickSide(label: 'THEY TAKE', team: pick, color: PodiumColors.silver),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('VS', style: PodiumText.score(size: 14, color: PodiumColors.muted, weight: FontWeight.w600)),
              ),
              Expanded(
                child: _PickSide(label: 'YOU TAKE', team: other, color: PodiumColors.gold, alignEnd: true),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _busy || me == null || games[w.matchupId] == null || league.lineupLocked
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Take it  ·  '),
                Text(formatCount(w.amount), style: PodiumText.score(size: 20, color: PodiumColors.navy)),
                const SizedBox(width: 4),
                const Text('coins'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Winner collects ${formatCount(w.amount * 2)} coins.',
            textAlign: TextAlign.center,
            style: PodiumText.caption,
          ),
        ],
      ),
    );
  }

  Widget _historyRow(League league, Wager w, Map<String, Team> teams, Map<String, Matchup> games) {
    final involved = w.involves(widget.userId);
    final IconData icon;
    final Color color;
    final Color tint;
    if (w.status == 'won' && w.winnerId == widget.userId) {
      icon = Icons.emoji_events_outlined;
      color = PodiumColors.gold;
      tint = PodiumColors.goldTint;
    } else if (w.status == 'won' && involved) {
      icon = Icons.close_rounded;
      color = PodiumColors.dangerText;
      tint = PodiumColors.dangerTint;
    } else if (w.isSettled || w.status == 'cancelled') {
      icon = Icons.check_rounded;
      color = PodiumColors.muted;
      tint = PodiumColors.silverTint;
    } else {
      icon = Icons.hourglass_top_rounded;
      color = PodiumColors.silver;
      tint = PodiumColors.silverTint;
    }
    return PodiumCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      radius: PodiumRadii.tile,
      child: Row(
        children: [
          TintedIcon(icon: icon, color: color, background: tint, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_describe(w, teams, games), style: const TextStyle(fontSize: 13, height: 1.35)),
                const SizedBox(height: 2),
                Text('Week ${w.week}', style: PodiumText.caption),
              ],
            ),
          ),
          if (w.isOpen && w.creatorId == widget.userId)
            TextButton(
              onPressed: _busy ? null : () => _run(() => _service.cancel(league: league, wager: w), 'Wager withdrawn.'),
              child: const Text('Withdraw'),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: Text(formatCount(w.amount), style: PodiumText.score(size: 18, color: color, weight: FontWeight.w600)),
            ),
        ],
      ),
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
                              PodiumCard(
                                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    const CoinIcon(size: 48),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('YOUR BALANCE', style: PodiumText.overline),
                                          const SizedBox(height: 4),
                                          Text(
                                            me == null ? '—' : formatCount(me.coins),
                                            style: PodiumText.score(size: 40, color: PodiumColors.gold),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text('Podium coins · no cash value', style: PodiumText.caption),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (league.lineupLocked)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: Row(
                                    children: [
                                      const StatusPill.live(),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Wagers are closed while lineups are locked.',
                                          style: PodiumText.caption.copyWith(color: PodiumColors.silver),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
                                child: SectionHeader('Open offers'),
                              ),
                              if (offers.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                                  child: EmptyCard(
                                    icon: Icons.toll_outlined,
                                    title: 'No open offers',
                                    message: 'Post a wager and another member can take the other side.',
                                  ),
                                ),
                              for (final w in offers) _offerCard(league, me, w, teams, games),
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                                child: SectionHeader('League wagers'),
                              ),
                              for (final w in rest) _historyRow(league, w, teams, games),
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

class _PickSide extends StatelessWidget {
  const _PickSide({required this.label, required this.team, required this.color, this.alignEnd = false});

  final String label;
  final String team;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: PodiumText.overline.copyWith(fontSize: 10, color: color)),
        const SizedBox(height: 4),
        Text(
          team,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
