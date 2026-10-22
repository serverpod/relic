import 'dart:async';

import 'package:relic_core/relic_core.dart';
import 'package:relic_io/relic_io.dart';
import 'package:test/test.dart';
import 'package:test_utils/test_utils.dart';

/// Makes a simple GET request to [handler] and returns the result.
Future<Response> makeRequest(
  Handler handler,
  String path, {
  Headers? headers,
  Method method = Method.get,
}) async {
  final request = _fromPath(path, headers, method: method);
  final response = await handler(request);
  if (response is! Response) throw ArgumentError(response);
  return response;
}

Request _fromPath(String path, Headers? headers, {required Method method}) =>
    testRequest(
      Uri.parse('http://localhost$path'),
      method: method,
      headers: headers,
    );

Matcher atSameTimeToSecond(DateTime value) =>
    _SecondResolutionDateTimeMatcher(value);

class _SecondResolutionDateTimeMatcher extends Matcher {
  final DateTime _target;

  _SecondResolutionDateTimeMatcher(DateTime target)
    : _target = target.toSecondResolution;

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is! DateTime) return false;

    return _datesEqualToSecond(_target, item);
  }

  @override
  Description describe(Description description) => description.add(
    'Must be at the same moment as $_target with resolution '
    'to the second.',
  );
}

bool _datesEqualToSecond(DateTime d1, DateTime d2) =>
    d1.toSecondResolution.isAtSameMomentAs(d2.toSecondResolution);
