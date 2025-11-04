// ignore_for_file: only_throw_errors

import 'dart:async';

import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../util/test_util.dart';

void main() {
  test(
    'Given a middleware with null handlers when a request is processed then it forwards the request and response',
    () async {
      final handler = const Pipeline()
          .addMiddleware(createMiddleware())
          .addHandler(
            createSyncHandler(
              headers: Headers.build(
                (final mh) =>
                    mh.from = FromHeader(
                      emails: ['innerHandler@serverpod.dev'],
                    ),
              ),
            ),
          );

      final response = await makeSimpleRequest(handler);
      expect(
        response.headers.from?.emails,
        contains('innerHandler@serverpod.dev'),
      );
    },
  );

  group('Given a requestHandler', () {
    test(
      'when sync null response is returned then it forwards to inner handler',
      () async {
        final handler = const Pipeline()
            .addMiddleware(createMiddleware(onRequest: (final request) => null))
            .addHandler(syncHandler);

        final response = await makeSimpleRequest(handler);
        expect(response.headers['from'], isNull);
      },
    );

    test(
      'when async null response is returned then it forwards to inner handler',
      () async {
        final handler = const Pipeline()
            .addMiddleware(
              createMiddleware(
                onRequest: (final request) => Future.value(null),
              ),
            )
            .addHandler(syncHandler);

        final response = await makeSimpleRequest(handler);
        expect(response.headers.from, isNull);
      },
    );

    test('when sync response is returned then it is used', () async {
      final handler = const Pipeline()
          .addMiddleware(
            createMiddleware(onRequest: (final request) => _middlewareResponse),
          )
          .addHandler(respondWith(_failHandler));

      final response = await makeSimpleRequest(handler);
      expect(
        response.headers.from?.emails,
        contains('middleware@serverpod.dev'),
      );
    });

    test('when async response is returned then it is used', () async {
      final handler = const Pipeline()
          .addMiddleware(
            createMiddleware(
              onRequest: (final request) => Future.value(_middlewareResponse),
            ),
          )
          .addHandler(respondWith(_failHandler));

      final response = await makeSimpleRequest(handler);
      expect(
        response.headers.from?.emails,
        contains('middleware@serverpod.dev'),
      );
    });

    group('Given a responseHandler', () {
      test(
        'when sync result is returned then responseHandler is not called',
        () async {
          final middleware = createMiddleware(
            onRequest: (final request) => _middlewareResponse,
            onResponse: (final response) => fail('should not be called'),
          );

          final handler = const Pipeline()
              .addMiddleware(middleware)
              .addHandler(syncHandler);

          final response = await makeSimpleRequest(handler);
          expect(
            response.headers.from?.emails,
            contains('middleware@serverpod.dev'),
          );
        },
      );

      test(
        'when async result is returned then responseHandler is not called',
        () async {
          final middleware = createMiddleware(
            onRequest: (final request) => Future.value(_middlewareResponse),
            onResponse: (final response) => fail('should not be called'),
          );
          final handler = const Pipeline()
              .addMiddleware(middleware)
              .addHandler(syncHandler);

          final response = await makeSimpleRequest(handler);
          expect(
            response.headers.from?.emails,
            contains('middleware@serverpod.dev'),
          );
        },
      );
    });
  });

  group('Given a responseHandler', () {
    test(
      'when innerHandler sync response is seen then replaced value continues',
      () async {
        final handler = const Pipeline()
            .addMiddleware(
              createMiddleware(
                onResponse: (final response) {
                  expect(
                    response.headers.from?.emails,
                    contains('handler@serverpod.dev'),
                  );
                  return _middlewareResponse;
                },
              ),
            )
            .addHandler(
              createSyncHandler(
                headers: Headers.build(
                  (final mh) =>
                      mh.from = FromHeader(emails: ['handler@serverpod.dev']),
                ),
              ),
            );

        final response = await makeSimpleRequest(handler);
        expect(
          response.headers.from?.emails,
          contains('middleware@serverpod.dev'),
        );
      },
    );

    test(
      'when innerHandler async response is seen then async value continues',
      () async {
        final handler = const Pipeline()
            .addMiddleware(
              createMiddleware(
                onResponse: (final response) {
                  expect(
                    response.headers.from?.emails,
                    contains('handler@serverpod.dev'),
                  );
                  return Future.value(_middlewareResponse);
                },
              ),
            )
            .addHandler(((final req) {
              return Future(
                () => createSyncHandler(
                  headers: Headers.build(
                    (final mh) =>
                        mh.from = FromHeader(emails: ['handler@serverpod.dev']),
                  ),
                )(req),
              );
            }));

        final response = await makeSimpleRequest(handler);
        expect(
          response.headers.from?.emails,
          contains('middleware@serverpod.dev'),
        );
      },
    );
  });

  group('Given error handling', () {
    test(
      'when sync error is thrown by requestHandler then it bubbles down',
      () {
        final handler = const Pipeline()
            .addMiddleware(
              createMiddleware(
                onRequest: (final request) => throw 'middleware error',
              ),
            )
            .addHandler(respondWith(_failHandler));

        expect(makeSimpleRequest(handler), throwsA('middleware error'));
      },
    );

    test(
      'when async error is thrown by requestHandler then it bubbles down',
      () {
        final handler = const Pipeline()
            .addMiddleware(
              createMiddleware(
                onRequest: (final request) => Future.error('middleware error'),
              ),
            )
            .addHandler(respondWith(_failHandler));

        expect(makeSimpleRequest(handler), throwsA('middleware error'));
      },
    );

    test(
      'when throw from responseHandler then it does not hit error handler',
      () {
        final middleware = createMiddleware(
          onResponse: (final response) {
            throw 'middleware error';
          },
          onError: (final e, final s) => fail('should never get here'),
        );

        final handler = const Pipeline()
            .addMiddleware(middleware)
            .addHandler(syncHandler);

        expect(makeSimpleRequest(handler), throwsA('middleware error'));
      },
    );

    test('when requestHandler throw then it does not hit errorHandlers', () {
      final middleware = createMiddleware(
        onRequest: (final request) {
          throw 'middleware error';
        },
        onError: (final e, final s) => fail('should never get here'),
      );

      final handler = const Pipeline()
          .addMiddleware(middleware)
          .addHandler(syncHandler);

      expect(makeSimpleRequest(handler), throwsA('middleware error'));
    });

    test(
      'when inner handler throws then it is caught by errorHandler with response',
      () async {
        final middleware = createMiddleware(
          onError: (final error, final stack) {
            expect(error, 'bad handler');
            return _middlewareResponse;
          },
        );

        final handler = const Pipeline()
            .addMiddleware(middleware)
            .addHandler(
              respondWith((final request) {
                throw 'bad handler';
              }),
            );

        final response = await makeSimpleRequest(handler);
        expect(
          response.headers.from?.emails,
          contains('middleware@serverpod.dev'),
        );
      },
    );

    test(
      'when inner handler throws then it is caught by errorHandler and rethrown',
      () {
        final middleware = createMiddleware(
          onError: (final Object error, final stack) {
            expect(error, 'bad handler');
            throw error;
          },
        );

        final handler = const Pipeline()
            .addMiddleware(middleware)
            .addHandler(
              respondWith((final request) {
                throw 'bad handler';
              }),
            );

        expect(makeSimpleRequest(handler), throwsA('bad handler'));
      },
    );

    test(
      'when error is thrown by inner handler without a middleware errorHandler then it is rethrown',
      () {
        final middleware = createMiddleware();

        final handler = const Pipeline()
            .addMiddleware(middleware)
            .addHandler(
              respondWith((final request) {
                throw 'bad handler';
              }),
            );

        expect(makeSimpleRequest(handler), throwsA('bad handler'));
      },
    );
  });
}

Response _failHandler(final Request request) => fail('should never get here');

final Response _middlewareResponse = Response.ok(
  body: Body.fromString('middleware content'),
  headers: Headers.build(
    (final mh) => mh.from = FromHeader(emails: ['middleware@serverpod.dev']),
  ),
);
