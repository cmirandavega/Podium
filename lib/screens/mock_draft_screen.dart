import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/podium_ui.dart';

enum DraftStatus { notStarted, inProgress, completed }

enum DraftFormat { snake, linear }

class DraftPlayer {
  final String id;
  final String name;
  final String sport;
  final String position;
  final String team;
  final Map<String, num> stats;

  const DraftPlayer({
    required this.id,
    required this.name,
    required this.sport,
    required this.position,
    required this.team,
    required this.stats,
  });
}

class MockDraftTeam {
  final String name;
  final bool isUser;
  final List<DraftPlayer> roster = [];

  MockDraftTeam(this.name, {this.isUser = false});
}

class MockDraftController extends ChangeNotifier {
  final Random _random = Random();

  DraftStatus status = DraftStatus.notStarted;
  DraftFormat format = DraftFormat.snake;

  int teamCount = 8;
  int rounds = 5;
  int currentPick = 0;
  int userTeamIndex = 0;

  String selectedSport = 'NFL';
  String? errorMessage;

  List<DraftPlayer> availablePlayers = [];
  List<MockDraftTeam> teams = [];

  final List<String> history = [];

  int get totalPicks => teamCount * rounds;

  int get currentRound => currentPick ~/ teamCount + 1;

  int get currentTeamIndex {
    final index = currentPick % teamCount;
    if (format == DraftFormat.snake && (currentRound - 1).isOdd) {
      return teamCount - 1 - index;
    }
    return index;
  }

  bool get isUserTurn =>
      status == DraftStatus.inProgress && currentTeamIndex == userTeamIndex;

  MockDraftTeam get userTeam => teams[userTeamIndex];

  void configure({
    required int teams,
    required int draftRounds,
    required String sport,
    required DraftFormat draftFormat,
  }) {
    teamCount = teams;
    rounds = draftRounds;
    selectedSport = sport;
    format = draftFormat;
    notifyListeners();
  }

  void startDraft(List<DraftPlayer> players) {
    reset();

    availablePlayers = players
        .where(
          (p) => selectedSport == 'Multi-Sport' || p.sport == selectedSport,
        )
        .toList();

    if (availablePlayers.length < totalPicks) {
      errorMessage =
          'Not enough players available for this draft. '
          'Reduce the number of teams or rounds.';
      notifyListeners();
      return;
    }

    teams = List.generate(
      teamCount,
      (index) => MockDraftTeam(
        index == userTeamIndex ? 'My Team' : 'CPU Team $index',
        isUser: index == userTeamIndex,
      ),
    );

    status = DraftStatus.inProgress;
    notifyListeners();
    runOpponents();
  }

  String? validatePick(DraftPlayer player) {
    if (status != DraftStatus.inProgress) {
      return 'The draft is not active.';
    }

    if (!isUserTurn) {
      return 'Wait for your turn.';
    }

    if (!availablePlayers.any((p) => p.id == player.id)) {
      return 'This player has already been drafted.';
    }

    if (userTeam.roster.length >= rounds) {
      return 'Your roster is full.';
    }

    return null;
  }

  bool draftPlayer(DraftPlayer player) {
    final validation = validatePick(player);

    if (validation != null) {
      errorMessage = validation;
      notifyListeners();
      return false;
    }

    errorMessage = null;
    _makePick(player);
    runOpponents();
    return true;
  }

  void _makePick(DraftPlayer player) {
    final team = teams[currentTeamIndex];

    team.roster.add(player);
    availablePlayers.removeWhere((p) => p.id == player.id);

    history.add(
      'Round $currentRound: ${team.name} selected '
      '${player.name} (${player.position})',
    );

    currentPick++;

    if (currentPick >= totalPicks) {
      status = DraftStatus.completed;
    }

    notifyListeners();
  }

  void runOpponents() {
    while (status == DraftStatus.inProgress && !isUserTurn) {
      if (availablePlayers.isEmpty) {
        errorMessage = 'No eligible players remain.';
        status = DraftStatus.completed;
        break;
      }

      final choice = availablePlayers[_random.nextInt(availablePlayers.length)];

      _makePick(choice);
    }

    notifyListeners();
  }

  void reset() {
    status = DraftStatus.notStarted;
    currentPick = 0;
    errorMessage = null;
    availablePlayers = [];
    teams = [];
    history.clear();
    notifyListeners();
  }
}

class MockDraftScreen extends StatefulWidget {
  const MockDraftScreen({super.key});

  @override
  State<MockDraftScreen> createState() => _MockDraftScreenState();
}

class _MockDraftScreenState extends State<MockDraftScreen> {
  final MockDraftController controller = MockDraftController();

  int teamCount = 8;
  int rounds = 5;
  String sport = 'NFL';
  DraftFormat format = DraftFormat.snake;

  // Filters for the available-players list (view only; CPU picks ignore them).
  final _search = TextEditingController();
  String _query = '';
  String? _position;

  // Fictional players and statistics for the mock draft.
  List<DraftPlayer> get demoPlayers {
    final sports = ['NFL', 'NBA', 'MLB', 'Soccer'];
    final positions = {
      'NFL': ['QB', 'RB', 'WR', 'TE'],
      'NBA': ['PG', 'SG', 'SF', 'PF', 'C'],
      'MLB': ['P', 'C', '1B', '2B', 'SS', 'OF'],
      'Soccer': ['GK', 'DEF', 'MID', 'FWD'],
    };

    const firstNames = [
      'Marcus',
      'Jordan',
      'Devin',
      'Cameron',
      'Elijah',
      'Andre',
      'Malik',
      'Jalen',
      'Isaiah',
      'Darius',
      'Tyler',
      'Xavier',
      'Caleb',
      'Brandon',
      'Jayden',
      'Anthony',
      'Miles',
      'Nathan',
      'Ethan',
      'Damien',
      'Trey',
      'Dominic',
      'Adrian',
      'Landon',
      'Noah',
      'Julian',
      'Kendrick',
      'Austin',
      'Derrick',
      'Bryce',
    ];

    const lastNames = [
      'Bennett',
      'Hayes',
      'Mitchell',
      'Brooks',
      'Carter',
      'Reynolds',
      'Harris',
      'Coleman',
      'Parker',
      'Foster',
      'Williams',
      'Johnson',
      'Turner',
      'Richardson',
      'Collins',
      'Washington',
      'Morgan',
      'Cooper',
      'Jackson',
      'Thompson',
      'Edwards',
      'Walker',
      'Henderson',
      'Robinson',
      'Phillips',
      'Sullivan',
      'Griffin',
      'Russell',
      'Bailey',
      'Anderson',
    ];

    const cities = [
      'Atlanta',
      'Chicago',
      'Dallas',
      'Miami',
      'Denver',
      'Seattle',
      'Boston',
      'Phoenix',
      'Detroit',
      'Orlando',
      'Houston',
      'Nashville',
      'Portland',
      'Cleveland',
      'Charlotte',
      'Austin',
      'Memphis',
      'Baltimore',
      'Las Vegas',
      'San Diego',
    ];

    const mascots = [
      'Hawks',
      'Wolves',
      'Titans',
      'Sharks',
      'Mustangs',
      'Storm',
      'Knights',
      'Falcons',
      'Panthers',
      'Bears',
      'Warriors',
      'Vipers',
      'Lions',
      'Eagles',
      'Dragons',
      'Ravens',
      'Bulls',
      'Tigers',
      'Royals',
      'Thunder',
    ];

    return List.generate(240, (i) {
      final playerSport = sports[i % sports.length];
      final options = positions[playerSport]!;
      final position = options[i % options.length];

      final firstName = firstNames[i % firstNames.length];
      final lastName =
          lastNames[(i ~/ firstNames.length + i * 7) % lastNames.length];

      final clubIndex = i % cities.length;
      final playerStats = _generateStats(playerSport, position, i);

      return DraftPlayer(
        id: 'demo_$i',
        name: '$firstName $lastName',
        sport: playerSport,
        position: position,
        team: '${cities[clubIndex]} ${mascots[clubIndex]}',
        stats: playerStats,
      );
    });
  }

  Map<String, num> _generateStats(
    String playerSport,
    String position,
    int seed,
  ) {
    final random = Random(seed + 2026);

    if (playerSport == 'NFL') {
      switch (position) {
        case 'QB':
          return {
            'Games Played': 17,
            'Passing Yards': 2800 + random.nextInt(1800),
            'Passing Touchdowns': 18 + random.nextInt(23),
            'Interceptions': 4 + random.nextInt(12),
            'Rushing Yards': 100 + random.nextInt(550),
            'Fantasy Points': 210 + random.nextInt(170),
          };
        case 'RB':
          return {
            'Games Played': 17,
            'Rushing Yards': 550 + random.nextInt(1100),
            'Rushing Touchdowns': 3 + random.nextInt(14),
            'Receptions': 15 + random.nextInt(65),
            'Receiving Yards': 100 + random.nextInt(650),
            'Fantasy Points': 130 + random.nextInt(210),
          };
        case 'WR':
          return {
            'Games Played': 17,
            'Receptions': 35 + random.nextInt(85),
            'Receiving Yards': 450 + random.nextInt(1250),
            'Receiving Touchdowns': 2 + random.nextInt(14),
            'Fantasy Points': 100 + random.nextInt(230),
          };
        case 'TE':
          return {
            'Games Played': 17,
            'Receptions': 25 + random.nextInt(75),
            'Receiving Yards': 300 + random.nextInt(850),
            'Receiving Touchdowns': 2 + random.nextInt(11),
            'Fantasy Points': 75 + random.nextInt(185),
          };
      }
    }

    if (playerSport == 'NBA') {
      return {
        'Games Played': 55 + random.nextInt(28),
        'Points Per Game': 8 + random.nextInt(25),
        'Rebounds Per Game': 2 + random.nextInt(11),
        'Assists Per Game': 1 + random.nextInt(11),
        'Steals Per Game': 1 + random.nextInt(3),
        'Fantasy Points Per Game': 20 + random.nextInt(40),
      };
    }

    if (playerSport == 'MLB') {
      if (position == 'P') {
        return {
          'Games Played': 20 + random.nextInt(20),
          'Wins': 5 + random.nextInt(15),
          'Strikeouts': 80 + random.nextInt(170),
          'ERA': double.parse(
            (2.50 + random.nextDouble() * 2.50).toStringAsFixed(2),
          ),
          'Fantasy Points': 100 + random.nextInt(220),
        };
      }

      return {
        'Games Played': 100 + random.nextInt(63),
        'Home Runs': 5 + random.nextInt(40),
        'Runs Batted In': 30 + random.nextInt(100),
        'Hits': 80 + random.nextInt(120),
        'Stolen Bases': random.nextInt(35),
        'Fantasy Points': 120 + random.nextInt(230),
      };
    }

    return {
      'Matches Played': 20 + random.nextInt(19),
      'Goals': position == 'GK' ? 0 : random.nextInt(25),
      'Assists': position == 'GK' ? 0 : random.nextInt(17),
      'Clean Sheets': random.nextInt(16),
      'Fantasy Points': 60 + random.nextInt(200),
    };
  }

  // Opens a separate screen instead of a popup.
  void _openPlayerDetails(DraftPlayer player) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MockDraftPlayerDetailsScreen(
          player: player,
          controller: controller,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_refresh);
    controller.dispose();
    _search.dispose();
    super.dispose();
  }

  void _startDraft() {
    _search.clear();
    _query = '';
    _position = null;
    controller.configure(
      teams: teamCount,
      draftRounds: rounds,
      sport: sport,
      draftFormat: format,
    );

    controller.startDraft(demoPlayers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mock Draft'),
            Text(
              'Practice against CPU teams',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: PodiumColors.muted),
            ),
          ],
        ),
        actions: [
          if (controller.status != DraftStatus.notStarted)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SquareIconButton(
                icon: Icons.restart_alt,
                tooltip: 'Restart draft',
                onPressed: controller.reset,
              ),
            ),
        ],
      ),
      body: switch (controller.status) {
        DraftStatus.notStarted => _buildSetup(),
        DraftStatus.inProgress => _buildDraft(),
        DraftStatus.completed => _buildResults(),
      },
    );
  }

  Widget _optionCard({required String label, required Widget child}) {
    return PodiumCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: PodiumText.overline),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _choices<T>(List<T> values, T selected, String Function(T) label, ValueChanged<T> onPick) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(label(v)),
            selected: v == selected,
            onSelected: (_) => setState(() => onPick(v)),
          ),
      ],
    );
  }

  Widget _buildSetup() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        PodiumCard(
          margin: const EdgeInsets.only(bottom: 16),
          child: const Row(
            children: [
              TintedIcon(
                icon: Icons.grid_view_rounded,
                color: PodiumColors.bronzeText,
                background: PodiumColors.bronzeTint,
                size: 48,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Set up a practice draft', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text(
                      'Fictional players and CPU teams. Nothing here touches your real leagues.',
                      style: TextStyle(fontSize: 13, color: PodiumColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _optionCard(
          label: 'Teams',
          child: _choices<int>(const [4, 6, 8, 10, 12], teamCount, (n) => '$n', (n) => teamCount = n),
        ),
        _optionCard(
          label: 'Rounds',
          child: _choices<int>(const [3, 5, 8, 10], rounds, (n) => '$n', (n) => rounds = n),
        ),
        _optionCard(
          label: 'Sport',
          child: _choices<String>(
            const ['NFL', 'NBA', 'MLB', 'Soccer', 'Multi-Sport'],
            sport,
            (s) => s,
            (s) => sport = s,
          ),
        ),
        _optionCard(
          label: 'Format',
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<DraftFormat>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: DraftFormat.snake, label: Text('Snake'), icon: Icon(Icons.swap_vert)),
                ButtonSegment(value: DraftFormat.linear, label: Text('Linear'), icon: Icon(Icons.south)),
              ],
              selected: {format},
              onSelectionChanged: (s) => setState(() => format = s.first),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Text(
            '${teamCount * rounds} total picks · you pick first'
            '${format == DraftFormat.snake ? ', order reverses each round' : ''}',
            style: PodiumText.caption.copyWith(fontSize: 13),
          ),
        ),
        if (controller.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(controller.errorMessage!, style: const TextStyle(color: PodiumColors.dangerText)),
          ),
        FilledButton.icon(
          onPressed: _startDraft,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start mock draft'),
        ),
      ],
    );
  }

  Widget _buildDraft() {
    final progress = controller.totalPicks == 0 ? 0.0 : controller.currentPick / controller.totalPicks;
    final positions = <String>{for (final p in controller.availablePlayers) p.position}.toList()..sort();
    final query = _query.trim().toLowerCase();
    final players = controller.availablePlayers
        .where((p) => _position == null || p.position == _position)
        .where((p) => query.isEmpty || p.name.toLowerCase().contains(query) || p.team.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => _points(b).compareTo(_points(a)));
    final roster = controller.userTeam.roster;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: PodiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ROUND', style: PodiumText.overline),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('${controller.currentRound}', style: PodiumText.score(size: 40, color: PodiumColors.gold)),
                            Text(' / $rounds', style: PodiumText.score(size: 22, color: PodiumColors.muted)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PICK', style: PodiumText.overline),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('${controller.currentPick + 1}', style: PodiumText.score(size: 40)),
                            Text(' / ${controller.totalPicks}', style: PodiumText.score(size: 22, color: PodiumColors.muted)),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    controller.isUserTurn
                        ? const StatusPill.gold('YOUR PICK')
                        : const StatusPill(label: 'CPU DRAFTING'),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(PodiumRadii.pill),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: PodiumColors.gold,
                    backgroundColor: PodiumColors.line,
                  ),
                ),
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(controller.errorMessage!, style: const TextStyle(color: PodiumColors.dangerText, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search players or teams',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                      }),
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('All'),
                  selected: _position == null,
                  onSelected: (_) => setState(() => _position = null),
                ),
              ),
              for (final pos in positions)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(pos),
                    selected: _position == pos,
                    onSelected: (_) => setState(() => _position = _position == pos ? null : pos),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
          child: Row(
            children: [
              Text('BEST AVAILABLE · ${players.length}', style: PodiumText.overline),
              const Spacer(),
              const Text('FPTS', style: PodiumText.overline),
            ],
          ),
        ),
        Expanded(
          child: players.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: EmptyCard(
                      icon: Icons.person_search_outlined,
                      title: 'No players match',
                      message: 'Clear the search or pick another position.',
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  itemCount: players.length,
                  itemBuilder: (context, i) => _PlayerRow(
                    player: players[i],
                    points: _points(players[i]),
                    onTap: () => _openPlayerDetails(players[i]),
                  ),
                ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: PodiumColors.deep,
            border: Border(top: BorderSide(color: PodiumColors.line)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MY ROSTER', style: PodiumText.overline),
                      const SizedBox(height: 2),
                      Text('${roster.length}/$rounds', style: PodiumText.score(size: 24, color: PodiumColors.gold)),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: roster.isEmpty
                          ? const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Tap a player to see stats and draft',
                                  style: TextStyle(fontSize: 13, color: PodiumColors.muted)),
                            )
                          : ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (final p in roster)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text('${p.position} ${_lastName(p.name)}'),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  TextButton(
                    onPressed: controller.reset,
                    child: const Text('Leave'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: PodiumText.score(size: 30)),
          const SizedBox(height: 4),
          Text(label.toUpperCase(), style: PodiumText.overline.copyWith(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final myTeam = controller.teams.where((t) => t.isUser).toList();
    final others = controller.teams.where((t) => !t.isUser).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        PodiumCard(
          borderColor: PodiumColors.gold,
          child: Column(
            children: [
              const TintedIcon(icon: Icons.emoji_events_outlined, size: 52),
              const SizedBox(height: 12),
              const Text('Draft complete', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Your ${myTeam.isEmpty ? 0 : myTeam.first.roster.length}-player roster projects '
                '${myTeam.isEmpty ? '0' : _teamPoints(myTeam.first).toStringAsFixed(0)} fantasy points.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: PodiumColors.muted),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _stat('Picks', '${controller.currentPick}'),
                  _stat('Teams', '${controller.teamCount}'),
                  _stat('Format', controller.format == DraftFormat.snake ? 'Snake' : 'Linear'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (final team in myTeam) ...[
          const SectionHeader('Your team'),
          const SizedBox(height: 8),
          _teamCard(team, expanded: true),
        ],
        const SizedBox(height: 12),
        const SectionHeader('CPU teams'),
        const SizedBox(height: 8),
        for (final team in others) _teamCard(team),
        const SizedBox(height: 12),
        const SectionHeader('Draft history'),
        const SizedBox(height: 8),
        PodiumCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (var i = 0; i < controller.history.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text('${i + 1}', style: PodiumText.score(size: 18, color: PodiumColors.muted)),
                      ),
                      Expanded(
                        child: Text(
                          controller.history[i].replaceFirst(RegExp(r'^Round \d+: '), ''),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: controller.history[i].contains('My Team') ? FontWeight.w700 : FontWeight.w400,
                            color: controller.history[i].contains('My Team') ? PodiumColors.gold : PodiumColors.chalk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: controller.reset,
          icon: const Icon(Icons.replay_rounded),
          label: const Text('New mock draft'),
        ),
      ],
    );
  }

  Widget _teamCard(MockDraftTeam team, {bool expanded = false}) {
    return PodiumCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      borderColor: team.isUser ? PodiumColors.gold : PodiumColors.line,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          leading: InitialsAvatar(
            name: team.name,
            size: 36,
            ring: team.isUser ? PodiumColors.gold : PodiumColors.line,
          ),
          title: Text(team.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${team.roster.length} players · ${_teamPoints(team).toStringAsFixed(0)} FPTS'),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          children: [
            for (final p in team.roster)
              _PlayerRow(player: p, points: _points(p), onTap: () => _openPlayerDetails(p), compact: true),
          ],
        ),
      ),
    );
  }
}

/// Projected fantasy points used to rank players (NBA uses per-game points).
double _points(DraftPlayer p) =>
    (p.stats['Fantasy Points'] ?? p.stats['Fantasy Points Per Game'] ?? 0).toDouble();

double _teamPoints(MockDraftTeam team) => team.roster.fold(0.0, (sum, p) => sum + _points(p));

String _lastName(String name) => name.contains(' ') ? name.substring(name.lastIndexOf(' ') + 1) : name;

/// Accent per sport so mixed-sport drafts are easy to scan.
(Color, Color) _sportColors(String sport) => switch (sport) {
      'NFL' => (PodiumColors.gold, PodiumColors.goldTint),
      'NBA' => (PodiumColors.bronzeText, PodiumColors.bronzeTint),
      'MLB' => (PodiumColors.silver, PodiumColors.silverTint),
      _ => (PodiumColors.chalk, PodiumColors.raised),
    };

/// Square position badge, e.g. "QB" on a gold tint for NFL.
class _PositionBadge extends StatelessWidget {
  const _PositionBadge({required this.player, this.size = 42});

  final DraftPlayer player;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (color, tint) = _sportColors(player.sport);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Text(
        player.position,
        style: PodiumText.score(size: size * 0.42, color: color),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player, required this.points, required this.onTap, this.compact = false});

  final DraftPlayer player;
  final double points;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PodiumCard(
      margin: EdgeInsets.only(bottom: compact ? 6 : 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 8 : 10),
      radius: PodiumRadii.tile,
      color: compact ? PodiumColors.navy : PodiumColors.field,
      onTap: onTap,
      child: Row(
        children: [
          _PositionBadge(player: player, size: compact ? 36 : 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${player.sport} · ${player.team}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: PodiumColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(points.toStringAsFixed(0), style: PodiumText.score(size: 24)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 20, color: PodiumColors.muted),
        ],
      ),
    );
  }
}

// Separate player details screen.
// The draft button is only available here.
class MockDraftPlayerDetailsScreen extends StatelessWidget {
  const MockDraftPlayerDetailsScreen({
    super.key,
    required this.player,
    required this.controller,
  });

  final DraftPlayer player;
  final MockDraftController controller;

  Future<void> _confirmDraft(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm pick'),
        content: Text(
          'Draft ${player.name} (${player.position})? '
          'This pick cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Draft'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success = controller.draftPlayer(player);

    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.errorMessage ?? 'Unable to draft player.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final canDraft = controller.validatePick(player) == null;
        final stats = player.stats.entries.toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Player')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              PodiumCard(
                child: Row(
                  children: [
                    _PositionBadge(player: player, size: 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.name,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${player.sport} · ${player.position} · ${player.team}',
                            style: const TextStyle(fontSize: 13, color: PodiumColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(_points(player).toStringAsFixed(0), style: PodiumText.score(size: 34, color: PodiumColors.gold)),
                        const SizedBox(height: 2),
                        Text('FPTS', style: PodiumText.overline.copyWith(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader('Season stats'),
              const SizedBox(height: 4),
              Text('Fictional player statistics', style: PodiumText.caption.copyWith(fontSize: 13)),
              const SizedBox(height: 12),
              for (var i = 0; i < stats.length; i += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(child: _StatTile(label: stats[i].key, value: '${stats[i].value}')),
                      const SizedBox(width: 10),
                      Expanded(
                        child: i + 1 < stats.length
                            ? _StatTile(label: stats[i + 1].key, value: '${stats[i + 1].value}')
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: PodiumColors.deep,
              border: Border(top: BorderSide(color: PodiumColors.line)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: FilledButton(
                  onPressed: canDraft ? () => _confirmDraft(context) : null,
                  child: Text(canDraft ? 'Draft ${player.name}' : 'Not your pick'),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return PodiumCard(
      radius: PodiumRadii.tile,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PodiumText.overline.copyWith(fontSize: 10.5),
          ),
          const SizedBox(height: 6),
          Text(value, style: PodiumText.score(size: 28)),
        ],
      ),
    );
  }
}
