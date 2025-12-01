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

void main() {
  group('Given a RelicServer with in-flight requests', () {
    late RelicServer server;
    bool serverClosed = false;

    setUp(() async {
      serverClosed = false;
      server = RelicServer(
        () => IOAdapter.bind(InternetAddress.loopbackIPv4, port: 0),
      );
    });

    tearDown(() async {
      // Server may already be closed by the test
      if (!serverClosed) {
        try {
          await server.close();
        } catch (_) {}
      }
    });

    test(
      'when server.close() is called during an in-flight request, '
      'then the request completes successfully before server shuts down',
      () async {
        final requestStarted = Completer<void>();
        final canComplete = Completer<void>();

        await server.mountAndStart(
          _createSignalingHandler(
            onRequestStarted: requestStarted.complete,
            canComplete: canComplete,
          ),
        );

        // Start a request
        final responseFuture = http.get(Uri.http('localhost:${server.port}'));

        // Wait for the request to start processing
        await requestStarted.future;

        // Verify request is in-flight
        final infoBeforeClose = await server.connectionsInfo();
        expect(
          infoBeforeClose.active + infoBeforeClose.idle,
          greaterThan(0),
          reason: 'Expected at least one active or idle connection',
        );

        // Close the server while request is in-flight
        final closeFuture = server.close();
        serverClosed = true;

        // Allow the request to complete
        canComplete.complete();

        // Wait for both the response and server close to complete
        final results = await Future.wait([responseFuture, closeFuture]);

        // Verify the in-flight request completed successfully
        final response = results[0] as http.Response;
        expect(response.statusCode, HttpStatus.ok);
        expect(response.body, 'Completed');
      },
    );

    test(
      'when server.close() is called with multiple concurrent in-flight requests, '
      'then all requests complete successfully',
      () async {
        const numberOfRequests = 5;
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

        // Start multiple concurrent requests
        final responseFutures = List.generate(
          numberOfRequests,
          (_) => http.get(Uri.http('localhost:${server.port}')),
        );

        // Wait for all requests to start processing
        await allRequestsStarted.future;

        // Close the server while requests are in-flight
        final closeFuture = server.close();
        serverClosed = true;

        // Allow the requests to complete
        canComplete.complete();

        // Wait for all responses
        final responses = await Future.wait(responseFutures);

        // Wait for server to close
        await closeFuture;

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
      await Future.wait([inFlightRequest, closeFuture]);

      // New request should have either failed with an error
      // or received a connection refused/reset error
      // The exact behavior depends on timing and the underlying HTTP server
      expect(
        newRequestError != null || newRequestResponse?.statusCode != 200,
        isTrue,
        reason: 'New requests should be rejected after server begins closing',
      );
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
      'when server.close() is called during in-flight requests across isolates, '
      'then all requests complete successfully',
      () async {
        // Use delay-based handler because Completers cannot cross isolate
        // boundaries
        const requestDelay = Duration(milliseconds: 300);
        const numberOfRequests = 4;

        await server.mountAndStart(_createDelayedHandler(requestDelay));

        // Start multiple concurrent requests that will be distributed
        // across isolates
        final responseFutures = List.generate(
          numberOfRequests,
          (_) => http.get(Uri.http('localhost:${server.port}')),
        );

        // Give requests time to start processing
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Close the server while requests are in-flight
        final closeFuture = server.close();
        serverClosed = true;

        // Wait for all responses
        final responses = await Future.wait(responseFutures);

        // Wait for server to close
        await closeFuture;

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
  });

  group('Given a RelicServer shutdown timing', () {
    late RelicServer server;
    bool serverClosed = false;

    setUp(() async {
      serverClosed = false;
      server = RelicServer(
        () => IOAdapter.bind(InternetAddress.loopbackIPv4, port: 0),
      );
    });

    tearDown(() async {
      if (!serverClosed) {
        try {
          await server.close();
        } catch (_) {}
      }
    });

    test('when server.close() is called with a long-running request, '
        'then server waits for the request to complete', () async {
      final requestStarted = Completer<void>();
      final canComplete = Completer<void>();
      var responseReceived = false;

      await server.mountAndStart(
        _createSignalingHandler(
          onRequestStarted: requestStarted.complete,
          canComplete: canComplete,
        ),
      );

      // Start a long-running request
      final responseFuture = http
          .get(Uri.http('localhost:${server.port}'))
          .then((final response) {
            responseReceived = true;
            return response;
          });

      // Wait for the request to start processing
      await requestStarted.future;

      // Close the server while request is in-flight
      serverClosed = true;
      final closeFuture = server.close();

      // Now allow the request to complete
      canComplete.complete();

      // Wait for both the response and server close to complete
      final results = await Future.wait([responseFuture, closeFuture]);

      // Verify the response was received (meaning the request was allowed to
      // complete despite the server closing)
      expect(responseReceived, isTrue);

      // The response should have completed successfully
      final response = results[0] as http.Response;
      expect(response.statusCode, HttpStatus.ok);
      expect(response.body, 'Completed');
    });
  });
}
