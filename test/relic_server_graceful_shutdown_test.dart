import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';
import 'package:test/test.dart';

/// Creates a handler that delays for the specified duration before responding.
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
        const requestDelay = Duration(milliseconds: 500);
        await server.mountAndStart(_createDelayedHandler(requestDelay));

        // Start a request that will take 500ms to complete
        final responseFuture = http.get(Uri.http('localhost:${server.port}'));

        // Give the request time to start processing
        await Future<void>.delayed(const Duration(milliseconds: 50));

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
        const requestDelay = Duration(milliseconds: 300);
        const numberOfRequests = 5;
        await server.mountAndStart(_createDelayedHandler(requestDelay));

        // Start multiple concurrent requests
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
          expect(
            responses[i].body,
            'Completed',
            reason: 'Request $i should have the expected body',
          );
        }
      },
    );

    test(
      'when server.close() is called, '
      'then new requests are not accepted after close begins',
      () async {
        const requestDelay = Duration(milliseconds: 200);
        await server.mountAndStart(_createDelayedHandler(requestDelay));

        // Start an in-flight request
        final inFlightRequest = http.get(Uri.http('localhost:${server.port}'));

        // Give the request time to start processing
        await Future<void>.delayed(const Duration(milliseconds: 50));

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
      },
      skip:
          'This test depends on the timing of server shutdown '
          'and may not reliably reproduce the rejection behavior',
    );
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

    /// Acceptable timing variance in milliseconds for shutdown timing tests.
    /// This accounts for system scheduling delays and HTTP overhead.
    const timingVarianceMs = 100;

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
      const requestDelay = Duration(milliseconds: 800);
      await server.mountAndStart(_createDelayedHandler(requestDelay));

      // Start a long-running request
      final responseFuture = http.get(Uri.http('localhost:${server.port}'));

      // Give the request time to start processing
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Record when we start closing
      final closeStartTime = DateTime.now();

      // Close the server and wait for response
      serverClosed = true;
      final results = await Future.wait([responseFuture, server.close()]);

      final closeEndTime = DateTime.now();
      final closeDuration = closeEndTime.difference(closeStartTime);

      // The response should have completed successfully
      final response = results[0] as http.Response;
      expect(response.statusCode, HttpStatus.ok);

      // The close should have taken approximately as long as the request
      // needed to complete (accounting for some timing variance)
      // The request should have taken most of its delay (minus the 50ms head start)
      expect(
        closeDuration.inMilliseconds,
        greaterThan(requestDelay.inMilliseconds - timingVarianceMs),
        reason: 'Server close should wait for in-flight request to complete',
      );
    });
  });
}
