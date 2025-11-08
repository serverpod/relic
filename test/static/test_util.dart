import 'dart:async';

import 'package:relic/relic.dart';
import 'package:relic/src/context/result.dart';
import 'package:relic/src/io/static/extension/datetime_extension.dart';
import 'package:test/test.dart';

/// Makes a simple GET request to [handler] and returns the result.
Future<Response> makeRequest(
  final Handler handler,
  final String path, {
  final Headers? headers,
  final Method method = Method.get,
}) async {
  final request = _fromPath(path, headers, method: method);
  final response = await handler(request);
  if (response is! Response) throw ArgumentError(response);
  return response;
}

Request _fromPath(
  final String path,
  final Headers? headers, {
  required final Method method,
}) => RequestInternal.create(
  method,
  Uri.parse('http://localhost$path'),
  Object(),
  headers: headers,
);

Matcher atSameTimeToSecond(final DateTime value) =>
    _SecondResolutionDateTimeMatcher(value);

class _SecondResolutionDateTimeMatcher extends Matcher {
  final DateTime _target;

  _SecondResolutionDateTimeMatcher(final DateTime target)
    : _target = target.toSecondResolution;

  @override
  bool matches(final dynamic item, final Map<dynamic, dynamic> matchState) {
    if (item is! DateTime) return false;

    return _datesEqualToSecond(_target, item);
  }

  @override
  Description describe(final Description description) => description.add(
    'Must be at the same moment as $_target with resolution '
    'to the second.',
  );
}

bool _datesEqualToSecond(final DateTime d1, final DateTime d2) =>
    d1.toSecondResolution.isAtSameMomentAs(d2.toSecondResolution);
