import 'package:cloud_firestore/cloud_firestore.dart';

/// One scoring week, written by the ingestion script to scoringPeriods/{id}.
class ScoringPeriod {
  const ScoringPeriod({
    required this.id,
    this.season,
    this.week,
    this.startDate,
  });

  final String id;
  final String? season;
  final int? week;
  final DateTime? startDate;

  String get label =>
      season != null && week != null ? 'Week $week, $season' : id;

  factory ScoringPeriod.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ScoringPeriod(
      id: doc.id,
      season: data['season']?.toString(),
      week: (data['week'] as num?)?.toInt(),
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
    );
  }
}
