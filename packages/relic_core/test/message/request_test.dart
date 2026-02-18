import 'dart:async';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';
import 'package:test_utils/test_utils.dart';

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
        'when an absolute URL is provided then url.pathAndQuery exposes the relativized path and query',
        () {
          final request = RequestInternal.create(
            Method.get,
            Uri.parse('http://localhost/foo/bar?q=1'),
            Object(),
          );
          expect(request.url.pathAndQuery, equals(Uri.parse('/foo/bar?q=1')));
        },
      );

      test('when the URL contains a colon then it is handled correctly', () {
        final request = RequestInternal.create(
          Method.get,
          Uri.parse('http://localhost/foo/bar:42'),
          Object(),
        );
        expect(request.url.pathAndQuery, equals(Uri.parse('/foo/bar:42')));
      });

      test(
        'when the URL contains a colon in the first segment then it is handled correctly',
        () {
          final request = RequestInternal.create(
            Method.get,
            Uri.parse('http://localhost/foo:bar/42'),
            Object(),
          );
          expect(request.url.pathAndQuery, equals(Uri.parse('/foo:bar/42')));
        },
      );

      test('when the URL contains a slash then it is handled correctly', () {
        final request = RequestInternal.create(
          Method.get,
          Uri.parse('http://localhost/foo/bar%2f42'),
          Object(),
        );
        expect(request.url.pathAndQuery, equals(Uri.parse('/foo/bar%2f42')));
      });
    });

    group('Given request errors', () {
      group('Given a url', () {
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
        expect(copy.url, request.url);
        expect(copy.protocolVersion, request.protocolVersion);
        expect(copy.headers, same(request.headers));
        expect(copy.url.pathAndQuery, request.url.pathAndQuery);
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

    test(
      'when a new url is provided then it returns an instance with the new url',
      () {
        final request = RequestInternal.create(
          Method.get,
          Uri.parse('https://test.example.com/original'),
          Object(),
        );

        final newUri = Uri.parse('https://test.example.com/new-path?q=1');
        final copy = request.copyWith(url: newUri);

        expect(copy.url, equals(newUri));
        expect(copy.method, equals(request.method));
        expect(copy.protocolVersion, equals(request.protocolVersion));
      },
    );

    test('when a new url and headers are provided then both are updated', () {
      final request = RequestInternal.create(
        Method.post,
        Uri.parse('https://test.example.com/original'),
        Object(),
      );

      final newUri = Uri.parse('https://test.example.com/updated');
      final newHeaders = Headers.build(
        (final mh) => mh['X-Custom'] = ['value'],
      );
      final copy = request.copyWith(url: newUri, headers: newHeaders);

      expect(copy.url, equals(newUri));
      expect(copy.headers, same(newHeaders));
    });

    test('when a relative url is provided then it throws an ArgumentError', () {
      final request = _request();
      expect(
        () => request.copyWith(url: Uri.parse('/relative-path')),
        throwsArgumentError,
      );
    });

    test(
      'when a url with a fragment is provided then it throws an ArgumentError',
      () {
        final request = _request();
        expect(
          () => request.copyWith(url: Uri.parse('http://localhost/path#frag')),
          throwsArgumentError,
        );
      },
    );
  });
}
