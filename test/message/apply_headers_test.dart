import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';
import 'package:mockito/mockito.dart';
import 'package:relic/relic.dart';
import 'package:relic/src/extensions/http_response_extension.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:test/test.dart';

class HttpHeadersMock extends Mock implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  List<String>? operator [](final String name) => _headers[name];

  @override
  int contentLength = -1;

  @override
  ContentType? contentType;

  @override
  void set(
    final String name,
    final Object value, {
    final bool preserveHeaderCase = false,
  }) {
    if (value is String) {
      _headers[name] = [value];
    } else if (value is List<String>) {
      _headers[name] = value;
    } else {
      throw ArgumentError('Invalid value type: $value');
    }
  }
}

class HttpResponseMock extends Mock implements HttpResponse {
  final HttpHeadersMock _headers = HttpHeadersMock();
  final int _statusCode;

  HttpResponseMock({
    final int statusCode = 200,
  }) : _statusCode = statusCode;

  @override
  HttpHeaders get headers => _headers;

  @override
  int get statusCode => _statusCode;
}

void main() {
  group('Given a framework response object', () {
    test(
        'with some headers '
        'when applying headers to http response '
        'then the headers are applied correctly', () async {
      final HttpResponseMock response = HttpResponseMock();

      final now = DateTime.now();
      final expires = now.add(const Duration(days: 1));
      final lastModified = now.add(const Duration(days: 2));
      response.applyHeaders(
        Headers.build((final mh) {
          mh.date = now;
          mh.expires = expires;
          mh.lastModified = lastModified;
          mh.origin = Uri.parse('https://example.com');
          mh.server = 'Relic';
          mh['foo'] = ['bar'];
        }),
        Body.empty(),
      );

      expect(response.headers['date'], equals([formatHttpDate(now)]));
      expect(response.headers['expires'], equals([formatHttpDate(expires)]));
      expect(response.headers['last-modified'],
          equals([formatHttpDate(lastModified)]));
      expect(response.headers['origin'], equals(['https://example.com']));
      expect(response.headers['server'], equals(['Relic']));
      expect(response.headers['foo'], equals(['bar']));
    });

    test(
        'with mime type and encoding '
        'when applying headers to http response '
        'then the content type is applied correctly', () async {
      final HttpResponseMock response = HttpResponseMock();
      response.applyHeaders(
        Headers.empty(),
        Body.fromString(
          'Relic',
          mimeType: MimeType.plainText,
          encoding: utf8,
        ),
      );

      expect(
        response.headers.contentType.toString(),
        equals('text/plain; charset=utf-8'),
      );
    });

    test(
        'with a known content length '
        'when applying headers to http response '
        'then the content length is applied correctly', () async {
      final HttpResponseMock response = HttpResponseMock();
      response.applyHeaders(
        Headers.empty(),
        Body.fromDataStream(
          Stream.fromIterable([
            Uint8List.fromList('Relic'.codeUnits),
          ]),
          contentLength: 5,
        ),
      );

      expect(response.headers.contentLength, equals(5));
    });

    test(
        'with an unknown content length '
        'when applying headers to http response '
        'then chunked transfer encoding is added', () async {
      final HttpResponseMock response = HttpResponseMock(statusCode: 200);
      response.applyHeaders(
        Headers.empty(),
        Body.fromDataStream(
          const Stream.empty(),
        ),
      );

      expect(
        response.headers['transfer-encoding'],
        equals([TransferEncoding.chunked.name]),
      );
    });

    test(
        'with "identity" transfer encoding and unknown content length '
        'when applying headers to http response '
        'then no "chunked" transfer encoding is added', () async {
      final HttpResponseMock response = HttpResponseMock();
      response.applyHeaders(
        Headers.build(
          (final mh) => mh.transferEncoding = TransferEncodingHeader(
            encodings: [TransferEncoding.identity],
          ),
        ),
        Body.fromDataStream(
          const Stream.empty(),
        ),
      );

      expect(
        response.headers['transfer-encoding'],
        isNot(contains(TransferEncoding.chunked.name)),
      );
    });

    test(
        'with "chunked" transfer encoding already applied '
        'when applying headers to http response '
        'then "chunked" is retained', () async {
      final HttpResponseMock response = HttpResponseMock();
      response.applyHeaders(
        Headers.build(
          (final mh) => mh.transferEncoding = TransferEncodingHeader(
            encodings: [TransferEncoding.chunked],
          ),
        ),
        Body.fromDataStream(
          Stream.fromIterable([
            Uint8List.fromList('5\r\nRelic\r\n0\r\n\r\n'.codeUnits),
          ]),
        ),
      );

      expect(
        response.headers['transfer-encoding'],
        equals([TransferEncoding.chunked.name]),
      );
    });

    group('with status code', () {
      test(
          '100 (continue) '
          'when applying headers to http response '
          'then no chunked transfer encoding is added', () async {
        final HttpResponseMock response = HttpResponseMock(statusCode: 100);
        response.applyHeaders(
          Headers.empty(),
          Body.fromDataStream(
            const Stream.empty(),
          ),
        );

        expect(
          response.headers['transfer-encoding'],
          isNot(contains(TransferEncoding.chunked.name)),
        );
      });

      test(
          '101 (switching protocols) '
          'when applying headers to http response '
          'then no chunked transfer encoding is added', () async {
        final HttpResponseMock response = HttpResponseMock(statusCode: 101);
        response.applyHeaders(
          Headers.empty(),
          Body.fromDataStream(
            const Stream.empty(),
          ),
        );

        expect(
          response.headers['transfer-encoding'],
          isNot(contains(TransferEncoding.chunked.name)),
        );
      });

      test(
          '102 (processing) '
          'when applying headers to http response '
          'then no chunked transfer encoding is added', () async {
        final HttpResponseMock response = HttpResponseMock(statusCode: 102);
        response.applyHeaders(
          Headers.empty(),
          Body.fromDataStream(
            const Stream.empty(),
          ),
        );

        expect(
          response.headers['transfer-encoding'],
          isNot(contains(TransferEncoding.chunked.name)),
        );
      });

      test(
          '103 (early hints) '
          'when applying headers to http response '
          'then no chunked transfer encoding is added', () async {
        final HttpResponseMock response = HttpResponseMock(statusCode: 103);
        response.applyHeaders(
          Headers.empty(),
          Body.fromDataStream(
            const Stream.empty(),
          ),
        );

        expect(
          response.headers['transfer-encoding'],
          isNot(contains(TransferEncoding.chunked.name)),
        );
      });

      test(
          '204 (no content) '
          'when applying headers to http response '
          'then no chunked transfer encoding is added', () async {
        final HttpResponseMock response = HttpResponseMock(statusCode: 204);
        response.applyHeaders(
          Headers.empty(),
          Body.fromDataStream(
            const Stream.empty(),
          ),
        );

        expect(
          response.headers['transfer-encoding'],
          isNot(contains(TransferEncoding.chunked.name)),
        );
      });

      test(
          '304 (not modified) '
          'when applying headers to http response '
          'then no chunked transfer encoding is added', () async {
        final HttpResponseMock response = HttpResponseMock(statusCode: 304);
        response.applyHeaders(
          Headers.empty(),
          Body.fromDataStream(
            const Stream.empty(),
          ),
        );

        expect(
          response.headers['transfer-encoding'],
          isNot(contains(TransferEncoding.chunked.name)),
        );
      });
    });

    test(
        'with mime type multipart/byteranges '
        'when applying headers to http response '
        'then no chunked transfer encoding is added', () async {
      final HttpResponseMock response = HttpResponseMock();
      response.applyHeaders(
        Headers.empty(),
        Body.fromDataStream(
          const Stream.empty(),
          mimeType: MimeType.multipartByteranges,
        ),
      );

      expect(
        response.headers['transfer-encoding'],
        isNot(contains(TransferEncoding.chunked.name)),
      );
    });
  });
}
