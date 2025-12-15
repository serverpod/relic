import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';
import 'package:test/test.dart';

/// Creates a handler that signals when processing starts and waits for
/// a completer before responding.
///
/// [onRequestStarted] is called when the request starts processing.
/// [canComplete] is a completer that the handler waits for before responding.
Handler _createSignalingHandler({
  required final void Function() onRequestStarted,
  required final Completer<void> canComplete,
}) {
  return (final req) async {
    onRequestStarted();
    await canComplete.future;
    return Response.ok(body: Body.fromString('Completed'));
  };
}

/// Creates a handler that delays for the specified duration before responding.
/// Used for multi-isolate tests where Completers cannot cross isolate boundaries.
Handler _createDelayedHandler(final Duration delay) {
  return (final req) async {
    await Future<void>.delayed(delay);
    return Response.ok(body: Body.fromString('Completed'));
  };
}

/// Starts [numberOfRequests] requests to the server using a delay-based handler.
/// Used for multi-isolate tests where Completers cannot cross isolate boundaries.
///
/// Returns the futures for all request responses. Waits briefly for requests
/// to start processing before returning.
Future<List<Future<http.Response>>> _startDelayedInFlightRequests(
  final RelicServer server, {
  final int numberOfRequests = 4,
  final Duration requestDelay = const Duration(milliseconds: 300),
}) async {
  await server.mountAndStart(_createDelayedHandler(requestDelay));

  final responseFutures = List.generate(
    numberOfRequests,
    (_) => http.get(Uri.http('localhost:${server.port}')),
  );

  // Give requests time to start processing
  await Future<void>.delayed(const Duration(milliseconds: 50));

  return responseFutures;
}

/// Starts [numberOfRequests] requests to the server and waits for all of them
/// to begin processing in the handler.
///
/// Returns a record containing:
/// - [responseFutures]: The futures for all request responses
/// - [canComplete]: A completer that must be completed to allow requests to finish
///
/// The handler will block until [canComplete] is completed.
Future<
  ({List<Future<http.Response>> responseFutures, Completer<void> canComplete})
>
_startInFlightRequests(
  final RelicServer server, {
  final int numberOfRequests = 4,
}) async {
  var requestsStarted = 0;
  final allRequestsStarted = Completer<void>();
  final canComplete = Completer<void>();

  await server.mountAndStart(
    _createSignalingHandler(
      onRequestStarted: () {
        requestsStarted++;
        if (requestsStarted == numberOfRequests) {
          allRequestsStarted.complete();
        }
      },
      canComplete: canComplete,
    ),
  );

  final responseFutures = List.generate(
    numberOfRequests,
    (_) => http.get(Uri.http('localhost:${server.port}')),
  );

  await allRequestsStarted.future;

  return (responseFutures: responseFutures, canComplete: canComplete);
}

void main() {
  group('Given a RelicServer with in-flight requests', () {
    late RelicServer server;

    setUp(() async {
      server = RelicServer(
        () => IOAdapter.bind(InternetAddress.loopbackIPv4, port: 0),
      );
    });

    tearDown(() async {
      // Server may already be closed by the test
      await server.close();
    });

    test(
      'when server.close() is called with in-flight requests, '
      'then all requests complete successfully before server shuts down',
      () async {
        final (:responseFutures, :canComplete) = await _startInFlightRequests(
          server,
        );

        // Close the server while requests are in-flight
        final closeFuture = server.close();

        // Allow the requests to complete
        canComplete.complete();

        // Wait for all responses and server close at the same time
        final (responses, _) = await (responseFutures.wait, closeFuture).wait;

        // Verify all requests completed successfully
        for (var i = 0; i < responses.length; i++) {
          expect(
            responses[i].statusCode,
            HttpStatus.ok,
            reason: 'Request $i should have completed with 200 OK',
          );
          expect(
            responses[i].body,
            'Completed',
            reason: 'Request $i should have the expected body',
          );
        }
      },
    );

    test('when server.close() is called, '
        'then new requests are not accepted after close begins', () async {
      final requestStarted = Completer<void>();
      final canComplete = Completer<void>();

      await server.mountAndStart(
        _createSignalingHandler(
          onRequestStarted: () {
            if (!requestStarted.isCompleted) {
              requestStarted.complete();
            }
          },
          canComplete: canComplete,
        ),
      );

      // Start an in-flight request
      final inFlightRequest = http.get(Uri.http('localhost:${server.port}'));

      // Wait for the request to start processing
      await requestStarted.future;

      // Close the server
      final closeFuture = server.close();

      // Try to start a new request after close is initiated
      // (This should fail or be rejected)
      late http.Response? newRequestResponse;
      Object? newRequestError;
      try {
        newRequestResponse = await http.get(
          Uri.http('localhost:${server.port}'),
        );
      } catch (e) {
        newRequestError = e;
      }

      // Allow the in-flight request to complete
      canComplete.complete();

      // Wait for close and in-flight request to complete
      await (inFlightRequest, closeFuture).wait;

      // New request should have either failed with an error
      // or received a connection refused/reset error
      // The exact behavior depends on timing and the underlying HTTP server
      expect(
        newRequestError != null || newRequestResponse?.statusCode != 200,
        isTrue,
        reason: 'New requests should be rejected after server begins closing',
      );
    });

    test('when server.close() is called twice sequentially, '
        'then the second call should complete without hanging', () async {
      // https://github.com/serverpod/relic/issues/293
      await server.mountAndStart(
        (final req) => Response.ok(body: Body.fromString('OK')),
      );

      await server.close();

      await expectLater(server.close(), completes);
    });

    test('when server.close() is called twice concurrently, '
        'then both calls should complete without error', () async {
      // https://github.com/serverpod/relic/issues/293
      final (:responseFutures, :canComplete) = await _startInFlightRequests(
        server,
      );

      // Start both close calls concurrently
      final closeFutures = (server.close(), server.close());

      // Allow requests to complete
      canComplete.complete();

      // Both close calls and all requests should complete successfully
      final (_, responses) = await (
        closeFutures.wait,
        responseFutures.wait,
      ).wait;

      for (final response in responses) {
        expect(response.statusCode, HttpStatus.ok);
      }
    });
  });

  group('Given a RelicServer with multi-isolate configuration', () {
    late RelicServer server;
    bool serverClosed = false;

    setUp(() async {
      serverClosed = false;
      server = RelicServer(
        () => IOAdapter.bind(InternetAddress.loopbackIPv4, port: 0),
        noOfIsolates: 2,
      );
    });

    tearDown(() async {
      if (!serverClosed) {
        try {
          await server.close();
        } catch (_) {}
      }
    });

    test(
      'when server.close() is called with in-flight requests, '
      'then all requests complete successfully before server shuts down',
      () async {
        final responseFutures = await _startDelayedInFlightRequests(server);

        // Close the server while requests are in-flight
        final closeFuture = server.close();
        serverClosed = true;

        // Wait for all responses and server close at the same time
        final (responses, _) = await (responseFutures.wait, closeFuture).wait;

        // Verify all requests completed successfully
        for (var i = 0; i < responses.length; i++) {
          expect(
            responses[i].statusCode,
            HttpStatus.ok,
            reason: 'Request $i should have completed with 200 OK',
          );
        }
      },
    );

    test('when server.close() is called twice sequentially, '
        'then the second call should complete without hanging', () async {
      // https://github.com/serverpod/relic/issues/293
      await server.mountAndStart(
        (final req) => Response.ok(body: Body.fromString('OK')),
      );

      await server.close();
      await expectLater(server.close(), completes);
    });

    test('when server.close() is called twice concurrently, '
        'then both calls should complete without error', () async {
      // https://github.com/serverpod/relic/issues/293
      final responseFutures = await _startDelayedInFlightRequests(server);

      // Both close calls should complete successfully
      final closeFutures = (server.close(), server.close()).wait;
      final (_, responses) = await (closeFutures, responseFutures.wait).wait;

      // Verify requests completed
      for (final response in responses) {
        expect(response.statusCode, HttpStatus.ok);
      }
    });
  });
}
