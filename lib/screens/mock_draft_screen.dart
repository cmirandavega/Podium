import 'dart:math';

import 'package:flutter/material.dart';

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
    super.dispose();
  }

  void _startDraft() {
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
        title: const Text('Mock Draft Simulator'),
        actions: [
          if (controller.status != DraftStatus.notStarted)
            IconButton(
              tooltip: 'Restart draft',
              icon: const Icon(Icons.restart_alt),
              onPressed: controller.reset,
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

  Widget _buildSetup() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Create a Mock Draft',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        const Text('Number of Teams'),
        DropdownButton<int>(
          isExpanded: true,
          value: teamCount,
          items: [4, 6, 8, 10, 12]
              .map((n) => DropdownMenuItem(value: n, child: Text('$n Teams')))
              .toList(),
          onChanged: (value) => setState(() => teamCount = value!),
        ),
        const SizedBox(height: 16),
        const Text('Number of Rounds'),
        DropdownButton<int>(
          isExpanded: true,
          value: rounds,
          items: [3, 5, 8, 10]
              .map((n) => DropdownMenuItem(value: n, child: Text('$n Rounds')))
              .toList(),
          onChanged: (value) => setState(() => rounds = value!),
        ),
        const SizedBox(height: 16),
        const Text('Sport'),
        DropdownButton<String>(
          isExpanded: true,
          value: sport,
          items: [
            'NFL',
            'NBA',
            'MLB',
            'Soccer',
            'Multi-Sport',
          ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (value) => setState(() => sport = value!),
        ),
        const SizedBox(height: 16),
        const Text('Draft Format'),
        DropdownButton<DraftFormat>(
          isExpanded: true,
          value: format,
          items: DraftFormat.values
              .map(
                (f) => DropdownMenuItem(
                  value: f,
                  child: Text(
                    f == DraftFormat.snake ? 'Snake Draft' : 'Linear Draft',
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => format = value!),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _startDraft,
          child: const Text('Start Mock Draft'),
        ),
        if (controller.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              controller.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _buildDraft() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Round ${controller.currentRound} of $rounds',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Pick ${controller.currentPick + 1} '
                'of ${controller.totalPicks}',
              ),
              const SizedBox(height: 8),
              Text(controller.isUserTurn ? 'Your Turn!' : 'CPU is drafting...'),
              if (controller.errorMessage != null)
                Text(
                  controller.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: controller.availablePlayers.length,
            itemBuilder: (context, index) {
              final player = controller.availablePlayers[index];

              return ListTile(
                title: Text(player.name),
                subtitle: Text(
                  '${player.sport} | ${player.position} | '
                  '${player.team}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openPlayerDetails(player),
              );
            },
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                'My Roster (${controller.userTeam.roster.length}/$rounds)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(
                height: 90,
                child: ListView(
                  children: controller.userTeam.roster
                      .map((p) => Text('${p.name} - ${p.position}'))
                      .toList(),
                ),
              ),
              TextButton(
                onPressed: controller.reset,
                child: const Text('Leave Draft'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Draft Complete!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text('Total Picks: ${controller.currentPick}'),
        Text('Teams: ${controller.teamCount}'),
        Text('Format: ${controller.format.name}'),
        const SizedBox(height: 20),
        ...controller.teams.map(
          (team) => Card(
            child: ExpansionTile(
              initiallyExpanded: team.isUser,
              title: Text(team.name),
              subtitle: Text('${team.roster.length} players drafted'),
              children: team.roster
                  .map(
                    (p) => ListTile(
                      title: Text(p.name),
                      subtitle: Text('${p.sport} | ${p.position}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openPlayerDetails(p),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Draft History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        ...controller.history.map(
          (entry) => ListTile(dense: true, title: Text(entry)),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: controller.reset,
          child: const Text('Create New Mock Draft'),
        ),
      ],
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
        title: const Text('Confirm Draft Pick'),
        content: Text(
          'Are you sure you want to draft ${player.name}? '
          'This pick cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm Draft'),
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

        return Scaffold(
          appBar: AppBar(title: const Text('Player Details')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                player.name,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${player.sport} | ${player.position}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(player.team),
              const SizedBox(height: 24),
              Text(
                'Season Statistics',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Fictional player statistics'),
              const Divider(),
              ...player.stats.entries.map(
                (stat) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(stat.key),
                  trailing: Text(
                    '${stat.value}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: canDraft ? () => _confirmDraft(context) : null,
                child: Text(
                  canDraft ? 'Draft ${player.name}' : 'Draft Unavailable',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
