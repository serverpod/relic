// ignore_for_file: only_throw_errors

import 'dart:async';

import 'package:relic/relic.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:test/test.dart';

import '../util/test_util.dart';

void main() {
  test(
      'Given a middleware with null handlers when a request is processed then it forwards the request and response',
      () async {
    final handler = const Pipeline()
        .addMiddleware(createMiddleware())
        .addHandler((final request) {
      return syncHandler(
        request,
        headers: Headers.build((final mh) =>
            mh.from = FromHeader(emails: ['innerHandler@serverpod.dev'])),
      );
    });

    final response = await makeSimpleRequest(handler);
    expect(
        response.headers.from?.emails, contains('innerHandler@serverpod.dev'));
  });

  group('Given a requestHandler', () {
    test(
        'when sync null response is returned then it forwards to inner handler',
        () async {
      final handler = const Pipeline()
          .addMiddleware(
              createMiddleware(requestHandler: (final request) => null))
          .addHandler(syncHandler);

      final response = await makeSimpleRequest(handler);
      expect(response.headers['from'], isNull);
    });

    test(
        'when async null response is returned then it forwards to inner handler',
        () async {
      final handler = const Pipeline()
          .addMiddleware(createMiddleware(
              requestHandler: (final request) => Future.value(null)))
          .addHandler(syncHandler);

      final response = await makeSimpleRequest(handler);
      expect(response.headers.from, isNull);
    });

    test('when sync response is returned then it is used', () async {
      final handler = const Pipeline()
          .addMiddleware(createMiddleware(
              requestHandler: (final request) => _middlewareResponse))
          .addHandler(_failHandler);

      final response = await makeSimpleRequest(handler);
      expect(
          response.headers.from?.emails, contains('middleware@serverpod.dev'));
    });

    test('when async response is returned then it is used', () async {
      final handler = const Pipeline()
          .addMiddleware(createMiddleware(
              requestHandler: (final request) =>
                  Future.value(_middlewareResponse)))
          .addHandler(_failHandler);

      final response = await makeSimpleRequest(handler);
      expect(
          response.headers.from?.emails, contains('middleware@serverpod.dev'));
    });

    group('Given a responseHandler', () {
      test('when sync result is returned then responseHandler is not called',
          () async {
        final middleware = createMiddleware(
            requestHandler: (final request) => _middlewareResponse,
            responseHandler: (final response) => fail('should not be called'));

        final handler =
            const Pipeline().addMiddleware(middleware).addHandler(syncHandler);

        final response = await makeSimpleRequest(handler);
        expect(response.headers.from?.emails,
            contains('middleware@serverpod.dev'));
      });

      test('when async result is returned then responseHandler is not called',
          () async {
        final middleware = createMiddleware(
            requestHandler: (final request) =>
                Future.value(_middlewareResponse),
            responseHandler: (final response) => fail('should not be called'));
        final handler =
            const Pipeline().addMiddleware(middleware).addHandler(syncHandler);

        final response = await makeSimpleRequest(handler);
        expect(response.headers.from?.emails,
            contains('middleware@serverpod.dev'));
      });
    });
  });

  group('Given a responseHandler', () {
    test(
        'when innerHandler sync response is seen then replaced value continues',
        () async {
      final handler = const Pipeline()
          .addMiddleware(createMiddleware(responseHandler: (final response) {
        expect(
          response.headers.from?.emails,
          contains('handler@serverpod.dev'),
        );
        return _middlewareResponse;
      })).addHandler((final request) {
        return syncHandler(
          request,
          headers: Headers.build((final mh) =>
              mh.from = FromHeader(emails: ['handler@serverpod.dev'])),
        );
      });

      final response = await makeSimpleRequest(handler);
      expect(
        response.headers.from?.emails,
        contains('middleware@serverpod.dev'),
      );
    });

    test('when innerHandler async response is seen then async value continues',
        () async {
      final handler = const Pipeline().addMiddleware(
        createMiddleware(
          responseHandler: (final response) {
            expect(
              response.headers.from?.emails,
              contains('handler@serverpod.dev'),
            );
            return Future.value(_middlewareResponse);
          },
        ),
      ).addHandler((final request) {
        return Future(
          () => syncHandler(
            request,
            headers: Headers.build((final mh) =>
                mh.from = FromHeader(emails: ['handler@serverpod.dev'])),
          ),
        );
      });

      final response = await makeSimpleRequest(handler);
      expect(
        response.headers.from?.emails,
        contains('middleware@serverpod.dev'),
      );
    });
  });

  group('Given error handling', () {
    test('when sync error is thrown by requestHandler then it bubbles down',
        () {
      final handler = const Pipeline()
          .addMiddleware(createMiddleware(
              requestHandler: (final request) => throw 'middleware error'))
          .addHandler(_failHandler);

      expect(makeSimpleRequest(handler), throwsA('middleware error'));
    });

    test('when async error is thrown by requestHandler then it bubbles down',
        () {
      final handler = const Pipeline()
          .addMiddleware(createMiddleware(
              requestHandler: (final request) =>
                  Future.error('middleware error')))
          .addHandler(_failHandler);

      expect(makeSimpleRequest(handler), throwsA('middleware error'));
    });

    test('when throw from responseHandler then it does not hit error handler',
        () {
      final middleware = createMiddleware(
          responseHandler: (final response) {
            throw 'middleware error';
          },
          errorHandler: (final e, final s) => fail('should never get here'));

      final handler =
          const Pipeline().addMiddleware(middleware).addHandler(syncHandler);

      expect(makeSimpleRequest(handler), throwsA('middleware error'));
    });

    test('when requestHandler throw then it does not hit errorHandlers', () {
      final middleware = createMiddleware(
          requestHandler: (final request) {
            throw 'middleware error';
          },
          errorHandler: (final e, final s) => fail('should never get here'));

      final handler =
          const Pipeline().addMiddleware(middleware).addHandler(syncHandler);

      expect(makeSimpleRequest(handler), throwsA('middleware error'));
    });

    test(
        'when inner handler throws then it is caught by errorHandler with response',
        () async {
      final middleware =
          createMiddleware(errorHandler: (final error, final stack) {
        expect(error, 'bad handler');
        return _middlewareResponse;
      });

      final handler = const Pipeline()
          .addMiddleware(middleware)
          .addHandler((final request) {
        throw 'bad handler';
      });

      final response = await makeSimpleRequest(handler);
      expect(
        response.headers.from?.emails,
        contains('middleware@serverpod.dev'),
      );
    });

    test(
        'when inner handler throws then it is caught by errorHandler and rethrown',
        () {
      final middleware =
          createMiddleware(errorHandler: (final Object error, final stack) {
        expect(error, 'bad handler');
        throw error;
      });

      final handler = const Pipeline()
          .addMiddleware(middleware)
          .addHandler((final request) {
        throw 'bad handler';
      });

      expect(makeSimpleRequest(handler), throwsA('bad handler'));
    });

    test(
        'when error is thrown by inner handler without a middleware errorHandler then it is rethrown',
        () {
      final middleware = createMiddleware();

      final handler = const Pipeline()
          .addMiddleware(middleware)
          .addHandler((final request) {
        throw 'bad handler';
      });

      expect(makeSimpleRequest(handler), throwsA('bad handler'));
    });

    test("when HijackException is thrown then it doesn't handle it", () {
      final middleware =
          createMiddleware(errorHandler: (final error, final stack) {
        fail("error handler shouldn't be called");
      });

      final handler = const Pipeline()
          .addMiddleware(middleware)
          .addHandler((final request) => throw const HijackException());

      expect(makeSimpleRequest(handler), throwsHijackException);
    });
  });
}

Response _failHandler(final Request request) => fail('should never get here');

final Response _middlewareResponse = Response.ok(
  body: Body.fromString('middleware content'),
  headers: Headers.build(
    (final mh) => mh.from = FromHeader(emails: ['middleware@serverpod.dev']),
  ),
);
