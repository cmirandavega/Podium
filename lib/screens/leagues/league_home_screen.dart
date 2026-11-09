import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/app_user.dart';
import '../../models/league.dart';
import '../../models/team.dart';
import '../../services/league_service.dart';
import '../../theme.dart';
import '../chat/league_chat_screen.dart';
import '../coach/coach_screen.dart';
import '../team/league_teams_screen.dart';
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

  /// Links to league features. Each feature adds its entry here.
  List<_LeagueTool> _tools(League league) => [
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
          subtitle: 'See every roster in the league',
          builder: (_) => LeagueTeamsScreen(league: league, viewerId: widget.user.uid),
        ),
        _LeagueTool(
          icon: Icons.forum_outlined,
          title: 'League Chat',
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
            title: Text(league.name),
            actions: [
              if (isCommissioner && league.phase == 'preseason')
                IconButton(
                  tooltip: 'Edit sports',
                  icon: const Icon(Icons.tune),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => EditSportsScreen(league: league)),
                  ),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _LeagueHeader(league: league, isCommissioner: isCommissioner),
              const SizedBox(height: 20),
              for (final tool in tools) ...[
                _ToolTile(tool: tool),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 14),
              Text(
                'Members (${league.memberIds.length}/${league.maxTeams})',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<LeagueMember>>(
                stream: _membersStream,
                builder: (context, memberSnap) {
                  final members = memberSnap.data ?? const <LeagueMember>[];
                  return Column(
                    children: [
                      for (final m in members)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            league.isCommissioner(m.userId)
                                ? Icons.workspace_premium_outlined
                                : Icons.person_outline,
                            color: league.isCommissioner(m.userId)
                                ? PodiumColors.gold
                                : PodiumColors.muted,
                          ),
                          title: Text('@${m.username}'),
                          subtitle: Text(
                            league.isCommissioner(m.userId) ? 'Commissioner' : 'Member',
                          ),
                          trailing: m.isMuted
                              ? const Icon(Icons.volume_off, color: PodiumColors.muted)
                              : null,
                        ),
                    ],
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool});

  final _LeagueTool tool;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PodiumColors.field,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: PodiumColors.line),
        ),
        leading: Icon(tool.icon, color: PodiumColors.gold),
        title: Text(tool.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(tool.subtitle, style: const TextStyle(color: PodiumColors.muted)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: tool.builder)),
      ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PodiumColors.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PodiumColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_phaseLabel, style: const TextStyle(color: PodiumColors.gold, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Chip(label: Text(league.formatLabel)),
              for (final s in league.sports) Chip(label: Text(s)),
              Chip(label: Text('${league.season} season')),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${league.rosterSize}-player rosters, ${league.starterCount} starters, '
            '${league.regularSeasonWeeks}-week regular season'
            '${league.playoffTeams > 0 ? ', ${league.playoffTeams}-team playoffs' : ''}',
            style: const TextStyle(color: PodiumColors.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Invite code: ', style: TextStyle(color: PodiumColors.muted)),
              SelectableText(
                league.inviteCode,
                style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2),
              ),
              IconButton(
                tooltip: 'Copy invite code',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: league.inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite code copied.')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
