import 'package:cloud_firestore/cloud_firestore.dart';

/// A team's recap for one scoring week, stored at
/// weeklyReports/{teamId}_{scoringPeriodId} (Use Case 5).
///
/// teamId, scoringPeriodId, pointsEarned, rosterEfficiency, rankChange, and
/// createdAt are from the database table. The rest were added in Sprint 4 to
/// show the matchup result and missed opportunities.
class WeeklyReport {
  const WeeklyReport({
    required this.id,
    required this.teamId,
    required this.leagueId,
    required this.scoringPeriodId,
    required this.week,
    required this.pointsEarned,
    required this.optimalPoints,
    required this.rosterEfficiency,
    required this.rankChange,
    required this.rank,
    required this.result,
    this.opponentTeamId,
    this.opponentPoints,
    this.topScorerName,
    this.topScorerPoints,
    this.bestBenchName,
    this.bestBenchPoints,
    this.createdAt,
  });

  final String id;
  final String teamId;
  final String leagueId;
  final String scoringPeriodId;
  final int week;
  final double pointsEarned;
  final double optimalPoints;
  final double rosterEfficiency; // pointsEarned / optimalPoints, 0..1
  final int rankChange; // positive = moved up
  final int rank;
  final String result; // "W", "L", "T", or "BYE"
  final String? opponentTeamId;
  final double? opponentPoints;
  final String? topScorerName;
  final double? topScorerPoints;
  final String? bestBenchName;
  final double? bestBenchPoints;
  final DateTime? createdAt;

  double get missedPoints => (optimalPoints - pointsEarned).clamp(0, double.infinity).toDouble();

  static String idFor(String teamId, String periodId) => '${teamId}_$periodId';

  factory WeeklyReport.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    double? optDouble(String key) => (data[key] as num?)?.toDouble();
    return WeeklyReport(
      id: doc.id,
      teamId: data['teamId'] as String? ?? '',
      leagueId: data['leagueId'] as String? ?? '',
      scoringPeriodId: data['scoringPeriodId'] as String? ?? '',
      week: (data['week'] as num?)?.toInt() ?? 0,
      pointsEarned: optDouble('pointsEarned') ?? 0,
      optimalPoints: optDouble('optimalPoints') ?? 0,
      rosterEfficiency: optDouble('rosterEfficiency') ?? 0,
      rankChange: (data['rankChange'] as num?)?.toInt() ?? 0,
      rank: (data['rank'] as num?)?.toInt() ?? 0,
      result: data['result'] as String? ?? '',
      opponentTeamId: data['opponentTeamId'] as String?,
      opponentPoints: optDouble('opponentPoints'),
      topScorerName: data['topScorerName'] as String?,
      topScorerPoints: optDouble('topScorerPoints'),
      bestBenchName: data['bestBenchName'] as String?,
      bestBenchPoints: optDouble('bestBenchPoints'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
