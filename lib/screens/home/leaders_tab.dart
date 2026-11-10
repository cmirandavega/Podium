import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/league.dart';
import '../../models/team.dart';
import '../../services/season_engine.dart';
import '../../services/team_service.dart';
import '../../theme.dart';
import '../../widgets/podium_ui.dart';
import '../leaderboard/leaderboard_screen.dart';
import 'shell_widgets.dart';

/// Leaders: the active league's standings on the podium, or the global
/// leaderboard.
class LeadersTab extends StatefulWidget {
  const LeadersTab({
    super.key,
    required this.user,
    required this.league,
    required this.leagues,
    required this.onSelectLeague,
  });

  final AppUser user;

  /// Null when the user isn't in a league; then only Global shows.
  final League? league;
  final List<League> leagues;
  final ValueChanged<String> onSelectLeague;

  @override
  State<LeadersTab> createState() => _LeadersTabState();
}

class _LeadersTabState extends State<LeadersTab> {
  bool _global = false;

  @override
  Widget build(BuildContext context) {
    final league = widget.league;
    final showGlobal = _global || league == null;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShellHeader(
            title: 'Leaderboard',
            below: league == null
                ? null
                : LeagueSwitcher(leagues: widget.leagues, active: league, onSelect: widget.onSelectLeague),
          ),
          if (league != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: PodiumColors.field,
                  borderRadius: BorderRadius.circular(PodiumRadii.control),
                  border: Border.all(color: PodiumColors.line),
                ),
                child: Row(
                  children: [
                    _seg(league.name, !showGlobal, () => setState(() => _global = false)),
                    _seg('Global', showGlobal, () => setState(() => _global = true)),
                  ],
                ),
              ),
            ),
          Expanded(
            child: showGlobal || league == null
                ? const GlobalLeaderboardView(padding: EdgeInsets.fromLTRB(20, 16, 20, 32))
                : _LeagueStandings(
                    key: ValueKey('standings_${league.id}'),
                    league: league,
                    userId: widget.user.uid,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _seg(String label, bool on, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: on ? PodiumColors.line : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
}

class _LeagueStandings extends StatefulWidget {
  const _LeagueStandings({super.key, required this.league, required this.userId});

  final League league;
  final String userId;

  @override
  State<_LeagueStandings> createState() => _LeagueStandingsState();
}

class _LeagueStandingsState extends State<_LeagueStandings> {
  late final Stream<List<Team>> _teams = TeamService().watchTeamsInLeague(widget.league.id);

  @override
  Widget build(BuildContext context) {
    final myTeamId = Team.idFor(widget.league.id, widget.userId);
    return StreamBuilder<List<Team>>(
      stream: _teams,
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('Unable to load standings.'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final standings = SeasonEngine.standings(snap.data!);
        if (standings.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: EmptyCard(
              icon: Icons.emoji_events_outlined,
              title: 'No teams yet',
              message: 'Teams appear once members join the league.',
            ),
          );
        }
        final rows = [
          for (final t in standings)
            PodiumEntry(
              name: t.teamName,
              points: t.pointsFor,
              record: t.record,
              isMe: t.id == myTeamId,
            ),
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            PodiumStand(top: rows.take(3).toList()),
            if (rows.length > 3) ...[
              const SizedBox(height: 22),
              RankedList(entries: rows.sublist(3), firstRank: 4),
            ],
            const SizedBox(height: 12),
            const Text(
              'Ranked by record, then total points.',
              textAlign: TextAlign.center,
              style: PodiumText.caption,
            ),
          ],
        );
      },
    );
  }
}
