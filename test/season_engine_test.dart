import 'package:flutter_test/flutter_test.dart';
import 'package:podium/models/roster_slot.dart';
import 'package:podium/models/team.dart';
import 'package:podium/services/season_engine.dart';

RosterSlot slot(String id, {required bool starter}) => RosterSlot(
      id: 'L_$id',
      leagueId: 'L',
      playerId: id,
      teamId: 'L_u',
      slotPosition: 'WR',
      isStarter: starter,
      playerName: id,
      sport: 'NFL',
      realTeam: 'XYZ',
    );

Team team(String id, {int w = 0, int l = 0, int t = 0, double pf = 0}) =>
    Team(id: id, leagueId: 'L', ownerId: id, teamName: id, wins: w, losses: l, ties: t, pointsFor: pf);

void main() {
  group('Use Case 15: schedule', () {
    test('four teams play everyone once in three weeks', () {
      final schedule = SeasonEngine.roundRobin(['A', 'B', 'C', 'D'], 3);
      expect(schedule.length, 3);
      final pairs = <String>{};
      for (final week in schedule) {
        expect(week.length, 2);
        final playing = <String>{};
        for (final g in week) {
          expect(g.away, isNotNull);
          playing..add(g.home)..add(g.away!);
          pairs.add(([g.home, g.away!]..sort()).join());
        }
        expect(playing.length, 4, reason: 'every team plays once per week');
      }
      expect(pairs, {'AB', 'AC', 'AD', 'BC', 'BD', 'CD'});
    });

    test('an odd number of teams gives one bye per week', () {
      final schedule = SeasonEngine.roundRobin(['A', 'B', 'C'], 3);
      final byes = <String>{};
      for (final week in schedule) {
        final bye = week.where((g) => g.away == null).toList();
        expect(bye.length, 1);
        byes.add(bye.single.home);
      }
      expect(byes, {'A', 'B', 'C'}, reason: 'each team gets one bye');
    });
  });

  group('scoring a week', () {
    test('only starters score; optimal uses the best players', () {
      final roster = [
        slot('s1', starter: true),
        slot('s2', starter: true),
        slot('b1', starter: false),
      ];
      final score = SeasonEngine.scoreTeam(
        roster: roster,
        points: {'s1': 10, 's2': 5, 'b1': 20},
        starterCount: 2,
      );
      expect(score.points, 15);
      expect(score.optimalPoints, 30);
      expect(score.topScorer?.playerId, 's1');
      expect(score.bestBench?.playerId, 'b1');
      expect(score.bestBenchPoints, 20);
    });

    test('ties have no winner in the regular season; home wins playoff ties', () {
      expect(SeasonEngine.winner(home: 'A', away: 'B', homeScore: 90, awayScore: 90), isNull);
      expect(SeasonEngine.winner(home: 'A', away: 'B', homeScore: 90, awayScore: 90, playoff: true), 'A');
      expect(SeasonEngine.winner(home: 'A', away: 'B', homeScore: 80, awayScore: 95), 'B');
    });
  });

  group('Use Case 11: standings', () {
    test('record first, then points', () {
      final order = SeasonEngine.standings([
        team('low', w: 1, l: 1, pf: 300),
        team('best', w: 2, l: 0, pf: 150),
        team('high', w: 1, l: 1, pf: 310),
      ]);
      expect(order.map((t) => t.id), ['best', 'high', 'low']);
    });

    test('playoff seeding: 1 v 4 and 2 v 3', () {
      final standings = [team('1'), team('2'), team('3'), team('4'), team('5')];
      final round = SeasonEngine.seedPlayoffs(standings, 4);
      expect(round.map((p) => '${p.home}v${p.away}'), ['1v4', '2v3']);
      expect(SeasonEngine.seedPlayoffs(standings, 2).single.home, '1');
      expect(SeasonEngine.playoffRounds(4), 2);
    });
  });
}
