import 'package:flutter_test/flutter_test.dart';
import 'package:podium/models/league.dart';
import 'package:podium/models/roster_slot.dart';
import 'package:podium/services/team_service.dart';

League testLeague({
  List<String> sports = const ['NFL'],
  int rosterSize = 4,
  int starterCount = 2,
  bool lineupLocked = false,
  String phase = 'preseason',
}) =>
    League(
      id: 'L1',
      name: 'Test',
      commissionerId: 'c',
      format: sports.length == 1 ? 'single-sport' : 'multi-sport',
      sports: sports,
      season: '2024',
      maxTeams: 4,
      rosterSize: rosterSize,
      starterCount: starterCount,
      tradeReviewHours: 0,
      status: 'active',
      inviteCode: 'ABCDEF',
      memberIds: const ['c'],
      currentWeek: 1,
      regularSeasonWeeks: 3,
      playoffTeams: 2,
      lineupLocked: lineupLocked,
      phase: phase,
    );

RosterSlot slot(String id, {bool starter = false, String sport = 'NFL', String pos = 'QB'}) => RosterSlot(
      id: 'L1_$id',
      leagueId: 'L1',
      playerId: id,
      teamId: 'L1_u',
      slotPosition: pos,
      isStarter: starter,
      playerName: id,
      sport: sport,
      realTeam: 'XYZ',
    );

void main() {
  group('Use Case 3: adding players', () {
    test('a valid add passes', () {
      expect(
        TeamService.validateAdd(league: testLeague(), playerSport: 'NFL', rosterCount: 0),
        isNull,
      );
    });

    test('a player from a sport outside the league is ineligible', () {
      expect(
        TeamService.validateAdd(league: testLeague(), playerSport: 'NBA', rosterCount: 0),
        contains('aren\'t eligible'),
      );
    });

    test('a full roster is rejected', () {
      expect(
        TeamService.validateAdd(league: testLeague(rosterSize: 4), playerSport: 'NFL', rosterCount: 4),
        contains('roster is full'),
      );
    });

    test('a locked lineup is rejected', () {
      expect(
        TeamService.validateAdd(league: testLeague(lineupLocked: true), playerSport: 'NFL', rosterCount: 0),
        contains('locked'),
      );
    });
  });

  group('Use Case 3: starters', () {
    test('starting a player past the starter limit is rejected', () {
      expect(
        TeamService.validateStarterChange(league: testLeague(starterCount: 2), makeStarter: true, starterCount: 2),
        isNotNull,
      );
    });

    test('benching is always allowed when unlocked', () {
      expect(
        TeamService.validateStarterChange(league: testLeague(), makeStarter: false, starterCount: 2),
        isNull,
      );
    });
  });

  test('rosters list starters first, then by sport and position', () {
    final sorted = TeamService.sortRoster([
      slot('benchQB'),
      slot('startWR', starter: true, pos: 'WR'),
      slot('startQB', starter: true),
    ]);
    expect(sorted.map((s) => s.playerId), ['startQB', 'startWR', 'benchQB']);
  });

  test('roster slot label includes position, team, and sport', () {
    expect(slot('Josh Allen').label, 'Josh Allen (QB, XYZ, NFL)');
  });
}
