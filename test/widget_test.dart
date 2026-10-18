// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:podium/utils/validators.dart';

void main() {
  test('Username validator', () {
    expect(Validators.username('chris_23'), isNull);
    expect(Validators.username('ab'), isNotNull);
    expect(Validators.username('bad name!'), isNotNull);
  });

  test('Email validator', () {
    expect(Validators.email('test@gmail.com'), isNull);
    expect(Validators.email('not-an-email'), isNotNull);
  });

  test('New password requires 8 characters', () {
    expect(Validators.newPassword('12345678'), isNull);
    expect(Validators.newPassword('1234'), isNotNull);
  });
}