import 'package:cloud_firestore/cloud_firestore.dart';

/// One player's stats for one game, stored at playerStats/{SPORT}_{playerId}_{gameId}.
class PlayerStat {
  const PlayerStat({
    required this.id,
    required this.playerId,
    required this.sport,
    required this.fullName,
    required this.realTeam,
    required this.position,
    required this.fantasyPoints,
    required this.rawStats,
  });

  final String id;
  final String playerId;
  final String sport;
  final String fullName;
  final String realTeam;
  final String? position;
  final double fantasyPoints;
  final Map<String, num> rawStats;

  factory PlayerStat.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final raw = data['rawStats'];
    return PlayerStat(
      id: doc.id,
      playerId: data['playerId'] as String? ?? doc.id,
      sport: data['sport'] as String? ?? '',
      fullName: data['fullName'] as String? ?? (data['playerId'] as String? ?? doc.id),
      realTeam: data['realTeam'] as String? ?? '',
      position: data['position'] as String?,
      fantasyPoints: (data['fantasyPoints'] as num?)?.toDouble() ?? 0,
      rawStats: raw is Map
          ? raw.map((key, value) => MapEntry(key.toString(), value is num ? value : 0))
          : const <String, num>{},
    );
  }
}

/// A player's combined line for a whole scoring week (sums every game that week).
class PlayerWeek {
  PlayerWeek({
    required this.playerId,
    required this.sport,
    required this.fullName,
    required this.realTeam,
    required this.position,
  });

  final String playerId;
  final String sport;
  final String fullName;
  final String realTeam;
  final String? position;
  double points = 0;
  int games = 0;
  final Map<String, num> stats = {};

  void add(PlayerStat line) {
    points += line.fantasyPoints;
    games += 1;
    for (final entry in line.rawStats.entries) {
      stats[entry.key] = (stats[entry.key] ?? 0) + entry.value;
    }
  }
}
