import 'package:flutter_test/flutter_test.dart';
import 'package:podium/services/trade_analyzer_service.dart';
import 'package:podium/services/trade_service.dart';

import 'team_builder_test.dart' show testLeague;

void main() {
  group('Use Case 8: trade rules', () {
    final league = testLeague(rosterSize: 4);

    test('both sides need at least one player', () {
      expect(
        TradeService.validate(
          league: league,
          proposerRosterSize: 4,
          receiverRosterSize: 4,
          offeredCount: 0,
          requestedCount: 1,
        ),
        isNotNull,
      );
    });

    test('a 1-for-1 trade between full rosters is allowed', () {
      expect(
        TradeService.validate(
          league: league,
          proposerRosterSize: 4,
          receiverRosterSize: 4,
          offeredCount: 1,
          requestedCount: 1,
        ),
        isNull,
      );
    });

    test('a 1-for-2 trade that overfills the proposer is blocked', () {
      expect(
        TradeService.validate(
          league: league,
          proposerRosterSize: 4,
          receiverRosterSize: 4,
          offeredCount: 1,
          requestedCount: 2,
        ),
        contains('over the 4-player roster limit'),
      );
    });
  });

  group('Use Case 4: projections', () {
    test('starter points use the best players up to the starter count', () {
      expect(TradeAnalyzerService.projectedStarterPoints([5, 20, 10, 1], 2), 30);
      expect(TradeAnalyzerService.projectedStarterPoints([5], 3), 5);
    });

    test('statistics-only fairness is 10 for even trades and drops with the gap', () {
      expect(TradeAnalyzerService.statsFairness(3, 3), 10);
      expect(TradeAnalyzerService.statsFairness(6, -6), 4);
      expect(TradeAnalyzerService.statsFairness(40, -40), 1);
    });

    test('the cache key ignores player order', () {
      final a = TradeAnalyzerService.cacheKey(proposerTeamId: 'p', receiverTeamId: 'r', playerIds: ['b', 'a']);
      final b = TradeAnalyzerService.cacheKey(proposerTeamId: 'p', receiverTeamId: 'r', playerIds: ['a', 'b']);
      expect(a, b);
    });
  });
}
