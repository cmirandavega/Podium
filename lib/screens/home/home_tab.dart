import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/league.dart';
import '../../models/matchup.dart';
import '../../models/team.dart';
import '../../models/wager.dart';
import '../../services/auth_service.dart';
import '../../services/matchup_service.dart';
import '../../services/season_engine.dart';
import '../../services/team_service.dart';
import '../../services/user_service.dart';
import '../../services/wager_service.dart';
import '../../theme.dart';
import '../../widgets/matchup_hero.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/podium_ui.dart';
import '../admin/admin_screen.dart';
import '../chat/league_chat_screen.dart';
import '../leagues/create_league_screen.dart';
import '../leagues/join_league_screen.dart';
import '../leagues/league_home_screen.dart';
import '../leagues/my_leagues_section.dart';
import '../matchups/matchups_screen.dart';
import '../mock_draft_screen.dart';
import '../profile/profile_screen.dart';
import '../reports/report_user_screen.dart';
import '../scores/scores_screen.dart';
import '../trades/trades_screen.dart';
import 'shell_widgets.dart';

/// Tab indexes in the bottom bar, so tabs can send the user to each other.
class ShellTab {
  static const home = 0;
  static const picks = 1;
  static const matchup = 2;
  static const leaders = 3;
  static const coach = 4;
}

/// Home: greeting, league switcher, this week's matchup, shortcuts, and
/// the user's standing.
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.user,
    required this.leagues,
    required this.active,
    required this.leaguesLoaded,
    required this.onSelectLeague,
    required this.onGoTo,
  });

  final AppUser user;
  final List<League> leagues;
  final League? active;
  final bool leaguesLoaded;
  final ValueChanged<String> onSelectLeague;
  final ValueChanged<int> onGoTo;

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String get _firstName {
    final name = user.nameToShow.trim();
    return name.isEmpty ? 'there' : name.split(' ').first;
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Good morning' : (now.hour < 17 ? 'Good afternoon' : 'Good evening');
    final league = active;
    final dateLine = league != null && (league.phase == 'regular' || league.phase == 'playoffs')
        ? 'Week ${league.currentWeek} · ${_weekdays[now.weekday - 1]}'
        : '${_weekdays[now.weekday - 1]} · ${_months[now.month - 1]} ${now.day}';

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _TopBar(user: user, league: league, onGoTo: onGoTo),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateLine.toUpperCase(), style: PodiumText.overline),
                const SizedBox(height: 4),
                Text(
                  '$greeting, $_firstName',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!leaguesLoaded)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (league == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _quickActions(context, null),
                  const SizedBox(height: 24),
                  MyLeaguesSection(user: user),
                ],
              ),
            )
          else ...[
            _LeaguePills(
              leagues: leagues,
              activeId: league.id,
              onSelect: onSelectLeague,
              onAdd: () => _addLeague(context),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (league.phase == 'regular' || league.phase == 'playoffs')
                    MatchupHeroCard(
                      key: ValueKey('hero_${league.id}'),
                      league: league,
                      userId: user.uid,
                      onOpen: () => onGoTo(ShellTab.matchup),
                    )
                  else
                    _PhaseCard(league: league, onOpen: () => _push(context, LeagueHomeScreen(leagueId: league.id, user: user))),
                  if (league.isCommissioner(user.uid) && league.phase != 'complete') ...[
                    const SizedBox(height: 14),
                    _CommissionerCard(
                      key: ValueKey('commish_${league.id}'),
                      league: league,
                      onOpenSchedule: () => _openSchedule(context, league),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _quickActions(context, league),
                  const SizedBox(height: 14),
                  _RankCard(
                    key: ValueKey('rank_${league.id}'),
                    league: league,
                    userId: user.uid,
                    onTap: () => onGoTo(ShellTab.leaders),
                  ),
                  if (league.phase == 'regular' || league.phase == 'playoffs') ...[
                    const SizedBox(height: 22),
                    _WeekGames(
                      key: ValueKey('games_${league.id}'),
                      league: league,
                      userId: user.uid,
                      onOpenSchedule: () => _openSchedule(context, league),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SectionHeader(
                    'League',
                    actionLabel: 'All tools',
                    onAction: () => _push(context, LeagueHomeScreen(leagueId: league.id, user: user)),
                  ),
                  const SizedBox(height: 8),
                  _LeagueShortcuts(league: league, user: user),
                  const SizedBox(height: 22),
                  _OpenOffers(
                    key: ValueKey('offers_${league.id}'),
                    league: league,
                    userId: user.uid,
                    onSeeAll: () => onGoTo(ShellTab.picks),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The full schedule with the commissioner panel. Scoring a week there
  /// also settles its wagers, same as the league hub.
  void _openSchedule(BuildContext context, League league) => _push(
        context,
        MatchupsScreen(
          leagueId: league.id,
          userId: user.uid,
          matchups: MatchupService(onWeekScored: WagerService().settleInBatch),
        ),
      );

  Widget _quickActions(BuildContext context, League? league) {
    return Row(
      children: [
        Expanded(
          child: league == null
              ? QuickActionTile(
                  icon: Icons.sports_football_outlined,
                  label: 'Live scores',
                  caption: 'Every sport',
                  onTap: () => _push(context, const ScoresScreen()),
                )
              : QuickActionTile(
                  icon: Icons.track_changes_rounded,
                  label: 'Make picks',
                  caption: 'Wager coins',
                  onTap: () => onGoTo(ShellTab.picks),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: league == null
              ? QuickActionTile(
                  icon: Icons.emoji_events_outlined,
                  label: 'Leaderboard',
                  caption: 'Top teams',
                  color: PodiumColors.silver,
                  tint: PodiumColors.silverTint,
                  onTap: () => onGoTo(ShellTab.leaders),
                )
              : QuickActionTile(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Trade AI',
                  caption: 'Grade a deal',
                  color: PodiumColors.silver,
                  tint: PodiumColors.silverTint,
                  onTap: () => _push(context, TradesScreen(leagueId: league.id, userId: user.uid)),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: QuickActionTile(
            icon: Icons.grid_view_rounded,
            label: 'Mock draft',
            caption: 'Practice',
            color: PodiumColors.bronzeText,
            tint: PodiumColors.bronzeTint,
            onTap: () => _push(context, const MockDraftScreen()),
          ),
        ),
      ],
    );
  }

  void _addLeague(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Add a league', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Create a league'),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _push(context, CreateLeagueScreen(user: user));
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Join with an invite code'),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _push(context, JoinLeagueScreen(user: user));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wordmark, coin balance, notifications, and the account menu.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.user, required this.league, required this.onGoTo});

  final AppUser user;
  final League? league;
  final ValueChanged<int> onGoTo;

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final l = league;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
      child: Row(
        children: [
          const PodiumWordmark(size: 22),
          const Spacer(),
          if (l != null)
            LeagueCoins(
              key: ValueKey('coins_${l.id}'),
              leagueId: l.id,
              userId: user.uid,
              onTap: () => onGoTo(ShellTab.picks),
            ),
          NotificationBell(uid: user.uid),
          PopupMenuButton<String>(
            tooltip: 'Account',
            icon: InitialsAvatar(
              name: user.nameToShow,
              size: 34,
              ring: PodiumColors.gold,
              foreground: PodiumColors.chalk,
            ),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  _push(context, ProfileScreen(user: user));
                case 'scores':
                  _push(context, const ScoresScreen());
                case 'admin':
                  _push(context, AdminScreen(currentUser: user));
                case 'report':
                  _openReportPicker(context, user);
                case 'logout':
                  AuthService().signOut();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'profile',
                child: ListTile(leading: Icon(Icons.person_outline), title: Text('Profile')),
              ),
              const PopupMenuItem(
                value: 'scores',
                child: ListTile(leading: Icon(Icons.sports_football_outlined), title: Text('Live scores')),
              ),
              if (user.isAdmin)
                const PopupMenuItem(
                  value: 'admin',
                  child: ListTile(leading: Icon(Icons.admin_panel_settings_outlined), title: Text('Admin tools')),
                ),
              const PopupMenuItem(
                value: 'report',
                child: ListTile(leading: Icon(Icons.flag_outlined), title: Text('Report a user')),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(leading: Icon(Icons.logout), title: Text('Log out')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Horizontal league pills (like the mockup's sport pills) plus "add".
class _LeaguePills extends StatelessWidget {
  const _LeaguePills({required this.leagues, required this.activeId, required this.onSelect, required this.onAdd});

  final List<League> leagues;
  final String activeId;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          for (final l in leagues)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(l.name),
                selected: l.id == activeId,
                onSelected: (_) => onSelect(l.id),
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('League'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

/// Before the season (or after it): where the league stands.
class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.league, required this.onOpen});

  final League league;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final complete = league.phase == 'complete';
    return PodiumCard(
      onTap: onOpen,
      radius: 22,
      child: Row(
        children: [
          TintedIcon(icon: complete ? Icons.emoji_events : Icons.format_list_numbered, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  complete ? 'SEASON COMPLETE' : 'PRESEASON',
                  style: PodiumText.overline.copyWith(color: PodiumColors.gold),
                ),
                const SizedBox(height: 4),
                Text(
                  complete ? 'See the final standings and the champion' : 'Draft your roster and set your starters',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${league.memberIds.length}/${league.maxTeams} teams · ${league.sports.join(' · ')}',
                  style: PodiumText.caption,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: PodiumColors.muted),
        ],
      ),
    );
  }
}

/// "2nd of 10 · 1,284.6 pts" with a medal-colored rank.
class _RankCard extends StatefulWidget {
  const _RankCard({super.key, required this.league, required this.userId, required this.onTap});

  final League league;
  final String userId;
  final VoidCallback onTap;

  @override
  State<_RankCard> createState() => _RankCardState();
}

class _RankCardState extends State<_RankCard> {
  late final Stream<List<Team>> _teams = TeamService().watchTeamsInLeague(widget.league.id);

  static String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
  }

  @override
  Widget build(BuildContext context) {
    final myTeamId = Team.idFor(widget.league.id, widget.userId);
    return StreamBuilder<List<Team>>(
      stream: _teams,
      builder: (context, snap) {
        final standings = SeasonEngine.standings(snap.data ?? const <Team>[]);
        final index = standings.indexWhere((t) => t.id == myTeamId);
        if (index < 0) return const SizedBox.shrink();
        final me = standings[index];
        final rank = index + 1;
        final medal = PodiumColors.medal(rank);
        return PodiumCard(
          onTap: widget.onTap,
          radius: PodiumRadii.tile + 2,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: medal ?? PodiumColors.navy,
                  shape: BoxShape.circle,
                  border: medal == null ? Border.all(color: PodiumColors.line) : null,
                ),
                child: Text(
                  '$rank',
                  style: PodiumText.score(size: 22, color: medal == null ? PodiumColors.chalk : PodiumColors.navy),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(me.teamName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${_ordinal(rank)} of ${standings.length} · ${me.record} · ${formatPoints(me.pointsFor)} pts',
                      style: PodiumText.caption,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: PodiumColors.muted),
            ],
          ),
        );
      },
    );
  }
}

/// Three shortcuts into the league: league tools (My team), chat, and live scores.
class _LeagueShortcuts extends StatelessWidget {
  const _LeagueShortcuts({required this.league, required this.user});

  final League league;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    Widget item(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: PodiumCard(
            onTap: onTap,
            radius: PodiumRadii.tile,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Icon(icon, color: PodiumColors.silver, size: 22),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
    return Row(
      children: [
        // My team opens the league's tools (roster, draft, trades, standings, and more).
        item(Icons.groups_2_outlined, 'My team', () => open(LeagueHomeScreen(leagueId: league.id, user: user))),
        const SizedBox(width: 8),
        item(Icons.forum_outlined, 'Chat', () => open(LeagueChatScreen(league: league, user: user))),
        const SizedBox(width: 8),
        item(Icons.sports_football_outlined, 'Scores', () => open(const ScoresScreen())),
      ],
    );
  }
}

/// Open wager offers from other members (the mockup's "Trending picks").
class _OpenOffers extends StatefulWidget {
  const _OpenOffers({super.key, required this.league, required this.userId, required this.onSeeAll});

  final League league;
  final String userId;
  final VoidCallback onSeeAll;

  @override
  State<_OpenOffers> createState() => _OpenOffersState();
}

class _OpenOffersState extends State<_OpenOffers> {
  late final Stream<List<Wager>> _wagers = WagerService().watchLeagueWagers(widget.league.id);
  late final Stream<List<Team>> _teams = TeamService().watchTeamsInLeague(widget.league.id);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Team>>(
      stream: _teams,
      builder: (context, teamSnap) {
        final teams = {for (final t in teamSnap.data ?? const <Team>[]) t.id: t};
        return StreamBuilder<List<Wager>>(
          stream: _wagers,
          builder: (context, snap) {
            final offers = (snap.data ?? const <Wager>[])
                .where((w) => w.isOpen && w.creatorId != widget.userId && w.week == widget.league.currentWeek)
                .take(2)
                .toList();
            if (offers.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader('Open offers', actionLabel: 'See all', onAction: widget.onSeeAll),
                const SizedBox(height: 8),
                for (final w in offers)
                  PodiumCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    radius: PodiumRadii.tile + 2,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    onTap: widget.onSeeAll,
                    child: Row(
                      children: [
                        InitialsAvatar(name: w.creatorName, size: 42),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('@${w.creatorName}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              Text(
                                'Took ${teams[w.pickTeamId]?.teamName ?? 'a team'} · take the other side',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PodiumText.caption,
                              ),
                            ],
                          ),
                        ),
                        const CoinIcon(size: 20),
                        const SizedBox(width: 6),
                        Text(formatCount(w.amount), style: PodiumText.score(size: 24)),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// The commissioner's next step for the week, right on Home:
/// Start season -> Lock lineups -> Score week -> (next week) Lock lineups...
class _CommissionerCard extends StatefulWidget {
  const _CommissionerCard({super.key, required this.league, required this.onOpenSchedule});

  final League league;
  final VoidCallback onOpenSchedule;

  @override
  State<_CommissionerCard> createState() => _CommissionerCardState();
}

class _CommissionerCardState extends State<_CommissionerCard> {
  // Scoring a week also settles that week's wagers in the same batch.
  final _service = MatchupService(onWeekScored: WagerService().settleInBatch);
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

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final league = widget.league;
    final week = league.currentWeek;

    final String step;
    final String detail;
    final IconData icon;
    final String label;
    final Future<void> Function() onPressed;
    if (league.phase == 'preseason') {
      step = 'PRESEASON';
      detail = 'When everyone has drafted, start the season. This builds the schedule and opens week 1.';
      icon = Icons.play_arrow_rounded;
      label = 'Start season';
      onPressed = () async {
        if (!await _confirm('Start the season?', 'This builds the full schedule. Rosters stay editable until you lock week 1.', 'Start')) return;
        await _run(() => _service.startSeason(league), 'Season started. Week 1 is set.');
      };
    } else if (!league.lineupLocked) {
      step = 'WEEK $week · LINEUPS OPEN';
      detail = 'Lock lineups when week $week\'s games begin. Locking also closes wagers and turns on live scores.';
      icon = Icons.lock_outline_rounded;
      label = 'Lock lineups for week $week';
      onPressed = () => _run(() => _service.setLineupsLocked(league, true), 'Lineups locked for week $week.');
    } else {
      step = 'WEEK $week · LOCKED';
      detail = 'Once the stats are in, score the week to post results, update standings, and settle wagers.';
      icon = Icons.scoreboard_outlined;
      label = 'Score week $week';
      onPressed = () async {
        if (!await _confirm(
          'Score week $week?',
          'This finalizes every week $week game, updates standings, and pays out wagers. It can\'t be undone.',
          'Score week',
        )) {
          return;
        }
        await _run(() => _service.scoreCurrentWeek(league), 'Week $week is final.');
      };
    }

    return PodiumCard(
      borderColor: PodiumColors.gold,
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_outlined, color: PodiumColors.gold, size: 18),
              const SizedBox(width: 8),
              Text('COMMISSIONER', style: PodiumText.overline.copyWith(color: PodiumColors.gold)),
              const Spacer(),
              Flexible(
                child: Text(
                  step,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PodiumText.overline.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(detail, style: const TextStyle(fontSize: 13, color: PodiumColors.silver, height: 1.4)),
          const SizedBox(height: 14),
          FilledButton.icon(
            icon: Icon(icon),
            label: Text(label),
            onPressed: _busy ? null : onPressed,
          ),
          if (_busy) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton(onPressed: widget.onOpenSchedule, child: const Text('Schedule & all games')),
              const Spacer(),
              if (league.lineupLocked && league.phase != 'preseason')
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: PodiumColors.silver),
                  onPressed: _busy
                      ? null
                      : () => _run(() => _service.setLineupsLocked(league, false), 'Lineups unlocked.'),
                  child: const Text('Unlock'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Every game in the league this week, scoreboard rows.
class _WeekGames extends StatefulWidget {
  const _WeekGames({super.key, required this.league, required this.userId, required this.onOpenSchedule});

  final League league;
  final String userId;
  final VoidCallback onOpenSchedule;

  @override
  State<_WeekGames> createState() => _WeekGamesState();
}

class _WeekGamesState extends State<_WeekGames> {
  late final Stream<List<Matchup>> _games = MatchupService().watchMatchups(widget.league.id);
  late final Stream<List<Team>> _teams = TeamService().watchTeamsInLeague(widget.league.id);

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
          builder: (context, snap) {
            final games = (snap.data ?? const <Matchup>[]).where((g) => g.week == league.currentWeek).toList()
              // Your game first.
              ..sort((a, b) => (b.involves(myTeamId) ? 1 : 0) - (a.involves(myTeamId) ? 1 : 0));
            if (games.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  'Week ${league.currentWeek} games',
                  actionLabel: 'Schedule',
                  onAction: widget.onOpenSchedule,
                ),
                const SizedBox(height: 8),
                PodiumCard(
                  padding: EdgeInsets.zero,
                  radius: PodiumRadii.tile + 2,
                  onTap: widget.onOpenSchedule,
                  child: Column(
                    children: [
                      for (var i = 0; i < games.length; i++) ...[
                        if (i > 0) const Divider(),
                        _GameRow(game: games[i], teams: teams, myTeamId: myTeamId, locked: league.lineupLocked),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({required this.game, required this.teams, required this.myTeamId, required this.locked});

  final Matchup game;
  final Map<String, Team> teams;
  final String myTeamId;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final g = game;
    String name(String? id) => id == null ? 'Bye' : (teams[id]?.teamName ?? 'Team');
    TextStyle nameStyle(String? id) {
      final won = g.isFinal && g.winnerTeamId != null && g.winnerTeamId == id;
      final lost = g.isFinal && g.winnerTeamId != null && g.winnerTeamId != id;
      return TextStyle(
        fontSize: 13,
        fontWeight: id == myTeamId || won ? FontWeight.w700 : FontWeight.w500,
        color: id == myTeamId ? PodiumColors.gold : (lost ? PodiumColors.muted : PodiumColors.chalk),
      );
    }

    final Widget middle;
    if (g.isBye) {
      middle = const StatusPill(label: 'BYE');
    } else if (g.isFinal) {
      middle = Text(
        '${formatPoints(g.homeScore)} – ${formatPoints(g.awayScore)}',
        style: PodiumText.score(size: 18, weight: FontWeight.w600),
      );
    } else if (locked) {
      middle = const StatusPill.live();
    } else {
      middle = Text('VS', style: PodiumText.score(size: 14, color: PodiumColors.muted, weight: FontWeight.w600));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name(g.homeTeamId),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: nameStyle(g.homeTeamId),
            ),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: middle),
          Expanded(
            child: Text(
              name(g.awayTeamId),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: nameStyle(g.awayTeamId),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pick another (non-admin) user, then open the report form.
void _openReportPicker(BuildContext context, AppUser user) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Who are you reporting?')),
        body: StreamBuilder<List<AppUser>>(
          stream: UserService().watchAllUsers(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Unable to load users.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final users = snapshot.data!.where((other) => other.uid != user.uid && !other.isAdmin).toList();
            if (users.isEmpty) {
              return const Center(child: Text('No users available to report.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: users.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final other = users[index];
                return PodiumCard(
                  radius: PodiumRadii.tile,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ReportUserScreen(reportedUser: other)),
                  ),
                  child: Row(
                    children: [
                      InitialsAvatar(name: other.nameToShow),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(other.nameToShow, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('@${other.username}', style: PodiumText.caption),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: PodiumColors.muted),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
  );
}
