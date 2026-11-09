import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:podium/models/ai_feature.dart';
import 'package:podium/services/ai/ai_exceptions.dart';
import 'package:podium/services/ai/ai_prompts.dart';
import 'package:podium/services/ai/ai_service.dart';
import 'package:podium/services/ai/ai_usage_service.dart';

void main() {
  group('AiUsageService keys', () {
    test('usageDate uses the UTC day, zero-padded', () {
      // 9:30 PM in New York on Nov 8 is already Nov 9 in UTC.
      final now = DateTime.utc(2026, 11, 9, 2, 30);
      expect(AiUsageService.usageDate(now), '2026-11-09');
      expect(AiUsageService.usageDate(DateTime.utc(2026, 3, 5)), '2026-03-05');
    });

    test('docId matches the aiUsage composite key', () {
      expect(
        AiUsageService.docId('abc123', '2026-11-09', AiFeature.assistantCoach),
        'abc123_2026-11-09_assistant_coach',
      );
      expect(
        AiUsageService.docId('abc123', '2026-11-09', AiFeature.tradeAnalyzer),
        'abc123_2026-11-09_trade_analyzer',
      );
    });

    test('nextReset is the next UTC midnight', () {
      final reset = AiUsageService.nextReset(DateTime.utc(2026, 12, 31, 23, 59));
      expect(reset.toUtc(), DateTime.utc(2027, 1, 1));
    });

    test('remaining never goes below zero or above the limit', () {
      const coach = AiFeature.assistantCoach;
      expect(AiUsageService.remainingFrom(0, coach), coach.dailyLimit);
      expect(AiUsageService.remainingFrom(coach.dailyLimit, coach), 0);
      expect(AiUsageService.remainingFrom(coach.dailyLimit + 5, coach), 0);
    });
  });

  group('AiPrompts', () {
    test('dataBlock includes dataAsOf and encodes DateTimes as UTC strings', () {
      final asOf = DateTime.utc(2026, 11, 9, 12);
      final block = AiPrompts.dataBlock(
        {'roster': ['QB Example'], 'lockTime': DateTime.utc(2026, 11, 10, 17)},
        dataAsOf: asOf,
      );
      expect(block.startsWith('DATA:\n'), isTrue);
      final json = jsonDecode(block.substring('DATA:\n'.length)) as Map<String, dynamic>;
      expect(json['dataAsOf'], '2026-11-09T12:00:00.000Z');
      expect(json['lockTime'], '2026-11-10T17:00:00.000Z');
      expect(json['roster'], ['QB Example']);
    });

    test('system puts the feature role before the shared rules', () {
      final system = AiPrompts.system('You are the Podium AI Coach.');
      expect(system.startsWith('You are the Podium AI Coach.'), isTrue);
      expect(system.contains(AiPrompts.groundingRules), isTrue);
    });
  });

  group('retry policy', () {
    test('backoff grows exponentially, stays random, and caps at 8 seconds', () {
      final random = Random(1);
      for (var retry = 0; retry < 6; retry++) {
        final cap = min(8000, 1000 * (1 << retry));
        for (var i = 0; i < 50; i++) {
          final ms = AiService.backoff(retry, random).inMilliseconds;
          expect(ms, inInclusiveRange(0, cap));
        }
      }
    });

    test('errors are sorted into retry, switch model, or stop', () {
      expect(AiService.classify(TimeoutException('slow')), AiFailure.switchModel);
      expect(AiService.classify(Exception('Server error 500')), AiFailure.transient);
      expect(AiService.classify(Exception('503 high demand, try again later')), AiFailure.transient);
      expect(AiService.classify(Exception('429 RESOURCE_EXHAUSTED')), AiFailure.transient);
      expect(
        AiService.classify(Exception('models/gemini-2.5-flash is no longer available to new users')),
        AiFailure.switchModel,
      );
      expect(AiService.classify(Exception('Firebase App Check token is invalid.')), AiFailure.fatal);
      expect(AiService.classify(Exception('PERMISSION_DENIED')), AiFailure.fatal);
    });
  });

  test('limit message names the feature and the limit', () {
    final error = AiLimitReachedException(
      feature: AiFeature.tradeAnalyzer,
      resetsAt: DateTime(2026, 11, 9, 19, 0),
    );
    expect(error.toString(), contains('10 AI Trade Analyzer requests'));
    expect(error.toString(), contains('7:00 PM'));
  });
}
