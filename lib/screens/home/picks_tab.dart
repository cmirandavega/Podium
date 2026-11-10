import 'package:flutter/material.dart';

import '../../models/app_user.dart';
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
import 'shell_widgets.dart';

/// Picks: the PrizePicks-style board for Use Case 13 (prediction wagers).
/// Pick a side on this week's games, set a stake, and post them all from the
/// slip. Other members take the other side; the winner collects both stakes.
class PicksTab extends StatefulWidget {
  const PicksTab({
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
  State<PicksTab> createState() => _PicksTabState();
}

class _PicksTabState extends State<PicksTab> {
  final _service = WagerService();
  late final Stream<List<LeagueMember>> _members = LeagueService().watchMembers(widget.league.id);
  late final Stream<List<Matchup>> _games = MatchupService().watchMatchups(widget.league.id);
  late final Stream<List<Team>> _teams = TeamService().watchTeamsInLeague(widget.league.id);
  late final Stream<List<Wager>> _wagers = _service.watchLeagueWagers(widget.league.id);

  /// matchupId -> picked teamId.
  final Map<String, String> _picks = {};
  int _stake = 50;
  bool _busy = false;

  String get _uid => widget.user.uid;

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _toggle(String gameId, String teamId) {
    setState(() {
      if (_picks[gameId] == teamId) {
        _picks.remove(gameId);
      } else {
        _picks[gameId] = teamId;
      }
    });
  }

  Future<void> _post(LeagueMember me, Map<String, Matchup> games) async {
    final total = _stake * _picks.length;
    if (total > me.coins) {
      _toast('That slip costs ${formatCount(total)} coins. You have ${formatCount(me.coins)}.');
      return;
    }
    setState(() => _busy = true);
    var posted = 0;
    try {
      for (final entry in Map<String, String>.of(_picks).entries) {
        final game = games[entry.key];
        if (game == null) continue;
        // Each pick is its own offer; the service re-checks the balance.
        await _service.create(
          league: widget.league,
          me: me,
          matchup: game,
          pickTeamId: entry.value,
          amount: _stake,
        );
        posted++;
        _picks.remove(entry.key);
      }
      _toast(posted == 1
          ? 'Pick posted. It goes live when someone takes the other side.'
          : '$posted picks posted. They go live when someone takes the other side.');
    } catch (error) {
      _toast(posted > 0 ? 'Posted $posted, then: $error' : '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _take(LeagueMember me, Wager w, Matchup game) async {
    setState(() => _busy = true);
    try {
      await _service.accept(league: widget.league, me: me, wager: w, matchup: game);
      _toast('Wager matched. Good luck!');
    } catch (error) {
      _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(Wager w) async {
    setState(() => _busy = true);
    try {
      await _service.cancel(league: widget.league, wager: w);
      _toast('Wager withdrawn.');
    } catch (error) {
      _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final league = widget.league;
    return StreamBuilder<List<LeagueMember>>(
      stream: _members,
      builder: (context, memberSnap) {
        LeagueMember? me;
        for (final m in memberSnap.data ?? const <LeagueMember>[]) {
          if (m.userId == _uid) me = m;
        }
        return StreamBuilder<List<Team>>(
          stream: _teams,
          builder: (context, teamSnap) {
            final teams = {for (final t in teamSnap.data ?? const <Team>[]) t.id: t};
            return StreamBuilder<List<Matchup>>(
              stream: _games,
              builder: (context, gameSnap) {
                final gameList = gameSnap.data ?? const <Matchup>[];
                final games = {for (final g in gameList) g.id: g};
                final open = gameList
                    .where((g) => g.week == league.currentWeek && !g.isFinal && !g.isBye)
                    .toList();
                return StreamBuilder<List<Wager>>(
                  stream: _wagers,
                  builder: (context, wagerSnap) {
                    final wagers = wagerSnap.data ?? const <Wager>[];
                    final offers = wagers.where((w) => w.isOpen && w.creatorId != _uid).toList();
                    final mine = wagers.where((w) => w.involves(_uid)).toList();
                    final member = me;

                    return DefaultTabController(
                      length: 3,
                      child: SafeArea(
                        bottom: false,
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                ShellHeader(
                                  title: 'Picks',
                                  below: LeagueSwitcher(
                                    leagues: widget.leagues,
                                    active: league,
                                    onSelect: widget.onSelectLeague,
                                  ),
                                  trailing: [CoinBadge(coins: member?.coins)],
                                ),
                                TabBar(
                                  tabs: [
                                    const Tab(text: 'This week'),
                                    Tab(text: offers.isEmpty ? 'Offers' : 'Offers (${offers.length})'),
                                    const Tab(text: 'My wagers'),
                                  ],
                                ),
                                Expanded(
                                  child: TabBarView(
                                    children: [
                                      _board(open, teams, games),
                                      _offers(member, offers, teams, games),
                                      _history(mine, teams, games),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_picks.isNotEmpty && member != null)
                              Positioned(
                                left: 14,
                                right: 14,
                                bottom: 12,
                                child: _slip(member, games),
                              ),
                          ],
                        ),
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

  /// Why the board is closed, or null when picks are open.
  String? get _closedReason {
    final league = widget.league;
    if (league.phase != 'regular' && league.phase != 'playoffs') {
      return 'Picks open once the commissioner starts the season.';
    }
    if (league.lineupLocked) return 'Picks are closed while lineups are locked.';
    return null;
  }

  Widget _board(List<Matchup> open, Map<String, Team> teams, Map<String, Matchup> games) {
    final closed = _closedReason;
    final myTeamId = Team.idFor(widget.league.id, _uid);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 14, 16, _picks.isEmpty ? 24 : 120),
      children: [
        if (closed != null) ...[
          PodiumCard(
            radius: PodiumRadii.tile,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                if (widget.league.lineupLocked) const StatusPill.live() else const StatusPill(label: 'CLOSED'),
                const SizedBox(width: 12),
                Expanded(child: Text(closed, style: const TextStyle(fontSize: 13, color: PodiumColors.silver))),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (open.isEmpty && closed == null)
          const EmptyCard(
            icon: Icons.sports_score_outlined,
            title: 'No games left this week',
            message: 'New games show up when the next week starts.',
          ),
        for (final g in open)
          _GameCard(
            game: g,
            teams: teams,
            myTeamId: myTeamId,
            picked: _picks[g.id],
            enabled: closed == null && !_busy,
            onPick: (teamId) => _toggle(g.id, teamId),
          ),
        if (open.isNotEmpty && closed == null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Each pick is posted as an offer. When another member takes the other side, '
              'the winner collects both stakes. Podium coins have no cash value.',
              textAlign: TextAlign.center,
              style: PodiumText.caption,
            ),
          ),
      ],
    );
  }

  Widget _slip(LeagueMember me, Map<String, Matchup> games) {
    final n = _picks.length;
    final total = _stake * n;
    final short = total > me.coins;
    return Material(
      color: PodiumColors.gold,
      elevation: 8,
      shadowColor: Colors.black54,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n == 1 ? '1 pick' : '$n picks',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: PodiumColors.navy),
                  ),
                  Text(
                    short
                        ? 'Needs ${formatCount(total)} coins'
                        : 'Win ${formatCount(_stake * 2)} each if matched',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: short ? const Color(0xFF8A1F1F) : PodiumColors.navy,
                    ),
                  ),
                ],
              ),
            ),
            _StakeStepper(
              stake: _stake,
              onChanged: _busy ? null : (v) => setState(() => _stake = v),
              max: me.coins,
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: PodiumColors.navy,
                foregroundColor: PodiumColors.chalk,
                minimumSize: const Size(72, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: _busy || short ? null : () => _post(me, games),
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _offers(LeagueMember? me, List<Wager> offers, Map<String, Team> teams, Map<String, Matchup> games) {
    if (offers.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          EmptyCard(
            icon: Icons.toll_outlined,
            title: 'No open offers',
            message: 'When a member posts a pick, you can take the other side here.',
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        for (final w in offers)
          _OfferCard(
            wager: w,
            teams: teams,
            game: games[w.matchupId],
            enabled: !_busy && me != null && _closedReason == null,
            onTake: () {
              final game = games[w.matchupId];
              if (me != null && game != null) _take(me, w, game);
            },
          ),
      ],
    );
  }

  Widget _history(List<Wager> mine, Map<String, Team> teams, Map<String, Matchup> games) {
    if (mine.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          EmptyCard(
            icon: Icons.receipt_long_outlined,
            title: 'No wagers yet',
            message: 'Your posted and matched picks show up here.',
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        for (final w in mine)
          _HistoryRow(
            wager: w,
            userId: _uid,
            teams: teams,
            games: games,
            onWithdraw: w.isOpen && w.creatorId == _uid && !_busy ? () => _cancel(w) : null,
          ),
      ],
    );
  }
}

/// One game on the board: two sides, tap one to pick it.
class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.game,
    required this.teams,
    required this.myTeamId,
    required this.picked,
    required this.enabled,
    required this.onPick,
  });

  final Matchup game;
  final Map<String, Team> teams;
  final String myTeamId;
  final String? picked;
  final bool enabled;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final home = teams[game.homeTeamId];
    final away = teams[game.awayTeamId];
    final mine = game.involves(myTeamId);
    return PodiumCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      borderColor: picked != null ? PodiumColors.gold : PodiumColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                game.isPlayoff ? 'PLAYOFFS · WEEK ${game.week}' : 'WEEK ${game.week}',
                style: PodiumText.overline.copyWith(fontSize: 11),
              ),
              const Spacer(),
              if (mine)
                const Text('Your game', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PodiumColors.gold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _TeamSide(team: home, isMe: game.homeTeamId == myTeamId)),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text('VS', style: PodiumText.score(size: 14, color: PodiumColors.muted, weight: FontWeight.w600)),
              ),
              Expanded(child: _TeamSide(team: away, isMe: game.awayTeamId == myTeamId)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PickButton(
                  label: home?.teamName ?? 'Home',
                  selected: picked == game.homeTeamId,
                  onTap: enabled ? () => onPick(game.homeTeamId) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PickButton(
                  label: away?.teamName ?? 'Away',
                  selected: picked == game.awayTeamId,
                  onTap: enabled && game.awayTeamId != null ? () => onPick(game.awayTeamId!) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamSide extends StatelessWidget {
  const _TeamSide({required this.team, required this.isMe});

  final Team? team;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final name = team?.teamName ?? 'Team';
    return Column(
      children: [
        InitialsAvatar(
          name: name,
          size: 52,
          ring: isMe ? PodiumColors.gold : PodiumColors.line,
          ringWidth: 2,
        ),
        const SizedBox(height: 6),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        Text(
          isMe ? 'You · ${team?.record ?? '0-0'}' : (team?.record ?? '0-0'),
          style: PodiumText.caption,
        ),
      ],
    );
  }
}

/// The More/Less-style pick button: gold when picked.
class _PickButton extends StatelessWidget {
  const _PickButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? PodiumColors.gold : PodiumColors.navy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? PodiumColors.gold : PodiumColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? Icons.check_rounded : Icons.add_rounded,
                    size: 16,
                    color: selected ? PodiumColors.navy : PodiumColors.muted,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? PodiumColors.navy
                            : (onTap == null ? PodiumColors.muted : PodiumColors.chalk),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// − 50 + stake control on the slip.
class _StakeStepper extends StatelessWidget {
  const _StakeStepper({required this.stake, required this.onChanged, required this.max});

  final int stake;
  final ValueChanged<int>? onChanged;
  final int max;

  static const _step = 10;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    Widget btn(IconData icon, String label, int? next) => SizedBox(
          width: 36,
          height: 44,
          child: IconButton(
            tooltip: label,
            padding: EdgeInsets.zero,
            icon: Icon(icon, size: 18, color: PodiumColors.navy),
            onPressed: change == null || next == null ? null : () => change(next),
          ),
        );
    final lower = stake - _step >= Wager.minAmount ? stake - _step : null;
    final higher = stake + _step <= (max < Wager.minAmount ? Wager.minAmount : max) ? stake + _step : null;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x2914213D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.remove_rounded, 'Lower stake', lower),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatCount(stake), style: PodiumText.score(size: 20, color: PodiumColors.navy)),
              const Text('each', style: TextStyle(fontSize: 10, color: PodiumColors.navy)),
            ],
          ),
          btn(Icons.add_rounded, 'Raise stake', higher),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.wager,
    required this.teams,
    required this.game,
    required this.enabled,
    required this.onTake,
  });

  final Wager wager;
  final Map<String, Team> teams;
  final Matchup? game;
  final bool enabled;
  final VoidCallback onTake;

  @override
  Widget build(BuildContext context) {
    final w = wager;
    final g = game;
    final pick = teams[w.pickTeamId]?.teamName ?? 'Team';
    final otherId = g == null ? null : (g.homeTeamId == w.pickTeamId ? g.awayTeamId : g.homeTeamId);
    final other = teams[otherId]?.teamName ?? 'the other team';
    return PodiumCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InitialsAvatar(name: w.creatorName, size: 34),
              const SizedBox(width: 10),
              Expanded(child: Text('@${w.creatorName}', style: const TextStyle(fontWeight: FontWeight.w600))),
              StatusPill(label: 'WEEK ${w.week}'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Side(label: 'THEY TAKE', team: pick, color: PodiumColors.silver)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('VS', style: PodiumText.score(size: 14, color: PodiumColors.muted, weight: FontWeight.w600)),
              ),
              Expanded(child: _Side(label: 'YOU TAKE', team: other, color: PodiumColors.gold, end: true)),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: enabled && g != null ? onTake : null,
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
          Text('Winner collects ${formatCount(w.amount * 2)} coins.', textAlign: TextAlign.center, style: PodiumText.caption),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.label, required this.team, required this.color, this.end = false});

  final String label;
  final String team;
  final Color color;
  final bool end;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: PodiumText.overline.copyWith(fontSize: 10, color: color)),
        const SizedBox(height: 4),
        Text(
          team,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: end ? TextAlign.right : TextAlign.left,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.wager,
    required this.userId,
    required this.teams,
    required this.games,
    required this.onWithdraw,
  });

  final Wager wager;
  final String userId;
  final Map<String, Team> teams;
  final Map<String, Matchup> games;
  final VoidCallback? onWithdraw;

  String get _text {
    final w = wager;
    final mineSide = w.creatorId == userId;
    final game = games[w.matchupId];
    final otherId = game == null ? null : (game.homeTeamId == w.pickTeamId ? game.awayTeamId : game.homeTeamId);
    final myTeam = mineSide ? teams[w.pickTeamId]?.teamName : teams[otherId]?.teamName;
    final theirName = mineSide ? w.opponentName : w.creatorName;
    final pick = myTeam ?? 'your pick';
    return switch (w.status) {
      'open' => 'You took $pick · waiting for a taker',
      'matched' => 'You took $pick vs @${theirName ?? 'member'}',
      'won' => w.winnerId == userId
          ? 'Won with $pick · +${formatCount(w.amount * 2)}'
          : 'Lost with $pick vs @${theirName ?? 'member'}',
      'push' => 'Tie game · stakes returned',
      'void' => 'Nobody took it · stake returned',
      'cancelled' => 'Withdrawn',
      _ => w.status,
    };
  }

  @override
  Widget build(BuildContext context) {
    final w = wager;
    final IconData icon;
    final Color color;
    final Color tint;
    if (w.status == 'won' && w.winnerId == userId) {
      icon = Icons.emoji_events_outlined;
      color = PodiumColors.gold;
      tint = PodiumColors.goldTint;
    } else if (w.status == 'won') {
      icon = Icons.close_rounded;
      color = PodiumColors.dangerText;
      tint = PodiumColors.dangerTint;
    } else if (w.isMatched) {
      icon = Icons.bolt_rounded;
      color = PodiumColors.silver;
      tint = PodiumColors.silverTint;
    } else if (w.isOpen) {
      icon = Icons.hourglass_top_rounded;
      color = PodiumColors.silver;
      tint = PodiumColors.silverTint;
    } else {
      icon = Icons.check_rounded;
      color = PodiumColors.muted;
      tint = PodiumColors.silverTint;
    }
    return PodiumCard(
      margin: const EdgeInsets.only(bottom: 8),
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
                Text(_text, style: const TextStyle(fontSize: 13, height: 1.35)),
                const SizedBox(height: 2),
                Text('Week ${w.week}', style: PodiumText.caption),
              ],
            ),
          ),
          if (onWithdraw != null)
            TextButton(onPressed: onWithdraw, child: const Text('Withdraw'))
          else
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: Text(formatCount(w.amount), style: PodiumText.score(size: 18, color: color, weight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
