import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:relic/relic.dart';
import 'package:relic/src/method/request_method.dart';
import 'package:test/test.dart';

final helloBytes = utf8.encode('hello,');

final worldBytes = utf8.encode(' world');

final Matcher throwsHijackException = throwsA(isA<HijackException>());

/// A simple, synchronous handler for [Request].
///
/// By default, replies with a status code 200, empty headers, and
/// `Hello from ${request.url.path}`.
Response syncHandler(Request request, {int? statusCode, Headers? headers}) {
  return Response(
    statusCode ?? 200,
    headers: headers ?? Headers.empty(),
    body: Body.fromString('Hello from ${request.requestedUri.path}'),
  );
}

/// Calls [syncHandler] and wraps the response in a [Future].
Future<Response> asyncHandler(Request request) =>
    Future(() => syncHandler(request));

/// Makes a simple GET request to [handler] and returns the result.
Future<Response> makeSimpleRequest(Handler handler) =>
    Future.sync(() => handler(_request));

final _request = Request(RequestMethod.get, localhostUri);

final localhostUri = Uri.parse('http://localhost/');

final isOhNoStateError =
    isA<StateError>().having((e) => e.message, 'message', 'oh no');

/// Like [group] but takes a variants argument and creates a group for each variant.
@isTestGroup
void parameterizedGroup<T>(
  String Function(T) descriptionBuilder,
  void Function(T) body, {
  required Iterable<T> variants,
}) {
  for (var v in variants) {
    group(descriptionBuilder(v), () => body(v));
  }
}

/// Like [test] but takes a variants argument and creates a test-case for each variant.
@isTest
void parameterizedTest<T>(
  String Function(T) descriptionBuilder,
  void Function(T) body, {
  required Iterable<T> variants,
}) {
  for (var v in variants) {
    test(descriptionBuilder(v), () => body(v));
  }
}

@isTest
void singleTest(
  String description, {
  required dynamic actual,
  required dynamic expected,
}) {
  test(description, () {
    expect(actual, expected);
  });
}
