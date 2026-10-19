import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/player_stat.dart';
import '../models/scoring_period.dart';

/// Use Case 10: reads the scores the ingestion script writes to Firestore.
/// The app only reads; the sports API is never called from the device.
class ScoringService {
  ScoringService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Scoring weeks that have ingested data, newest first.
  Stream<List<ScoringPeriod>> watchPeriods() {
    return _db.collection('scoringPeriods').snapshots().map((query) {
      final periods = query.docs
          .map(ScoringPeriod.fromFirestore)
          .where((p) => p.week != null) // skips older placeholder documents
          .toList();
      periods.sort((a, b) {
        final bySeason = (b.season ?? '').compareTo(a.season ?? '');
        return bySeason != 0 ? bySeason : (b.week ?? 0).compareTo(a.week ?? 0);
      });
      return periods;
    });
  }

  /// Live, ranked fantasy totals for one week. Updates on screen whenever the
  /// ingestion script writes new stats. Sorted on the device, so no composite index is needed.
  Stream<List<PlayerWeek>> watchWeek(String periodId) {
    return _db
        .collection('playerStats')
        .where('scoringPeriodId', isEqualTo: periodId)
        .snapshots()
        .map((query) {
      final byPlayer = <String, PlayerWeek>{};
      for (final doc in query.docs) {
        final line = PlayerStat.fromFirestore(doc);
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
      final players = byPlayer.values.toList()
        ..sort((a, b) => b.points.compareTo(a.points));
      return players;
    });
  }
}
