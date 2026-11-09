import 'package:flutter_test/flutter_test.dart';
import 'package:podium/models/matchup.dart';
import 'package:podium/models/wager.dart';
import 'package:podium/services/wager_service.dart';

import 'team_builder_test.dart' show testLeague;

Matchup game({String? winner, String status = 'scheduled', int week = 1, String? away = 'B'}) => Matchup(
      id: 'L1_w${week}_0',
      leagueId: 'L1',
      week: week,
      homeTeamId: 'A',
      awayTeamId: away,
      homeScore: 0,
      awayScore: 0,
      status: status,
      type: 'regular',
      round: 0,
      winnerTeamId: winner,
    );

Wager wager({String status = 'matched', String pick = 'A', int amount = 100}) => Wager(
      id: 'w1',
      leagueId: 'L1',
      matchupId: 'L1_w1_0',
      week: 1,
      creatorId: 'alice',
      creatorName: 'alice',
      pickTeamId: pick,
      amount: amount,
      status: status,
      opponentId: status == 'open' ? null : 'bob',
    );

void main() {
  group('Use Case 13: placing wagers', () {
    final league = testLeague(phase: 'regular');

    test('a valid wager passes', () {
      expect(WagerService.validate(league: league, matchup: game(), amount: 50, balance: 1000), isNull);
    });

    test('wagering more than your balance fails', () {
      expect(WagerService.validate(league: league, matchup: game(), amount: 2000, balance: 1000), contains('only have'));
    });

    test('below the minimum fails', () {
      expect(WagerService.validate(league: league, matchup: game(), amount: 5, balance: 1000), isNotNull);
    });

    test('wagers close when lineups lock or for other weeks', () {
      expect(
        WagerService.validate(league: testLeague(phase: 'regular', lineupLocked: true), matchup: game(), amount: 50, balance: 1000),
        contains('lock'),
      );
      expect(WagerService.validate(league: league, matchup: game(week: 2), amount: 50, balance: 1000), isNotNull);
      expect(WagerService.validate(league: league, matchup: game(away: null), amount: 50, balance: 1000), isNotNull);
    });

    test('no wagers before the season starts', () {
      expect(WagerService.validate(league: testLeague(), matchup: game(), amount: 50, balance: 1000), isNotNull);
    });
  });

  group('Use Case 13: settlement', () {
    test('the winner collects both stakes', () {
      final creatorWins = WagerService.outcome(wager(pick: 'A'), game(winner: 'A', status: 'final'));
      expect(creatorWins.status, 'won');
      expect(creatorWins.winnerId, 'alice');
      expect(creatorWins.payouts, {'alice': 200});

      final opponentWins = WagerService.outcome(wager(pick: 'A'), game(winner: 'B', status: 'final'));
      expect(opponentWins.payouts, {'bob': 200});
    });

    test('a tie returns both stakes', () {
      final tie = WagerService.outcome(wager(), game(status: 'final'));
      expect(tie.status, 'push');
      expect(tie.payouts, {'alice': 100, 'bob': 100});
    });

    test('an offer nobody took is refunded', () {
      final unmatched = WagerService.outcome(wager(status: 'open'), game(winner: 'A', status: 'final'));
      expect(unmatched.status, 'void');
      expect(unmatched.payouts, {'alice': 100});
    });
  });
}
