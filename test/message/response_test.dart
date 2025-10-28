import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';
import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../util/test_util.dart';

void main() {
  group('Given a response with a String body', () {
    test('when readAsString is called then it returns the correct string', () {
      final response = Response.ok(body: Body.fromString('hello, world'));
      expect(response.readAsString(), completion(equals('hello, world')));
    });

    test('when read is called then it returns the correct byte list', () {
      final helloWorldBytes = [...helloBytes, ...worldBytes];
      final response = Response.ok(body: Body.fromString('hello, world'));
      expect(response.read().toList(), completion(equals([helloWorldBytes])));
    });
  });

  test(
    'Given a response with a Uint8List body when read then it does not copy the body',
    () async {
      final bytes = Uint8List(10);
      final response = Response.ok(body: Body.fromData(bytes));
      expect(response.body.contentLength, 10);
      expect(await response.read().single, same(bytes));
    },
  );

  test(
    'Given a response with a Stream<Uint8List> body when read then it does not copy the body',
    () async {
      final bytes = Stream.value(Uint8List.fromList([1, 2, 3, 4]));
      final response = Response.ok(body: Body.fromDataStream(bytes));
      expect(response.read(), same(bytes));
    },
  );

  group('Given a new Response.internalServerError without a body', () {
    test(
      'when readAsString is called then it sets the body to "Internal Server Error"',
      () {
        final response = Response.internalServerError();
        expect(
          response.readAsString(),
          completion(equals('Internal Server Error')),
        );
      },
    );

    test('when checked then it sets the content-type header to text/plain', () {
      final response = Response.internalServerError();
      final contentType = response.body.bodyType?.mimeType;
      final encoding = response.body.bodyType?.encoding;
      expect(contentType?.primaryType, equals('text'));
      expect(contentType?.subType, equals('plain'));
      expect(encoding?.name, equals('utf-8'));
      expect(response.body.contentLength, equals(21));
    });
  });

  group('Given a Response.badRequest', () {
    test('when no body is supplied then it results in "Bad Request"', () {
      final response = Response.badRequest();
      expect(response.readAsString(), completion(equals('Bad Request')));
    });

    test('when a body is set then it returns the correct body', () {
      final response = Response.badRequest(
        body: Body.fromString('missing token'),
      );
      expect(response.readAsString(), completion(equals('missing token')));
    });
  });

  group('Given a Response.unauthorized', () {
    test(
      'when a body is set then it returns the correct body and status code',
      () {
        final response = Response.unauthorized(
          body: Body.fromString('request unauthorized'),
        );
        expect(
          response.readAsString(),
          completion(equals('request unauthorized')),
        );
        expect(response.statusCode, 401);
      },
    );
  });

  group('Given a Response redirect', () {
    test(
      'when a String is used then it sets the location header correctly',
      () {
        final response = Response.found(Uri.parse('/foo'));
        expect(response.headers.location.toString(), equals('/foo'));
      },
    );

    test('when a Uri is used then it sets the location header correctly', () {
      final response = Response.found(Uri(path: '/foo'));
      expect(response.headers.location.toString(), equals('/foo'));
    });
  });

  group('Given a response with an Expires header', () {
    test('when no Expires header is present then expires is null', () {
      expect(
        Response.ok(body: Body.fromString('okay!')).headers.expires,
        isNull,
      );
    });

    test(
      'when an Expires header is present then it returns the correct date',
      () {
        expect(
          Response.ok(
            body: Body.fromString('okay!'),
            headers: Headers.build(
              (final mh) =>
                  mh.expires = parseHttpDate('Sun, 06 Nov 1994 08:49:37 GMT'),
            ),
          ).headers.expires,
          equals(DateTime.parse('1994-11-06 08:49:37z')),
        );
      },
    );
  });

  group('Given a response with a Last-Modified header', () {
    test(
      'when no Last-Modified header is present then lastModified is null',
      () {
        expect(
          Response.ok(body: Body.fromString('okay!')).headers.lastModified,
          isNull,
        );
      },
    );

    test(
      'when a Last-Modified header is present then it returns the correct date',
      () {
        expect(
          Response.ok(
            body: Body.fromString('okay!'),
            headers: Headers.build(
              (final mh) =>
                  mh.lastModified = parseHttpDate(
                    'Sun, 06 Nov 1994 08:49:37 GMT',
                  ),
            ),
          ).headers.lastModified,
          equals(DateTime.parse('1994-11-06 08:49:37z')),
        );
      },
    );
  });

  group('Given a response change', () {
    test(
      'when no arguments are provided then it returns an instance with equal values',
      () {
        final controller = StreamController<Object>();

        final response = Response(
          345,
          body: Body.fromString('hèllo, world'),
          encoding: latin1,
          headers: Headers.build(
            (final mh) => mh['header1'] = ['header value 1'],
          ),
          context: {'context1': 'context value 1'},
        );

        final copy = response.copyWith();

        expect(copy.statusCode, response.statusCode);
        expect(copy.readAsString(), completion('hèllo, world'));
        expect(copy.headers.hashCode, response.headers.hashCode);
        expect(copy.headers, same(response.headers));
        expect(copy.encoding, response.encoding);

        controller.add(helloBytes);
        return Future(() {
          controller
            ..add(worldBytes)
            ..close();
        });
      },
    );

    test('when the original response is read then it allows reading', () {
      final response = Response.ok(body: null);
      final changed = response.copyWith();

      expect(response.read().toList(), completion(isEmpty));
      expect(changed.read, throwsStateError);
    });

    test('when the changed response is read then it allows reading', () {
      final response = Response.ok(body: null);
      final changed = response.copyWith();

      expect(changed.read().toList(), completion(isEmpty));
      expect(response.read, throwsStateError);
    });

    test('when another changed response is read then it allows reading', () {
      final response = Response.ok(body: null);
      final changed1 = response.copyWith();
      final changed2 = response.copyWith();

      expect(changed2.read().toList(), completion(isEmpty));
      expect(changed1.read, throwsStateError);
      expect(response.read, throwsStateError);
    });
  });
}
