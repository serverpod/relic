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

  test('Given headers with a multipart Content-Type, '
      'when contentType is read, '
      'then it returns the MIME type and boundary.', () {
    final headers = Headers.build(
      (final mh) => mh[Headers.contentTypeHeader] = [
        'multipart/form-data; boundary=abc123',
      ],
    );

    expect(headers.contentType?.mimeType, MimeType.multipartFormData);
    expect(headers.contentType?.parameter('boundary'), 'abc123');
  });

  test('Given headers with an invalid Content-Type, '
      'when contentType is read, '
      'then it throws InvalidHeaderException.', () {
    final headers = Headers.build(
      (final mh) => mh[Headers.contentTypeHeader] = ['not-a-content-type'],
    );

    expect(() => headers.contentType, throwsA(isA<InvalidHeaderException>()));
  });

  group('Given an invalid Content-Type header', () {
    test('when parsed, '
        'then it throws FormatException.', () {
      expect(
        () => ContentTypeHeader.parse('not-a-content-type'),
        throwsFormatException,
      );
    });

    test('when a parameter name is invalid then encoding throws', () {
      expect(
        () => ContentTypeHeader.codec.encode(
          ContentTypeHeader(
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
