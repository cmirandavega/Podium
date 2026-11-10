import 'package:flutter_test/flutter_test.dart';
import 'package:podium/models/chat_message.dart';
import 'package:podium/services/chat_service.dart';

void main() {
  group('Use Case 7: message validation', () {
    test('empty and whitespace-only messages are rejected', () {
      expect(ChatService.validateBody(''), isNotNull);
      expect(ChatService.validateBody('   '), isNotNull);
    });

    test('a normal message passes', () {
      expect(ChatService.validateBody('Anyone want to trade a QB?'), isNull);
    });

    test('messages at the limit pass and over the limit fail', () {
      expect(ChatService.validateBody('a' * ChatMessage.maxLength), isNull);
      expect(ChatService.validateBody('a' * (ChatMessage.maxLength + 1)), isNotNull);
    });
  });
}
