import 'dart:convert';

import 'package:http_parser/http_parser.dart' as parser;
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  test('Given the current time, when the date is read, '
      'then it is the current time to the second.', () {
    final before = DateTime.now().toUtc();

    final date = parser.parseHttpDate(httpDate());

    expect(date.difference(before).inSeconds.abs(), lessThanOrEqualTo(1));
  });

  test('Given the current time, when the date line is read, '
      'then it is the date field with the same value.', () {
    final value = httpDate();
    final line = latin1.decode(httpDateLine());

    expect(line, 'date: $value\r\n');
  });
}
