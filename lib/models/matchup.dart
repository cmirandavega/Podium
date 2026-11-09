import 'package:cloud_firestore/cloud_firestore.dart';

/// One head-to-head game for one week, stored at
/// matchups/{leagueId}_w{week}_{index} (Use Case 15, new in Sprint 4).
/// A matchup with no awayTeamId is a bye week for the home team.
class Matchup {
  const Matchup({
    required this.id,
    required this.leagueId,
    required this.week,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeScore,
    required this.awayScore,
    required this.status,
    required this.type,
    required this.round,
    this.winnerTeamId,
  });

  final String id;
  final String leagueId;
  final int week;
  final String homeTeamId;
  final String? awayTeamId;
  final double homeScore;
  final double awayScore;
  final String status; // "scheduled" or "final"
  final String type; // "regular" or "playoff"
  final int round; // playoff round (1 = first round); 0 for regular season
  final String? winnerTeamId; // null for ties, byes, and unplayed games

  bool get isBye => awayTeamId == null;
  bool get isFinal => status == 'final';
  bool get isPlayoff => type == 'playoff';
  bool involves(String teamId) => homeTeamId == teamId || awayTeamId == teamId;

  static String idFor(String leagueId, int week, int index) => '${leagueId}_w${week}_$index';

  factory Matchup.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Matchup(
      id: doc.id,
      leagueId: data['leagueId'] as String? ?? '',
      week: (data['week'] as num?)?.toInt() ?? 0,
      homeTeamId: data['homeTeamId'] as String? ?? '',
      awayTeamId: data['awayTeamId'] as String?,
      homeScore: (data['homeScore'] as num?)?.toDouble() ?? 0,
      awayScore: (data['awayScore'] as num?)?.toDouble() ?? 0,
      status: data['status'] as String? ?? 'scheduled',
      type: data['type'] as String? ?? 'regular',
      round: (data['round'] as num?)?.toInt() ?? 0,
      winnerTeamId: data['winnerTeamId'] as String?,
    );
  }
}

/// A pairing produced by the schedule generator, before it's saved.
typedef Pairing = ({String home, String? away});
