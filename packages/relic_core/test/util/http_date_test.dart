import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http_parser/http_parser.dart' as parser;
import 'package:relic_core/adapter.dart';
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  test('Given the current time, when the date is read, '
      'then it is the current time to the second.', () {
    final before = DateTime.now().toUtc();

    final date = parser.parseHttpDate(httpDate());

    expect(date.difference(before).inSeconds.abs(), lessThanOrEqualTo(1));
  });

  test('Given a substituted clock, '
      'when it advances past the second, '
      'then the date follows that clock', () {
    var now = DateTime.utc(2026, 1, 1);
    withClock(Clock(() => now), () {
      expect(httpDate(), 'Thu, 01 Jan 2026 00:00:00 GMT');
      now = now.add(const Duration(seconds: 2));
      expect(httpDate(), 'Thu, 01 Jan 2026 00:00:02 GMT');
    });
  });

  test('Given the current date value, when its line is asked for, '
      'then it is the date field, and null for any other string', () {
    final value = httpDate();

    expect(latin1.decode(httpDateLineOf(value)!), 'date: $value\r\n');
    expect(httpDateLineOf(String.fromCharCodes(value.codeUnits)), isNull);
  });
}
