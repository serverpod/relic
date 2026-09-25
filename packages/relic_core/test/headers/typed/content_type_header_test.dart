import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('Given a multipart Content-Type header', () {
    test(
      'when parsed then it exposes the MIME type and boundary parameter',
      () {
        final header = ContentTypeHeader.parse(
          'multipart/form-data; boundary=abc123',
        );

        expect(header.mimeType, MimeType.multipartFormData);
        expect(header.parameters['boundary'], 'abc123');
        expect(header.parameter('BOUNDARY'), 'abc123');
      },
    );
  });

  group('Given a urlencoded Content-Type header', () {
    test('when parsed then it exposes the charset parameter', () {
      final header = ContentTypeHeader.parse(
        'application/x-www-form-urlencoded; charset=utf-8',
      );

      expect(header.mimeType, MimeType.urlEncoded);
      expect(header.charset, 'utf-8');
    });
  });

  group('Given Content-Type headers', () {
    test('when accessed through Headers then they are parsed once typed', () {
      final headers = Headers.build(
        (final mh) => mh[Headers.contentTypeHeader] = [
          'multipart/form-data; boundary=abc123',
        ],
      );

      expect(headers.contentType?.mimeType, MimeType.multipartFormData);
      expect(headers.contentType?.parameter('boundary'), 'abc123');
    });

    test(
      'when set through MutableHeaders then it encodes the header value',
      () {
        final headers = Headers.build(
          (final mh) => mh.contentType = ContentTypeHeader(
            mimeType: MimeType.urlEncoded,
            parameters: const {'charset': 'utf-8'},
          ),
        );

        expect(headers[Headers.contentTypeHeader], [
          'application/x-www-form-urlencoded; charset=utf-8',
        ]);
        expect(headers.contentType?.charset, 'utf-8');
      },
    );
  });

  group('Given an invalid Content-Type header', () {
    test(
      'when accessed through Headers then it throws InvalidHeaderException',
      () {
        final headers = Headers.build(
          (final mh) => mh[Headers.contentTypeHeader] = ['not-a-content-type'],
        );

        expect(
          () => headers.contentType,
          throwsA(isA<InvalidHeaderException>()),
        );
      },
    );

    test('when a parameter name is invalid then encoding throws', () {
      expect(
        () => Headers.build(
          (final mh) => mh.contentType = ContentTypeHeader(
            mimeType: MimeType.json,
            parameters: const {'bad name': 'value'},
          ),
        ),
        throwsFormatException,
      );
    });
  });

  group('Given a Content-Type parameter with uppercase name', () {
    test('when constructed then lookup is case-insensitive', () {
      final header = ContentTypeHeader(
        mimeType: MimeType.multipartFormData,
        parameters: const {'Boundary': 'abc123'},
      );

      expect(header.parameters['boundary'], 'abc123');
      expect(header.parameter('BOUNDARY'), 'abc123');
    });
  });
}
