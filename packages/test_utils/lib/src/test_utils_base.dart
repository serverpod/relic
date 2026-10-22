import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

final helloBytes = utf8.encode('hello,');

final worldBytes = utf8.encode(' world');

typedef SyncHandler = Result Function(Request);

/// A simple, synchronous handler.
///
/// By default, replies with a status code 200, empty headers, and
/// `Hello from ${req.url.path}`.
SyncHandler createSyncHandler({
  int statusCode = 200,
  Headers? headers,
  Body? body,
}) {
  return (Request req) {
    return Response(
      statusCode,
      headers: headers ?? Headers.empty(),
      body: body ?? Body.fromString('Hello from ${req.url.path}'),
    );
  };
}

final SyncHandler syncHandler = createSyncHandler();

/// Calls [createSyncHandler] and wraps the response in a [Future].
Future<Result> asyncHandler(Request req) async {
  return syncHandler(req);
}

/// Makes a simple GET request to [handler] and returns the result.
Future<Response> makeSimpleRequest(Handler handler, [Request? request]) async {
  final newCtx = await handler((request ?? _defaultRequest));
  if (newCtx is! Response) throw ArgumentError(newCtx);
  return newCtx;
}

final _defaultRequest = testRequest(localhostUri);

/// A [Request] for [url], built without an adapter.
Request testRequest(
  Uri url, {
  Method method = Method.get,
  Headers? headers,
  Body? body,
}) => RequestInternal.create(method, url, null, headers: headers, body: body);

final localhostUri = Uri.parse('http://localhost/');

final isOhNoStateError = isA<StateError>().having(
  (e) => e.message,
  'message',
  'oh no',
);

/// Like [group], but takes a [variants] argument and creates a group for each
/// variant.
///
/// Setup multiple groups of tests where each group gets a different parameter
/// value. The [descriptionBuilder] is used to produce a description for each
/// group based on the [variants]. For each variant the [body] is executed to
/// setup tests and sub-groups.
///
/// This is useful for running the same tests against multiple configurations,
/// implementations, or inputs.
///
/// Example:
/// ```dart
/// parameterizedGroup<String>(
///   (protocol) => 'Testing protocol: $protocol',
///   (protocol) {
///     test('connects successfully', () {
///       // Test using the protocol parameter
///     });
///   },
///   variants: ['http', 'https', 'ws'],
/// );
/// ```
@isTestGroup
void parameterizedGroup<T>(
  String Function(T) descriptionBuilder,
  void Function(T) body, {
  required Iterable<T> variants,
}) {
  for (final v in variants) {
    group(descriptionBuilder(v), () => body(v));
  }
}

/// Like [test,] but takes a [variants] argument and creates a test-case
/// for each variant.
///
/// Setup multiple test cases where each test case gets a different parameter
/// value. The [descriptionBuilder] is used to produce a description for each
/// test case based on the [variants]. For each variant the [body] is executed.
///
/// This is useful for testing the same functionality against multiple inputs
/// or configurations.
///
/// Example:
/// ```dart
/// parameterizedTest<int>(
///   (value) => 'Test with value: $value',
///   (value) {
///     expect(value * 2, greaterThan(value));
///   },
///   variants: [1, 2, 3, 4, 5],
/// );
/// ```
@isTest
void parameterizedTest<T>(
  String Function(T) descriptionBuilder,
  void Function(T) body, {
  required Iterable<T> variants,
}) {
  for (final v in variants) {
    test(descriptionBuilder(v), () => body(v));
  }
}

/// Creates a [test] with a single [expect].
///
/// A convenience method that creates a test with a [description] that
/// validates the single expectation that [actual] matches [expected].
///
/// Example:
/// ```dart
/// singleTest('1 + 1 equals 2', 1 + 1, 2);
/// ```
@isTest
void singleTest(String description, dynamic actual, dynamic expected) {
  test(description, () {
    expect(actual, expected);
  });
}
