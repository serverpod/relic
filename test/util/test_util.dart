import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';
import 'package:relic/src/context/context.dart';
import 'package:test/test.dart';

final helloBytes = utf8.encode('hello,');

final worldBytes = utf8.encode(' world');

typedef SyncHandler = HandledContext Function(Request);

/// A simple, synchronous handler.
///
/// By default, replies with a status code 200, empty headers, and
/// `Hello from ${ctx.url.path}`.
SyncHandler createSyncHandler({
  final int statusCode = 200,
  final Headers? headers,
  final Body? body,
}) {
  return (final Request ctx) {
    return Response(
      statusCode,
      headers: headers ?? Headers.empty(),
      body: body ?? Body.fromString('Hello from ${ctx.requestedUri.path}'),
    );
  };
}

final SyncHandler syncHandler = createSyncHandler();

/// Calls [createSyncHandler] and wraps the response in a [Future].
Future<HandledContext> asyncHandler(final Request ctx) async {
  return syncHandler(ctx);
}

/// Makes a simple GET request to [handler] and returns the result.
Future<Response> makeSimpleRequest(
  final Handler handler, [
  final Request? request,
]) async {
  final newCtx = await handler(
    (request ?? _defaultRequest)..setToken(Object()),
  );
  if (newCtx is! Response) throw ArgumentError(newCtx);
  return newCtx;
}

final _defaultRequest = Request(Method.get, localhostUri);

final localhostUri = Uri.parse('http://localhost/');

final isOhNoStateError = isA<StateError>().having(
  (final e) => e.message,
  'message',
  'oh no',
);

Future<RelicServer> testServe(
  final Handler handler, {
  final SecurityContext? context,
}) async {
  final server = RelicServer(
    () =>
        IOAdapter.bind(InternetAddress.loopbackIPv4, port: 0, context: context),
  );
  await server.mountAndStart(handler);
  return server;
}

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
  final String Function(T) descriptionBuilder,
  final void Function(T) body, {
  required final Iterable<T> variants,
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
  final String Function(T) descriptionBuilder,
  final void Function(T) body, {
  required final Iterable<T> variants,
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
void singleTest(
  final String description,
  final dynamic actual,
  final dynamic expected,
) {
  test(description, () {
    expect(actual, expected);
  });
}
