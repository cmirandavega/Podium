import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/ai_feature.dart';
import '../models/league.dart';
import '../models/roster_slot.dart';
import '../models/trade_analysis.dart';
import 'ai/ai_exceptions.dart';
import 'ai/ai_prompts.dart';
import 'ai/ai_service.dart';
import 'player_history_service.dart';
import 'team_service.dart';

/// Use Case 4: the AI Trade and Team Analyzer.
///
/// Podium computes the point projections itself from weekly stats, then
/// asks the AI only for the fairness rating and the written explanation. If
/// the AI is unavailable, the user still gets the statistics-only result.
class TradeAnalyzerService {
  TradeAnalyzerService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    AiService? ai,
    TeamService? teams,
    PlayerHistoryService? history,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _ai = ai ?? AiService(),
        _teams = teams ?? TeamService(),
        _history = history ?? PlayerHistoryService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final AiService _ai;
  final TeamService _teams;
  final PlayerHistoryService _history;

  static const tradeRole = '''
You are the Podium AI Trade Analyzer. You judge whether a fantasy trade is fair and how it changes each roster in a league that can mix several sports.
- The projected weekly point changes in DATA were computed by Podium from real stats. Use them as given; do not recalculate them.
- fairnessRating: 10 means perfectly even, 1 means extremely one-sided.
- verdict: one of "even", "favors proposer", "favors receiver".
- positionalImpact: one or two sentences on how each roster's positions and sports change.
- explanation: under 120 words, citing the players' average points from DATA.''';

  static const rosterRole = '''
You are the Podium AI Team Analyzer. You review one fantasy roster in a league that can mix several sports.
- positionalImpact: the roster's strongest and weakest positions, and any of the league's sports with thin coverage.
- explanation: under 120 words, citing players' average points from DATA, with one concrete suggestion.
- fairnessRating must be 0 and verdict must be "roster".''';

  static final _schema = Schema.object(properties: {
    'fairnessRating': Schema.integer(),
    'verdict': Schema.string(),
    'positionalImpact': Schema.string(),
    'explanation': Schema.string(),
  });

  /// Weekly points the best possible lineup would average, from each
  /// player's average. This is how a trade's value to a roster is measured.
  static double projectedStarterPoints(List<double> playerAverages, int starterCount) {
    final sorted = [...playerAverages]..sort((a, b) => b.compareTo(a));
    return sorted.take(starterCount).fold<double>(0, (total, v) => total + v);
  }

  /// A 1-10 rating from how far apart the two sides' gains are, used when
  /// the AI is unavailable.
  static int statsFairness(double deltaProposer, double deltaReceiver) {
    final gap = (deltaProposer - deltaReceiver).abs();
    return (10 - gap / 2).round().clamp(1, 10).toInt();
  }

  static String cacheKey({
    required String proposerTeamId,
    required String receiverTeamId,
    required List<String> playerIds,
  }) =>
      '$proposerTeamId|$receiverTeamId|${([...playerIds]..sort()).join(',')}';

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be logged in.');
    return user.uid;
  }

  /// Analyzes a trade where [offered] goes from the proposer to the receiver
  /// and [requested] goes the other way. Shows a saved analysis instead when
  /// the same trade was analyzed this week (Use Case 4 alternate path).
  /// Throws [AiLimitReachedException] when the daily limit is used up.
  Future<TradeAnalysis> analyzeTrade({
    required League league,
    required String proposerTeamId,
    required String receiverTeamId,
    required List<RosterSlot> offered,
    required List<RosterSlot> requested,
    String? tradeId,
  }) async {
    if (offered.isEmpty || requested.isEmpty) {
      throw StateError('Pick at least one player on each side of the trade.');
    }
    final throughWeek = PlayerHistoryService.visibleThroughWeek(league);
    final key = cacheKey(
      proposerTeamId: proposerTeamId,
      receiverTeamId: receiverTeamId,
      playerIds: [for (final s in [...offered, ...requested]) s.playerId],
    );
    final cached = await _cached(key, throughWeek);
    if (cached != null) return cached;

    final proposerRoster = await _teams.getRoster(proposerTeamId);
    final receiverRoster = await _teams.getRoster(receiverTeamId);
    final weekly = await _history.weeklyPoints(
      playerIds: [for (final s in [...proposerRoster, ...receiverRoster]) s.playerId],
      season: league.season,
      throughWeek: throughWeek,
    );
    double avg(RosterSlot s) => PlayerHistoryService.average(weekly[s.playerId] ?? const {});

    final offeredIds = {for (final s in offered) s.playerId};
    final requestedIds = {for (final s in requested) s.playerId};
    final proposerAfter = [
      ...proposerRoster.where((s) => !offeredIds.contains(s.playerId)),
      ...requested,
    ];
    final receiverAfter = [
      ...receiverRoster.where((s) => !requestedIds.contains(s.playerId)),
      ...offered,
    ];
    double project(List<RosterSlot> roster) =>
        projectedStarterPoints([for (final s in roster) avg(s)], league.starterCount);

    final deltaProposer = _round(project(proposerAfter) - project(proposerRoster));
    final deltaReceiver = _round(project(receiverAfter) - project(receiverRoster));

    Map<String, Object?> player(RosterSlot s) => {
          'name': s.playerName,
          'position': s.slotPosition,
          'sport': s.sport,
          'realTeam': s.realTeam,
          'averagePoints': _round(avg(s)),
          'weeksPlayed': (weekly[s.playerId] ?? const {}).length,
        };

    final data = AiPrompts.dataBlock({
      'league': {'sports': league.sports, 'starterCount': league.starterCount, 'statsThroughWeek': throughWeek},
      'proposerSends': [for (final s in offered) player(s)],
      'receiverSends': [for (final s in requested) player(s)],
      'proposerRosterBefore': [for (final s in proposerRoster) player(s)],
      'receiverRosterBefore': [for (final s in receiverRoster) player(s)],
      'projectedWeeklyStarterPointsChange': {'proposer': deltaProposer, 'receiver': deltaReceiver},
    }, dataAsOf: DateTime.now());

    var result = TradeAnalysis(
      tradeId: tradeId,
      analysisType: 'trade',
      fairnessRating: statsFairness(deltaProposer, deltaReceiver),
      projectedDeltaProposer: deltaProposer,
      projectedDeltaReceiver: deltaReceiver,
      explanation: 'The AI summary is temporarily unavailable. Based on weekly averages through week '
          '$throughWeek, the proposer\'s best lineup changes by ${_signed(deltaProposer)} points per week '
          'and the receiver\'s by ${_signed(deltaReceiver)}.',
      positionalImpact: '',
      verdict: deltaProposer > deltaReceiver + 2
          ? 'favors proposer'
          : (deltaReceiver > deltaProposer + 2 ? 'favors receiver' : 'even'),
      aiAvailable: false,
      throughWeek: throughWeek,
      dataAsOf: DateTime.now(),
    );

    try {
      final json = await _ai.generateJson(
        feature: AiFeature.tradeAnalyzer,
        systemInstruction: AiPrompts.system(tradeRole),
        prompt: '$data\n\nAnalyze this trade.',
        schema: _schema,
        requiredKeys: const ['fairnessRating', 'verdict', 'positionalImpact', 'explanation'],
      );
      result = TradeAnalysis(
        tradeId: tradeId,
        analysisType: 'trade',
        fairnessRating: ((json['fairnessRating'] as num?)?.toInt() ?? result.fairnessRating).clamp(1, 10).toInt(),
        projectedDeltaProposer: deltaProposer,
        projectedDeltaReceiver: deltaReceiver,
        explanation: json['explanation'] as String? ?? result.explanation,
        positionalImpact: json['positionalImpact'] as String? ?? '',
        verdict: json['verdict'] as String? ?? result.verdict,
        aiAvailable: true,
        throughWeek: throughWeek,
        dataAsOf: DateTime.now(),
      );
    } on AiLimitReachedException {
      rethrow;
    } on Exception {
      // Keep the statistics-only result (Use Case 4 exception path).
    }

    await _save(league, result, key);
    return result;
  }

  /// A report on the user's own roster with no trade.
  Future<TradeAnalysis> analyzeRoster({required League league}) async {
    final teamId = '${league.id}_$_uid';
    final throughWeek = PlayerHistoryService.visibleThroughWeek(league);
    final key = 'roster|$teamId';
    final cached = await _cached(key, throughWeek);
    if (cached != null) return cached;

    final roster = await _teams.getRoster(teamId);
    if (roster.isEmpty) throw StateError('Add players to your roster first.');
    final weekly = await _history.weeklyPoints(
      playerIds: [for (final s in roster) s.playerId],
      season: league.season,
      throughWeek: throughWeek,
    );
    final data = AiPrompts.dataBlock({
      'league': {'sports': league.sports, 'starterCount': league.starterCount, 'statsThroughWeek': throughWeek},
      'roster': [
        for (final s in roster)
          {
            'name': s.playerName,
            'position': s.slotPosition,
            'sport': s.sport,
            'starter': s.isStarter,
            'averagePoints': _round(PlayerHistoryService.average(weekly[s.playerId] ?? const {})),
          },
      ],
    }, dataAsOf: DateTime.now());

    final json = await _ai.generateJson(
      feature: AiFeature.tradeAnalyzer,
      systemInstruction: AiPrompts.system(rosterRole),
      prompt: '$data\n\nReview this roster.',
      schema: _schema,
      requiredKeys: const ['positionalImpact', 'explanation'],
    );
    final result = TradeAnalysis(
      analysisType: 'roster',
      fairnessRating: 0,
      projectedDeltaProposer: 0,
      projectedDeltaReceiver: 0,
      explanation: json['explanation'] as String? ?? '',
      positionalImpact: json['positionalImpact'] as String? ?? '',
      verdict: 'roster',
      aiAvailable: true,
      throughWeek: throughWeek,
      dataAsOf: DateTime.now(),
    );
    await _save(league, result, key);
    return result;
  }

  Future<TradeAnalysis?> _cached(String key, int throughWeek) async {
    final query = await _db
        .collection('tradeAnalyses')
        .where('userId', isEqualTo: _uid)
        .where('cacheKey', isEqualTo: key)
        .get();
    for (final doc in query.docs) {
      final a = TradeAnalysis.fromFirestore(doc);
      if (a.throughWeek == throughWeek && a.aiAvailable) return a;
    }
    return null;
  }

  Future<void> _save(League league, TradeAnalysis a, String key) {
    return _db.collection('tradeAnalyses').add({
      'userId': _uid,
      'leagueId': league.id,
      'tradeId': a.tradeId,
      'analysisType': a.analysisType,
      'fairnessRating': a.fairnessRating,
      'projectedDeltaProposer': a.projectedDeltaProposer,
      'projectedDeltaReceiver': a.projectedDeltaReceiver,
      'explanation': a.explanation,
      'positionalImpact': a.positionalImpact,
      'verdict': a.verdict,
      'aiAvailable': a.aiAvailable,
      'cacheKey': key,
      'throughWeek': a.throughWeek,
      'dataAsOf': Timestamp.fromDate(a.dataAsOf),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static double _round(double v) => (v * 10).roundToDouble() / 10;
  static String _signed(double v) => v >= 0 ? '+${v.toStringAsFixed(1)}' : v.toStringAsFixed(1);
}
