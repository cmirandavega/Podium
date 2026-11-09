import 'package:cloud_firestore/cloud_firestore.dart';

/// A saved AI Trade and Team Analyzer result, stored at
/// tradeAnalyses/{analysisId} (Use Case 4).
///
/// Fields from the database table: userId, tradeId, analysisType,
/// fairnessRating, projectedDeltaProposer, projectedDeltaReceiver,
/// explanation, dataAsOf, createdAt. Added in Sprint 4: leagueId, cacheKey,
/// throughWeek, positionalImpact, verdict, aiAvailable.
class TradeAnalysis {
  const TradeAnalysis({
    required this.analysisType,
    required this.fairnessRating,
    required this.projectedDeltaProposer,
    required this.projectedDeltaReceiver,
    required this.explanation,
    required this.positionalImpact,
    required this.verdict,
    required this.aiAvailable,
    required this.throughWeek,
    required this.dataAsOf,
    this.id,
    this.tradeId,
    this.fromCache = false,
  });

  final String? id;
  final String? tradeId;
  final String analysisType; // "trade" or "roster"
  final int fairnessRating; // 1-10; 0 for roster reports
  final double projectedDeltaProposer; // weekly starter points change
  final double projectedDeltaReceiver;
  final String explanation;
  final String positionalImpact;
  final String verdict;
  final bool aiAvailable; // false when only the stats-based result is shown
  final int throughWeek;
  final DateTime dataAsOf;
  final bool fromCache;

  factory TradeAnalysis.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return TradeAnalysis(
      id: doc.id,
      tradeId: data['tradeId'] as String?,
      analysisType: data['analysisType'] as String? ?? 'trade',
      fairnessRating: (data['fairnessRating'] as num?)?.toInt() ?? 0,
      projectedDeltaProposer: (data['projectedDeltaProposer'] as num?)?.toDouble() ?? 0,
      projectedDeltaReceiver: (data['projectedDeltaReceiver'] as num?)?.toDouble() ?? 0,
      explanation: data['explanation'] as String? ?? '',
      positionalImpact: data['positionalImpact'] as String? ?? '',
      verdict: data['verdict'] as String? ?? '',
      aiAvailable: data['aiAvailable'] as bool? ?? true,
      throughWeek: (data['throughWeek'] as num?)?.toInt() ?? 0,
      dataAsOf: (data['dataAsOf'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fromCache: true,
    );
  }
}
