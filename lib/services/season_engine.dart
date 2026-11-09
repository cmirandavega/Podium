import '../models/matchup.dart';
import '../models/roster_slot.dart';
import '../models/team.dart';

/// One team's score for a week, plus what Weekly Analysis needs.
typedef TeamWeekScore = ({
  double points,
  double optimalPoints,
  RosterSlot? topScorer,
  double topScorerPoints,
  RosterSlot? bestBench,
  double bestBenchPoints,
});

/// The rules of a Podium season with no Firestore code, so they can be unit
/// tested: schedules, scoring, standings, and playoff seeding (Use Cases 5,
/// 11, and 15).
class SeasonEngine {
  /// Round-robin schedule (circle method). With an odd number of teams, one
  /// team has a bye each week. Home and away alternate by week. If the
  /// season is longer than one full round, the rotation repeats.
  static List<List<Pairing>> roundRobin(List<String> teamIds, int weeks) {
    if (teamIds.length < 2) return [for (var w = 0; w < weeks; w++) const <Pairing>[]];
    final slots = <String?>[...teamIds];
    if (slots.length.isOdd) slots.add(null);
    final n = slots.length;
    final schedule = <List<Pairing>>[];

    var rotation = [...slots];
    for (var week = 0; week < weeks; week++) {
      final games = <Pairing>[];
      for (var i = 0; i < n ~/ 2; i++) {
        final a = rotation[i];
        final b = rotation[n - 1 - i];
        if (a == null && b == null) continue;
        if (a == null || b == null) {
          games.add((home: (a ?? b)!, away: null));
        } else if (week.isEven) {
          games.add((home: a, away: b));
        } else {
          games.add((home: b, away: a));
        }
      }
      schedule.add(games);
      // Keep the first slot fixed and rotate the rest one step.
      rotation = [rotation.first, rotation.last, ...rotation.sublist(1, n - 1)];
    }
    return schedule;
  }

  /// A team's starter points, the best possible lineup's points, its top
  /// scorer, and its best bench player for one week.
  static TeamWeekScore scoreTeam({
    required List<RosterSlot> roster,
    required Map<String, double> points,
    required int starterCount,
  }) {
    double p(RosterSlot s) => points[s.playerId] ?? 0;
    final starters = roster.where((s) => s.isStarter).toList();
    final bench = roster.where((s) => !s.isStarter).toList();
    final actual = starters.fold<double>(0, (sum, s) => sum + p(s));

    final best = [...roster]..sort((a, b) => p(b).compareTo(p(a)));
    final optimal = best.take(starterCount).fold<double>(0, (sum, s) => sum + p(s));

    RosterSlot? top;
    for (final s in starters) {
      if (top == null || p(s) > p(top)) top = s;
    }
    RosterSlot? benchBest;
    for (final s in bench) {
      if (benchBest == null || p(s) > p(benchBest)) benchBest = s;
    }
    return (
      points: _round(actual),
      optimalPoints: _round(optimal),
      topScorer: top,
      topScorerPoints: top == null ? 0 : _round(p(top)),
      bestBench: benchBest,
      bestBenchPoints: benchBest == null ? 0 : _round(p(benchBest)),
    );
  }

  /// Winner of a matchup, or null for a tie. In the playoffs a tie goes to
  /// the home team, which is always the higher seed.
  static String? winner({
    required String home,
    required String away,
    required double homeScore,
    required double awayScore,
    bool playoff = false,
  }) {
    if (homeScore > awayScore) return home;
    if (awayScore > homeScore) return away;
    return playoff ? home : null;
  }

  /// Standings: win percentage, then total points as the tiebreaker
  /// (Use Case 11), then name so the order is stable.
  static List<Team> standings(List<Team> teams) {
    final sorted = [...teams];
    sorted.sort((a, b) {
      final byPct = b.winPct.compareTo(a.winPct);
      if (byPct != 0) return byPct;
      final byPoints = b.pointsFor.compareTo(a.pointsFor);
      if (byPoints != 0) return byPoints;
      return a.teamName.compareTo(b.teamName);
    });
    return sorted;
  }

  /// First playoff round from the final standings: 1 vs 4 and 2 vs 3, or
  /// 1 vs 2 for a two-team final.
  static List<Pairing> seedPlayoffs(List<Team> standings, int playoffTeams) {
    final seeds = standings.take(playoffTeams).map((t) => t.id).toList();
    if (seeds.length < 2) return const [];
    if (seeds.length >= 4) {
      return [(home: seeds[0], away: seeds[3]), (home: seeds[1], away: seeds[2])];
    }
    return [(home: seeds[0], away: seeds[1])];
  }

  /// Number of playoff rounds for a playoff size.
  static int playoffRounds(int playoffTeams) => playoffTeams >= 4 ? 2 : (playoffTeams >= 2 ? 1 : 0);

  /// 1-based rank of each team in [standings].
  static Map<String, int> ranks(List<Team> standings) =>
      {for (var i = 0; i < standings.length; i++) standings[i].id: i + 1};

  static double _round(double v) => (v * 10).roundToDouble() / 10;
}
