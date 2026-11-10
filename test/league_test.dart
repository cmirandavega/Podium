import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:podium/models/sport.dart';
import 'package:podium/models/team.dart';
import 'package:podium/services/league_service.dart';

void main() {
  const available = [
    Sport(name: 'NFL', apiCode: 'american-football', isActive: true),
    Sport(name: 'NBA', apiCode: 'basketball', isActive: true),
    Sport(name: 'MLB', apiCode: 'baseball', isActive: false),
  ];

  group('Use Case 2: sport selection', () {
    test('no sport selected is rejected', () {
      expect(
        LeagueService.validateSports(format: 'multi-sport', selected: [], available: available),
        'Select at least one sport.',
      );
    });

    test('an unavailable sport is rejected', () {
      final error = LeagueService.validateSports(
        format: 'single-sport',
        selected: ['MLB'],
        available: available,
      );
      expect(error, contains('MLB is not available'));
    });

    test('single-sport needs exactly one sport', () {
      expect(
        LeagueService.validateSports(format: 'single-sport', selected: ['NFL'], available: available),
        isNull,
      );
      expect(
        LeagueService.validateSports(
          format: 'single-sport',
          selected: ['NFL', 'NBA'],
          available: available,
        ),
        isNotNull,
      );
    });

    test('multi-sport needs two or more sports', () {
      expect(
        LeagueService.validateSports(format: 'multi-sport', selected: ['NFL'], available: available),
        isNotNull,
      );
      expect(
        LeagueService.validateSports(
          format: 'multi-sport',
          selected: ['NFL', 'NBA'],
          available: available,
        ),
        isNull,
      );
    });
  });

  test('invite codes are 6 characters with no look-alike letters', () {
    final random = Random(42);
    for (var i = 0; i < 200; i++) {
      final code = LeagueService.generateInviteCode(random);
      expect(code.length, 6);
      expect(RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(code), isTrue, reason: code);
    }
  });

  group('Team record', () {
    test('team IDs combine league and owner', () {
      expect(Team.idFor('league1', 'user1'), 'league1_user1');
    });

    test('win percentage counts ties as half a win', () {
      const team = Team(id: 't', leagueId: 'l', ownerId: 'o', teamName: 'T', wins: 2, losses: 1, ties: 1);
      expect(team.winPct, closeTo(0.625, 1e-9));
      expect(team.record, '2-1-1');
      const fresh = Team(id: 't', leagueId: 'l', ownerId: 'o', teamName: 'T');
      expect(fresh.winPct, 0);
      expect(fresh.record, '0-0');
    });
  });
}
