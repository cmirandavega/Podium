import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/league.dart';
import '../models/player_stat.dart';

/// Weekly fantasy points for players, read from playerStats. Shared by the
/// AI Coach, the Trade Analyzer, and matchup scoring.
///
/// Podium replays a past season week by week, so later weeks are already in
/// Firestore. [visibleThroughWeek] keeps features from using weeks the league
/// hasn't reached yet.
class PlayerHistoryService {
  PlayerHistoryService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Parses "period_2024_w3" into (season "2024", week 3).
  static ({String season, int week})? parsePeriodId(String periodId) {
    final match = RegExp(r'^period_(\w+)_w(\d+)$').firstMatch(periodId);
    if (match == null) return null;
    return (season: match.group(1)!, week: int.parse(match.group(2)!));
  }

  /// Last week the league has finished. In the preseason, week 1 is used as
  /// a baseline so the AI tools have something to work from.
  static int visibleThroughWeek(League league) =>
      league.currentWeek > 1 ? league.currentWeek - 1 : 1;

  /// playerId -> {week -> points}, for weeks 1..[throughWeek] of [season].
  Future<Map<String, Map<int, double>>> weeklyPoints({
    required List<String> playerIds,
    required String season,
    required int throughWeek,
  }) async {
    final result = {for (final id in playerIds) id: <int, double>{}};
    for (var i = 0; i < playerIds.length; i += 30) {
      final chunk = playerIds.sublist(i, i + 30 > playerIds.length ? playerIds.length : i + 30);
      final query = await _db.collection('playerStats').where('playerId', whereIn: chunk).get();
      for (final doc in query.docs) {
        final stat = PlayerStat.fromFirestore(doc);
        final period = parsePeriodId(doc.data()['scoringPeriodId'] as String? ?? '');
        if (period == null || period.season != season || period.week > throughWeek) continue;
        final weeks = result.putIfAbsent(stat.playerId, () => {});
        weeks[period.week] = (weeks[period.week] ?? 0) + stat.fantasyPoints;
      }
    }
    return result;
  }

  /// Points scored by each player in one scoring period.
  Future<Map<String, double>> pointsForPeriod(String periodId) async {
    final query = await _db
        .collection('playerStats')
        .where('scoringPeriodId', isEqualTo: periodId)
        .get();
    final points = <String, double>{};
    for (final doc in query.docs) {
      final stat = PlayerStat.fromFirestore(doc);
      points[stat.playerId] = (points[stat.playerId] ?? 0) + stat.fantasyPoints;
    }
    return points;
  }

  /// Best players nobody in the league has rostered, by points in [periodId].
  Future<List<PlayerWeek>> topAvailable({
    required League league,
    required Set<String> takenPlayerIds,
    required String periodId,
    int limit = 15,
  }) async {
    final query = await _db
        .collection('playerStats')
        .where('scoringPeriodId', isEqualTo: periodId)
        .get();
    final byPlayer = <String, PlayerWeek>{};
    for (final doc in query.docs) {
      final line = PlayerStat.fromFirestore(doc);
      if (!league.sports.contains(line.sport) || takenPlayerIds.contains(line.playerId)) continue;
      byPlayer
          .putIfAbsent(
            line.playerId,
            () => PlayerWeek(
              playerId: line.playerId,
              sport: line.sport,
              fullName: line.fullName,
              realTeam: line.realTeam,
              position: line.position,
            ),
          )
          .add(line);
    }
    final players = byPlayer.values.toList()..sort((a, b) => b.points.compareTo(a.points));
    return players.take(limit).toList();
  }

  static double average(Map<int, double> weeks) =>
      weeks.isEmpty ? 0 : weeks.values.reduce((a, b) => a + b) / weeks.length;
}
