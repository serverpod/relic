import 'dart:async';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';
import 'package:relic/relic.dart';
import 'package:relic/src/context/context.dart';
import 'package:test/test.dart';

import '../util/test_util.dart';

Request _request({final Headers? headers, final Body? body}) {
  return RequestInternal.create(
    Method.get,
    localhostUri,
    Object(),
    headers: headers,
    body: body,
  );
}

void main() {
  group('Given a request constructor', () {
    test('when no protocolVersion is provided then it defaults to "1.1"', () {
      final request = RequestInternal.create(
        Method.get,
        localhostUri,
        Object(),
      );
      expect(request.protocolVersion, '1.1');
    });

    test(
      'when a non-default protocolVersion is provided then it is set correctly',
      () {
        final request = RequestInternal.create(
          Method.get,
          localhostUri,
          Object(),
          protocolVersion: '1.0',
        );
        expect(request.protocolVersion, '1.0');
      },
    );

    group('Given a request URL', () {
      test(
        "when no url is provided then it defaults to the requestedUri's relativized path and query",
        () {
          final request = RequestInternal.create(
            Method.get,
            Uri.parse('http://localhost/foo/bar?q=1'),
            Object(),
          );
          expect(request.url, equals(Uri.parse('/foo/bar?q=1')));
        },
      );

      test('when the URL contains a colon then it is handled correctly', () {
        final request = RequestInternal.create(
          Method.get,
          Uri.parse('http://localhost/foo/bar:42'),
          Object(),
        );
        expect(request.url, equals(Uri.parse('/foo/bar:42')));
      });

      test(
        'when the URL contains a colon in the first segment then it is handled correctly',
        () {
          final request = RequestInternal.create(
            Method.get,
            Uri.parse('http://localhost/foo:bar/42'),
            Object(),
          );
          expect(request.url, equals(Uri.parse('/foo:bar/42')));
        },
      );

      test('when the URL contains a slash then it is handled correctly', () {
        final request = RequestInternal.create(
          Method.get,
          Uri.parse('http://localhost/foo/bar%2f42'),
          Object(),
        );
        expect(request.url, equals(Uri.parse('/foo/bar%2f42')));
      });
    });

    group('Given request errors', () {
      group('Given a requestedUri', () {
        test('when it is not absolute then it throws an ArgumentError', () {
          expect(
            () => RequestInternal.create(
              Method.get,
              Uri.parse('/path'),
              Object(),
            ),
            throwsArgumentError,
          );
        });

        test('when it has a fragment then it throws an ArgumentError', () {
          expect(() {
            RequestInternal.create(
              Method.get,
              Uri.parse('http://localhost/#fragment'),
              Object(),
            );
          }, throwsArgumentError);
        });
      });
    });
  });

  group('Given ifModifiedSince', () {
    test('when there is no If-Modified-Since header then it is null', () {
      final request = _request();
      expect(request.headers.ifModifiedSince, isNull);
    });

    test('when there is a Last-Modified header then it is set correctly', () {
      final request = _request(
        headers: Headers.build((final mh) {
          mh.ifModifiedSince = parseHttpDate('Sun, 06 Nov 1994 08:49:37 GMT');
        }),
      );
      expect(
        request.headers.ifModifiedSince,
        equals(DateTime.parse('1994-11-06 08:49:37z')),
      );
    });
  });

  group('Given a request change', () {
    test(
      'when no arguments are provided then it returns an instance with equal values',
      () {
        final controller = StreamController<Uint8List>();

        final uri = Uri.parse('https://test.example.com/static/file.html');

        final request = RequestInternal.create(
          Method.get,
          uri,
          Object(),
          protocolVersion: '2.0',
          headers: Headers.build(
            (final mh) => mh['header1'] = ['header value 1'],
          ),
          body: Body.fromDataStream(controller.stream),
        );

        final copy = request.copyWith();

        expect(copy.method, request.method);
        expect(copy.requestedUri, request.requestedUri);
        expect(copy.protocolVersion, request.protocolVersion);
        expect(copy.headers, same(request.headers));
        expect(copy.url, request.url);
        expect(copy.readAsString(), completion('hello, world'));

        controller.add(helloBytes);
        return Future(() {
          controller
            ..add(worldBytes)
            ..close();
        });
      },
    );

    test('when the original request is read then it allows reading', () {
      final request = _request();
      final changed = request.copyWith();

      expect(request.read().toList(), completion(isEmpty));
      expect(changed.read, throwsStateError);
    });

    test('when the changed request is read then it allows reading', () {
      final request = _request();
      final changed = request.copyWith();

      expect(changed.read().toList(), completion(isEmpty));
      expect(request.read, throwsStateError);
    });

    test('when another changed request is read then it allows reading', () {
      final request = _request();
      final changed1 = request.copyWith();
      final changed2 = request.copyWith();

      expect(changed2.read().toList(), completion(isEmpty));
      expect(changed1.read, throwsStateError);
      expect(request.read, throwsStateError);
    });
  });
}
