import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/league.dart';
import '../../models/team.dart';
import '../../models/wager.dart';
import '../../services/auth_service.dart';
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
import '../mock_draft_screen.dart';
import '../profile/profile_screen.dart';
import '../reports/report_user_screen.dart';
import '../scores/scores_screen.dart';
import '../team/team_screen.dart';
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
                  const SizedBox(height: 14),
                  _quickActions(context, league),
                  const SizedBox(height: 14),
                  _RankCard(
                    key: ValueKey('rank_${league.id}'),
                    league: league,
                    userId: user.uid,
                    onTap: () => onGoTo(ShellTab.leaders),
                  ),
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

/// Four shortcuts into the league: team, chat, live scores, and everything else.
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
        item(Icons.groups_2_outlined, 'My team', () => open(TeamScreen(
              league: league,
              teamId: Team.idFor(league.id, user.uid),
              viewerId: user.uid,
            ))),
        const SizedBox(width: 8),
        item(Icons.forum_outlined, 'Chat', () => open(LeagueChatScreen(league: league, user: user))),
        const SizedBox(width: 8),
        item(Icons.sports_football_outlined, 'Scores', () => open(const ScoresScreen())),
        const SizedBox(width: 8),
        item(Icons.apps_rounded, 'More', () => open(LeagueHomeScreen(leagueId: league.id, user: user))),
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
