import '../models/league.dart';
import '../models/matchup.dart';
import '../models/roster_slot.dart';
import 'player_history_service.dart';
import 'season_engine.dart';
import 'team_service.dart';

/// Running scores for the current week, computed the same way the
/// commissioner's "Score week" does (starter points from playerStats), so
/// the matchup screens can show live numbers once lineups lock.
///
/// Podium replays a past season, so a week's stats are already in Firestore.
/// Screens only call this for weeks whose lineups are locked or final, so it
/// never reveals points while players can still change their lineups.
class LiveScoreService {
  LiveScoreService({TeamService? teams, PlayerHistoryService? history})
      : _teams = teams ?? TeamService(),
        _history = history ?? PlayerHistoryService();

  final TeamService _teams;
  final PlayerHistoryService _history;

  // One read of playerStats per scoring period per app session.
  static final Map<String, Future<Map<String, double>>> _pointsCache = {};

  /// playerId -> fantasy points for [week]. Empty if the stats aren't loaded.
  Future<Map<String, double>> pointsForWeek(League league, int week) {
    final periodId = league.periodIdForWeek(week);
    return _pointsCache.putIfAbsent(periodId, () async {
      try {
        return await _history.pointsForPeriod(periodId);
      } catch (_) {
        _pointsCache.remove(periodId);
        rethrow;
      }
    });
  }

  /// Points a team's starters have scored with these player points.
  static double starterPoints({
    required List<RosterSlot> roster,
    required Map<String, double> points,
    required int starterCount,
  }) =>
      SeasonEngine.scoreTeam(roster: roster, points: points, starterCount: starterCount).points;

  /// Live home and away scores for [game] from its week's stats.
  Future<({double home, double away})> liveScores(League league, Matchup game) async {
    final points = await pointsForWeek(league, game.week);
    final home = await _teams.getRoster(game.homeTeamId);
    final away = game.awayTeamId == null ? const <RosterSlot>[] : await _teams.getRoster(game.awayTeamId!);
    return (
      home: starterPoints(roster: home, points: points, starterCount: league.starterCount),
      away: starterPoints(roster: away, points: points, starterCount: league.starterCount),
    );
  }
}
