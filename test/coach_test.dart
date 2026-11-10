import 'package:flutter_test/flutter_test.dart';
import 'package:podium/models/roster_slot.dart';
import 'package:podium/services/coach_service.dart';
import 'package:podium/services/player_history_service.dart';

RosterSlot slot(String id, {required bool starter}) => RosterSlot(
      id: 'L1_$id',
      leagueId: 'L1',
      playerId: id,
      teamId: 'L1_u',
      slotPosition: 'WR',
      isStarter: starter,
      playerName: id,
      sport: 'NFL',
      realTeam: 'XYZ',
    );

void main() {
  group('Use Case 12: Coach replies', () {
    test('a swap line is parsed and removed from the shown text', () {
      final parsed = CoachService.parseReply(
        'Start Smith over Jones; he averaged 18.2 points.\n[[SWAP start=NFL_1 bench=NFL_2]]',
      );
      expect(parsed.text, 'Start Smith over Jones; he averaged 18.2 points.');
      expect(parsed.swap?.startPlayerId, 'NFL_1');
      expect(parsed.swap?.benchPlayerId, 'NFL_2');
    });

    test('a reply without a swap has no suggestion', () {
      final parsed = CoachService.parseReply('Your lineup already looks optimal.');
      expect(parsed.swap, isNull);
      expect(parsed.text, 'Your lineup already looks optimal.');
    });

    test('a swap is kept only if it matches the roster', () {
      final roster = [slot('NFL_1', starter: false), slot('NFL_2', starter: true)];
      const good = (startPlayerId: 'NFL_1', benchPlayerId: 'NFL_2');
      const backwards = (startPlayerId: 'NFL_2', benchPlayerId: 'NFL_1');
      const unknown = (startPlayerId: 'NFL_9', benchPlayerId: 'NFL_2');
      expect(CoachService.validSwap(good, roster), good);
      expect(CoachService.validSwap(backwards, roster), isNull);
      expect(CoachService.validSwap(unknown, roster), isNull);
      expect(CoachService.validSwap(null, roster), isNull);
    });
  });

  group('player history', () {
    test('period IDs parse into season and week', () {
      final parsed = PlayerHistoryService.parsePeriodId('period_2024_w12');
      expect(parsed?.season, '2024');
      expect(parsed?.week, 12);
      expect(PlayerHistoryService.parsePeriodId('period_2026_w06')?.week, 6);
      expect(PlayerHistoryService.parsePeriodId('demo'), isNull);
    });

    test('average of weekly points', () {
      expect(PlayerHistoryService.average({1: 10, 2: 20}), 15);
      expect(PlayerHistoryService.average({}), 0);
    });
  });
}
