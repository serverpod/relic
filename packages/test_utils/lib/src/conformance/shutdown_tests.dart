import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import 'conformance.dart';

/// A handler that reports when it starts and waits for [canComplete].
Handler _signalingHandler({
  required void Function() onRequestStarted,
  required Completer<void> canComplete,
}) {
  return (req) async {
    onRequestStarted();
    await canComplete.future;
    return Response.ok(body: Body.fromString('Completed'));
  };
}

/// A handler that waits [delay] before responding.
///
/// Completers cannot cross isolates, so the multi-isolate tests use this
/// instead.
Handler _delayedHandler(Duration delay) {
  return (req) async {
    await Future<void>.delayed(delay);
    return Response.ok(body: Body.fromString('Completed'));
  };
}

Future<List<Future<http.Response>>> _startDelayedInFlightRequests(
  RelicServer server, {
  int numberOfRequests = 4,
  Duration requestDelay = const Duration(milliseconds: 300),
}) async {
  await server.mountAndStart(_delayedHandler(requestDelay));

  final responseFutures = List.generate(
    numberOfRequests,
    (_) => http.get(server.url),
  );

  // Give requests time to start processing.
  await Future<void>.delayed(const Duration(milliseconds: 50));

  return responseFutures;
}

Future<
  ({List<Future<http.Response>> responseFutures, Completer<void> canComplete})
>
_startInFlightRequests(RelicServer server, {int numberOfRequests = 4}) async {
  var requestsStarted = 0;
  final allRequestsStarted = Completer<void>();
  final canComplete = Completer<void>();

  await server.mountAndStart(
    _signalingHandler(
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
    (_) => http.get(server.url),
  );

  await allRequestsStarted.future;

  return (responseFutures: responseFutures, canComplete: canComplete);
}

void shutdownTests(AdapterConformance conformance) {
  group('Given a server with in-flight requests', () {
    late RelicServer server;

    setUp(() => server = conformance.create());

    tearDown(() => server.close());

    test(
      'when server.close() is called with in-flight requests, '
      'then all requests complete successfully before server shuts down',
      () async {
        final (:responseFutures, :canComplete) = await _startInFlightRequests(
          server,
        );

        final closeFuture = server.close();

        canComplete.complete();

        final (responses, _) = await (responseFutures.wait, closeFuture).wait;

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
        _signalingHandler(
          onRequestStarted: () {
            if (!requestStarted.isCompleted) {
              requestStarted.complete();
            }
          },
          canComplete: canComplete,
        ),
      );

      final inFlightRequest = http.get(server.url);

      await requestStarted.future;

      final closeFuture = server.close();

      late http.Response? newRequestResponse;
      Object? newRequestError;
      try {
        newRequestResponse = await http.get(server.url);
      } catch (e) {
        newRequestError = e;
      }

      canComplete.complete();

      await (inFlightRequest, closeFuture).wait;

      // The exact failure depends on timing: refused, reset or a non-200.
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
        (req) => Response.ok(body: Body.fromString('OK')),
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

      final closeFutures = (server.close(), server.close());

      canComplete.complete();

      final (_, responses) = await (
        closeFutures.wait,
        responseFutures.wait,
      ).wait;

      for (final response in responses) {
        expect(response.statusCode, HttpStatus.ok);
      }
    });

    test('when server.close(force: true) is called with in-flight requests, '
        'then all requests are terminated immediately', () async {
      final (:responseFutures, :canComplete) = await _startInFlightRequests(
        server,
      );

      await server.close(force: true);

      await expectLater(
        responseFutures.wait,
        throwsA(
          isA<ParallelWaitError<List<http.Response?>, List<AsyncError?>>>()
              .having(
                (e) => e.errors.nonNulls.length,
                'error count',
                responseFutures.length,
              ),
        ),
      );

      canComplete.complete();
    });
  });

  group('Given a server with two isolates', () {
    late RelicServer server;
    var serverClosed = false;

    setUp(() {
      serverClosed = false;
      server = conformance.create(noOfIsolates: 2);
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

        final closeFuture = server.close();
        serverClosed = true;

        final (responses, _) = await (responseFutures.wait, closeFuture).wait;

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
        (req) => Response.ok(body: Body.fromString('OK')),
      );

      await server.close();
      await expectLater(server.close(), completes);
    });

    test('when server.close() is called twice concurrently, '
        'then both calls should complete without error', () async {
      // https://github.com/serverpod/relic/issues/293
      final responseFutures = await _startDelayedInFlightRequests(server);

      final closeFutures = (server.close(), server.close()).wait;
      final (_, responses) = await (closeFutures, responseFutures.wait).wait;

      for (final response in responses) {
        expect(response.statusCode, HttpStatus.ok);
      }
    });
  });
}
