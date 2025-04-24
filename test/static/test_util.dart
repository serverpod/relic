import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:relic/relic.dart';
import 'package:relic/src/adaptor/context.dart';
import 'package:relic/src/io/static/extension/datetime_extension.dart';
import 'package:test/test.dart';

final p.Context _ctx = p.url;

/// Makes a simple GET request to [handler] and returns the result.
Future<Response> makeRequest(
  final Handler handler,
  final String path, {
  final String? handlerPath,
  final Headers? headers,
  final RequestMethod method = RequestMethod.get,
}) async {
  final rootedHandler = _rootHandler(handlerPath, handler);
  final request = _fromPath(path, headers, method: method);
  final ctx = await rootedHandler(request.toContext());
  if (ctx is! ResponseContext) throw ArgumentError(ctx);
  return ctx.response;
}

Request _fromPath(
  final String path,
  final Headers? headers, {
  required final RequestMethod method,
}) =>
    Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: headers,
    );

Handler _rootHandler(final String? path, final Handler handler) {
  if (path == null || path.isEmpty) {
    return handler;
  }

  return (final requestCtx) {
    final ctx = requestCtx as RespondableContext;
    final request = ctx.request;
    if (!_ctx.isWithin('/$path', request.requestedUri.path)) {
      return ctx.withResponse(Response.notFound(
        body: Body.fromString(
          'not found',
        ),
      ));
    }
    assert(request.handlerPath == '/');

    final relativeRequest = request.copyWith(path: path);

    return handler(relativeRequest.toContext());
  };
}

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
  Description describe(final Description description) =>
      description.add('Must be at the same moment as $_target with resolution '
          'to the second.');
}

bool _datesEqualToSecond(final DateTime d1, final DateTime d2) =>
    d1.toSecondResolution.isAtSameMomentAs(d2.toSecondResolution);
