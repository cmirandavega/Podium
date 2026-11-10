import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/app_user.dart';
import '../../models/league.dart';
import '../../models/matchup.dart';
import '../../models/team.dart';
import '../../services/league_service.dart';
import '../../services/matchup_service.dart';
import '../../services/team_service.dart';
import '../../services/wager_service.dart';
import '../../theme.dart';
import '../../widgets/podium_ui.dart';
import '../chat/league_chat_screen.dart';
import '../coach/coach_screen.dart';
import '../draft/draft_screen.dart';
import '../matchups/matchups_screen.dart';
import '../matchups/standings_screen.dart';
import '../matchups/weekly_analysis_screen.dart';
import '../team/league_teams_screen.dart';
import '../trades/trades_screen.dart';
import '../wagers/wagers_screen.dart';
import '../team/team_screen.dart';
import 'edit_sports_screen.dart';

/// One league's hub: settings, invite code, members, and links to each
/// league feature (team, chat, matchups, trades, AI tools).
class LeagueHomeScreen extends StatefulWidget {
  const LeagueHomeScreen({super.key, required this.leagueId, required this.user});

  final String leagueId;
  final AppUser user;

  @override
  State<LeagueHomeScreen> createState() => _LeagueHomeScreenState();
}

class _LeagueHomeScreenState extends State<LeagueHomeScreen> {
  final _leagues = LeagueService();
  late final Stream<League?> _leagueStream = _leagues.watchLeague(widget.leagueId);
  late final Stream<List<LeagueMember>> _membersStream = _leagues.watchMembers(widget.leagueId);
  // Separate subscription for the coin badge (a stream can only have one listener).
  late final Stream<List<LeagueMember>> _coinStream = _leagues.watchMembers(widget.leagueId);

  /// Links to league features. Each feature adds its entry here.
  List<_LeagueTool> _tools(League league) => [
        _LeagueTool(
          icon: Icons.format_list_numbered,
          title: 'Draft',
          color: PodiumColors.bronzeText,
          tint: PodiumColors.bronzeTint,
          subtitle: switch (league.draftStatus) {
            'not_started' => 'Commissioner starts the snake draft',
            'live' => 'Live now: join the draft room',
            _ => 'Draft board and results',
          },
          builder: (_) => DraftScreen(leagueId: league.id, userId: widget.user.uid),
        ),
        _LeagueTool(
          icon: Icons.groups_2_outlined,
          title: 'My Team',
          subtitle: 'Roster, starters, and bench',
          builder: (_) => TeamScreen(
            league: league,
            teamId: Team.idFor(league.id, widget.user.uid),
            viewerId: widget.user.uid,
            extraActions: [
              ActionChip(
                avatar: const Icon(Icons.psychology_outlined, size: 18),
                label: const Text('Ask the AI Coach'),
                onPressed: () => _openCoach(league),
              ),
            ],
          ),
        ),
        _LeagueTool(
          icon: Icons.shield_outlined,
          title: 'Teams',
          color: PodiumColors.silver,
          tint: PodiumColors.silverTint,
          subtitle: 'See every roster in the league',
          builder: (_) => LeagueTeamsScreen(league: league, viewerId: widget.user.uid),
        ),
        _LeagueTool(
          icon: Icons.sports_score_outlined,
          title: 'Matchups',
          subtitle: league.phase == 'preseason'
              ? 'Schedule starts when the season does'
              : 'Week ${league.currentWeek} head-to-head games',
          builder: (_) => MatchupsScreen(
            leagueId: league.id,
            userId: widget.user.uid,
            // Scoring a week also settles that week's wagers in the same batch.
            matchups: MatchupService(onWeekScored: WagerService().settleInBatch),
          ),
        ),
        _LeagueTool(
          icon: Icons.format_list_numbered,
          title: 'Standings',
          color: PodiumColors.silver,
          tint: PodiumColors.silverTint,
          subtitle: 'Ranked by record, then total points',
          builder: (_) => StandingsScreen(league: league, userId: widget.user.uid),
        ),
        _LeagueTool(
          icon: Icons.insights_outlined,
          title: 'Weekly Analysis',
          color: PodiumColors.bronzeText,
          tint: PodiumColors.bronzeTint,
          subtitle: 'Your recap after each scored week',
          builder: (_) => WeeklyAnalysisScreen(
            leagueId: league.id,
            teamId: Team.idFor(league.id, widget.user.uid),
          ),
        ),
        _LeagueTool(
          icon: Icons.swap_horiz,
          title: 'Trades',
          subtitle: 'Offers, counters, and the AI Trade Analyzer',
          builder: (_) => TradesScreen(leagueId: league.id, userId: widget.user.uid),
        ),
        _LeagueTool(
          icon: Icons.toll_outlined,
          title: 'Prediction Wagers',
          subtitle: 'Bet Podium coins on matchups (no cash value)',
          builder: (_) => WagersScreen(leagueId: league.id, userId: widget.user.uid),
        ),
        _LeagueTool(
          icon: Icons.forum_outlined,
          title: 'League Chat',
          color: PodiumColors.silver,
          tint: PodiumColors.silverTint,
          subtitle: 'Talk trades and trash with your league',
          builder: (_) => LeagueChatScreen(league: league, user: widget.user),
        ),
        _LeagueTool(
          icon: Icons.psychology_outlined,
          title: 'AI Coach',
          subtitle: 'Lineup advice from your roster and stats',
          builder: (_) => CoachScreen(leagueId: league.id, userId: widget.user.uid),
        ),
      ];

  void _openCoach(League league) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CoachScreen(leagueId: league.id, userId: widget.user.uid),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<League?>(
      stream: _leagueStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Unable to load this league.')),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final league = snapshot.data!;
        final isCommissioner = league.isCommissioner(widget.user.uid);
        final tools = _tools(league);

        return Scaffold(
          appBar: AppBar(
            title: Text(league.name, overflow: TextOverflow.ellipsis),
            actions: [
              StreamBuilder<List<LeagueMember>>(
                stream: _coinStream,
                builder: (context, memberSnap) {
                  int? coins;
                  for (final m in memberSnap.data ?? const <LeagueMember>[]) {
                    if (m.userId == widget.user.uid) coins = m.coins;
                  }
                  // App bar actions stretch to the toolbar height; keep the pill compact.
                  return Center(
                    child: CoinBadge(
                      coins: coins,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => WagersScreen(leagueId: league.id, userId: widget.user.uid),
                      )),
                    ),
                  );
                },
              ),
              if (isCommissioner && league.phase == 'preseason')
                IconButton(
                  tooltip: 'Edit sports',
                  icon: const Icon(Icons.tune),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => EditSportsScreen(league: league)),
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              _LeagueHeader(league: league, isCommissioner: isCommissioner),
              if (isCommissioner && league.phase == 'preseason') _JoinRequests(league: league),
              if (league.phase == 'regular' || league.phase == 'playoffs') ...[
                const SizedBox(height: 14),
                _MyMatchupCard(
                  league: league,
                  userId: widget.user.uid,
                  onOpen: () => Navigator.of(context).push(MaterialPageRoute(builder: tools.firstWhere((t) => t.title == 'Matchups').builder)),
                ),
              ],
              const SizedBox(height: 24),
              const SectionHeader('League tools'),
              const SizedBox(height: 10),
              for (var i = 0; i < tools.length; i += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _ToolTile(tool: tools[i])),
                        const SizedBox(width: 10),
                        Expanded(
                          child: i + 1 < tools.length ? _ToolTile(tool: tools[i + 1]) : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              SectionHeader('Members (${league.memberIds.length}/${league.maxTeams})'),
              const SizedBox(height: 10),
              StreamBuilder<List<LeagueMember>>(
                stream: _membersStream,
                builder: (context, memberSnap) {
                  final members = memberSnap.data ?? const <LeagueMember>[];
                  return PodiumCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (var i = 0; i < members.length; i++) ...[
                          if (i > 0) const Divider(indent: 66),
                          _MemberRow(
                            member: members[i],
                            isCommissioner: league.isCommissioner(members[i].userId),
                            isMe: members[i].userId == widget.user.uid,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LeagueTool {
  const _LeagueTool({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
    this.color = PodiumColors.gold,
    this.tint = PodiumColors.goldTint,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;
  final Color color;
  final Color tint;
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool});

  final _LeagueTool tool;

  @override
  Widget build(BuildContext context) {
    return PodiumCard(
      radius: PodiumRadii.tile + 2,
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: tool.builder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TintedIcon(icon: tool.icon, color: tool.color, background: tool.tint, size: 38),
          const SizedBox(height: 12),
          Text(tool.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(
            tool.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, height: 1.35, color: PodiumColors.muted),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.isCommissioner, required this.isMe});

  final LeagueMember member;
  final bool isCommissioner;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          InitialsAvatar(
            name: member.username,
            ring: isCommissioner ? PodiumColors.gold : PodiumColors.line,
            ringWidth: isCommissioner ? 2 : 1.5,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '@${member.username} (you)' : '@${member.username}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  isCommissioner ? 'Commissioner' : 'Member',
                  style: TextStyle(
                    fontSize: 12,
                    color: isCommissioner ? PodiumColors.gold : PodiumColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (member.isMuted)
            const Icon(Icons.volume_off, size: 18, color: PodiumColors.muted, semanticLabel: 'Muted'),
          const SizedBox(width: 8),
          const CoinIcon(size: 18),
          const SizedBox(width: 6),
          Text(formatCount(member.coins), style: PodiumText.score(size: 17, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// This week's head-to-head for the signed-in user, scoreboard style.
class _MyMatchupCard extends StatefulWidget {
  const _MyMatchupCard({required this.league, required this.userId, required this.onOpen});

  final League league;
  final String userId;
  final VoidCallback onOpen;

  @override
  State<_MyMatchupCard> createState() => _MyMatchupCardState();
}

class _MyMatchupCardState extends State<_MyMatchupCard> {
  late final Stream<List<Team>> _teams = TeamService().watchTeamsInLeague(widget.league.id);
  late final Stream<List<Matchup>> _games = MatchupService().watchMatchups(widget.league.id);

  @override
  Widget build(BuildContext context) {
    final league = widget.league;
    final onOpen = widget.onOpen;
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
            if (game == null) return const SizedBox.shrink();

            final me = teams[myTeamId];
            final oppId = game.homeTeamId == myTeamId ? game.awayTeamId : game.homeTeamId;
            final opp = oppId == null ? null : teams[oppId];
            final myScore = game.homeTeamId == myTeamId ? game.homeScore : game.awayScore;
            final oppScore = game.homeTeamId == myTeamId ? game.awayScore : game.homeScore;
            final total = myScore + oppScore;

            final Widget pill;
            if (game.isFinal) {
              pill = game.winnerTeamId == myTeamId
                  ? const StatusPill.gold('WIN')
                  : StatusPill(label: game.winnerTeamId == null ? 'FINAL' : 'LOSS');
            } else if (league.lineupLocked) {
              pill = const StatusPill.live();
            } else {
              pill = const StatusPill(label: 'UPCOMING');
            }

            return PodiumCard(
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      pill,
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          game.isPlayoff ? 'Playoffs · Week ${league.currentWeek}' : 'Week ${league.currentWeek} matchup',
                          style: const TextStyle(fontSize: 13, color: PodiumColors.muted, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: PodiumColors.muted),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (game.isBye)
                    Text(
                      'Bye week. ${me?.teamName ?? 'Your team'} sits this one out.',
                      style: const TextStyle(color: PodiumColors.silver),
                    )
                  else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _Side(
                            name: me?.teamName ?? 'Your team',
                            detail: 'You · ${me?.record ?? '0-0'}',
                            score: game.isFinal ? formatPoints(myScore) : (me?.record ?? '0-0'),
                            scoreColor: PodiumColors.gold,
                            alignEnd: false,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Text('VS', style: PodiumText.score(size: 15, color: PodiumColors.muted, weight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: _Side(
                            name: opp?.teamName ?? 'Opponent',
                            detail: opp?.record ?? '0-0',
                            score: game.isFinal ? formatPoints(oppScore) : (opp?.record ?? '0-0'),
                            scoreColor: PodiumColors.chalk,
                            alignEnd: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (game.isFinal && total > 0) ...[
                      SplitBar(leftShare: myScore / total),
                      const SizedBox(height: 8),
                      Text(
                        'Share of points scored',
                        style: PodiumText.caption,
                      ),
                    ] else
                      Text(
                        league.lineupLocked
                            ? 'Lineups locked. Scores post when the commissioner scores the week.'
                            : 'Set your starters before the commissioner locks lineups.',
                        style: PodiumText.caption,
                      ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.name,
    required this.detail,
    required this.score,
    required this.scoreColor,
    required this.alignEnd,
  });

  final String name;
  final String detail;
  final String score;
  final Color scoreColor;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = alignEnd ? TextAlign.right : TextAlign.left;
    return Column(
      crossAxisAlignment: align,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(score, style: PodiumText.score(size: 44, color: scoreColor)),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Text(detail, textAlign: textAlign, style: PodiumText.caption),
      ],
    );
  }
}

class _LeagueHeader extends StatelessWidget {
  const _LeagueHeader({required this.league, required this.isCommissioner});

  final League league;
  final bool isCommissioner;

  String get _phaseLabel => switch (league.phase) {
        'regular' => 'Week ${league.currentWeek} of ${league.regularSeasonWeeks}',
        'playoffs' => 'Playoffs',
        'complete' => 'Season complete',
        _ => 'Preseason: draft your roster',
      };

  @override
  Widget build(BuildContext context) {
    return PodiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_phaseLabel.toUpperCase(), style: PodiumText.overline.copyWith(color: PodiumColors.gold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Tag(league.formatLabel),
              for (final s in league.sports) _Tag(s),
              _Tag('${league.season} season'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${league.rosterSize}-player rosters, ${league.starterCount} starters, '
            '${league.regularSeasonWeeks}-week regular season'
            '${league.playoffTeams > 0 ? ', ${league.playoffTeams}-team playoffs' : ''}',
            style: const TextStyle(fontSize: 13, color: PodiumColors.muted),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            decoration: BoxDecoration(
              color: PodiumColors.navy,
              borderRadius: BorderRadius.circular(PodiumRadii.control),
              border: Border.all(color: PodiumColors.line),
            ),
            child: Row(
              children: [
                const Text('Invite code', style: TextStyle(fontSize: 13, color: PodiumColors.muted)),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectableText(
                    league.inviteCode,
                    style: PodiumText.score(size: 22, weight: FontWeight.w700).copyWith(letterSpacing: 3),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy invite code',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: league.inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code copied.')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: PodiumColors.navy,
        borderRadius: BorderRadius.circular(PodiumRadii.pill),
        border: Border.all(color: PodiumColors.line),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PodiumColors.silver),
      ),
    );
  }
}

/// Commissioner's list of pending join requests, with approve and decline.
class _JoinRequests extends StatefulWidget {
  const _JoinRequests({required this.league});

  final League league;

  @override
  State<_JoinRequests> createState() => _JoinRequestsState();
}

class _JoinRequestsState extends State<_JoinRequests> {
  final _leagues = LeagueService();
  late final Stream<List<JoinRequest>> _requests = _leagues.watchJoinRequests(widget.league.id);
  final Set<String> _busy = {};

  Future<void> _handle(JoinRequest request, bool approve) async {
    setState(() => _busy.add(request.userId));
    try {
      if (approve) {
        await _leagues.approveRequest(league: widget.league, request: request);
      } else {
        await _leagues.declineRequest(league: widget.league, request: request);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(request.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JoinRequest>>(
      stream: _requests,
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const <JoinRequest>[];
        if (requests.isEmpty) return const SizedBox.shrink();
        return PodiumCard(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(14),
          borderColor: PodiumColors.gold,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Join requests (${requests.length})',
                style: const TextStyle(color: PodiumColors.gold, fontWeight: FontWeight.w700),
              ),
              for (final r in requests)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('@${r.username}'),
                  subtitle: Text('Team: ${r.teamName}', style: const TextStyle(color: PodiumColors.muted)),
                  trailing: _busy.contains(r.userId)
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Decline',
                              icon: const Icon(Icons.close, color: PodiumColors.danger),
                              onPressed: () => _handle(r, false),
                            ),
                            IconButton(
                              tooltip: 'Approve',
                              icon: const Icon(Icons.check, color: PodiumColors.gold),
                              onPressed: widget.league.isFull ? null : () => _handle(r, true),
                            ),
                          ],
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}
