import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/league.dart';
import '../../services/league_service.dart';
import '../../theme.dart';
import '../coach/coach_screen.dart';
import 'home_tab.dart';
import 'leaders_tab.dart';
import 'matchup_tab.dart';
import 'picks_tab.dart';
import 'shell_widgets.dart';

/// The signed-in app: five bottom tabs (Home, Picks, Matchup, Leaders,
/// Coach). Picks, Matchup, Leaders, and Coach follow the active league,
/// which the user switches from Home or any tab header.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Stream<List<League>> _leagues = LeagueService().watchMyLeagues(widget.user.uid);
  int _tab = ShellTab.home;
  String? _leagueId;

  void _selectLeague(String id) => setState(() => _leagueId = id);
  void _goTo(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return StreamBuilder<List<League>>(
      stream: _leagues,
      builder: (context, snap) {
        final leagues = snap.data ?? const <League>[];
        League? active;
        for (final l in leagues) {
          if (l.id == _leagueId) active = l;
        }
        if (active == null && leagues.isNotEmpty) active = leagues.first;
        final league = active;

        Widget leagueTab(String title, String message, Widget Function(League l) build) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (league == null) return NoLeagueView(user: user, title: title, message: message);
          return build(league);
        }

        final tabs = <Widget>[
          HomeTab(
            user: user,
            leagues: leagues,
            active: league,
            leaguesLoaded: snap.hasData,
            onSelectLeague: _selectLeague,
            onGoTo: _goTo,
          ),
          leagueTab(
            'Picks',
            'Picks are wagers on your league\'s weekly games, paid in Podium coins.',
            (l) => PicksTab(
              key: ValueKey('picks_${l.id}'),
              user: user,
              league: l,
              leagues: leagues,
              onSelectLeague: _selectLeague,
            ),
          ),
          leagueTab(
            'Matchup',
            'Your weekly head-to-head shows here once you\'re in a league.',
            (l) => MatchupTab(
              key: ValueKey('matchup_${l.id}'),
              user: user,
              league: l,
              leagues: leagues,
              onSelectLeague: _selectLeague,
            ),
          ),
          LeadersTab(
            key: ValueKey('leaders_${league?.id ?? 'none'}'),
            user: user,
            league: league,
            leagues: leagues,
            onSelectLeague: _selectLeague,
          ),
          leagueTab(
            'Coach',
            'The AI Coach gives lineup advice from your league roster.',
            (l) => CoachScreen(key: ValueKey('coach_${l.id}'), leagueId: l.id, userId: user.uid),
          ),
        ];

        return Scaffold(
          body: IndexedStack(index: _tab, children: tabs),
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PodiumColors.line)),
            ),
            child: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: _goTo,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.track_changes_outlined),
                  selectedIcon: Icon(Icons.track_changes_rounded),
                  label: 'Picks',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bolt_outlined),
                  selectedIcon: Icon(Icons.bolt_rounded),
                  label: 'Matchup',
                ),
                NavigationDestination(
                  icon: Icon(Icons.emoji_events_outlined),
                  selectedIcon: Icon(Icons.emoji_events_rounded),
                  label: 'Leaders',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  selectedIcon: Icon(Icons.auto_awesome),
                  label: 'Coach',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
