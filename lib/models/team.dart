import 'package:cloud_firestore/cloud_firestore.dart';

/// A fantasy team, stored at teams/{leagueId}_{ownerId}, so each user has at
/// most one team per league (Use Case 3).
///
/// wins, losses, ties, and pointsFor are added in Sprint 4 and updated when
/// the commissioner scores a week (Use Case 15). Standings are sorted by
/// record, then pointsFor as the tiebreaker (Use Case 11).
class Team {
  const Team({
    required this.id,
    required this.leagueId,
    required this.ownerId,
    required this.teamName,
    this.wins = 0,
    this.losses = 0,
    this.ties = 0,
    this.pointsFor = 0,
    this.createdAt,
  });

  final String id;
  final String leagueId;
  final String ownerId;
  final String teamName;
  final int wins;
  final int losses;
  final int ties;
  final double pointsFor;
  final DateTime? createdAt;

  static String idFor(String leagueId, String ownerId) => '${leagueId}_$ownerId';

  int get gamesPlayed => wins + losses + ties;

  /// Win percentage with ties counted as half a win; 0 before any games.
  double get winPct => gamesPlayed == 0 ? 0 : (wins + ties * 0.5) / gamesPlayed;

  String get record => ties > 0 ? '$wins-$losses-$ties' : '$wins-$losses';

  /// Data for a brand-new team document.
  static Map<String, dynamic> newTeamData({
    required String leagueId,
    required String ownerId,
    required String teamName,
  }) =>
      {
        'leagueId': leagueId,
        'ownerId': ownerId,
        'teamName': teamName.trim(),
        'wins': 0,
        'losses': 0,
        'ties': 0,
        'pointsFor': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory Team.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Team(
      id: doc.id,
      leagueId: data['leagueId'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      teamName: data['teamName'] as String? ?? 'Team',
      wins: (data['wins'] as num?)?.toInt() ?? 0,
      losses: (data['losses'] as num?)?.toInt() ?? 0,
      ties: (data['ties'] as num?)?.toInt() ?? 0,
      pointsFor: (data['pointsFor'] as num?)?.toDouble() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
