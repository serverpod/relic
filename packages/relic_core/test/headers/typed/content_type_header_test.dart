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
      (mh) =>
          mh[HeaderName.contentType] = ['multipart/form-data; boundary=abc123'],
    );

    expect(headers.contentType?.mimeType, MimeType.multipartFormData);
    expect(headers.contentType?.parameter('boundary'), 'abc123');
  });

  test('Given headers with an invalid Content-Type, '
      'when contentType is read, '
      'then it throws InvalidHeaderException.', () {
    final headers = Headers.build(
      (mh) => mh[HeaderName.contentType] = ['not-a-content-type'],
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

  test('Given a Content-Type with upper-case letters in every part, '
      'when parsed, '
      'then only the parameter value keeps its case.', () {
    final header = ContentTypeHeader.parse('Text/HTML; Charset=UTF-8');

    expect(header.mimeType, MimeType.html);
    expect(header.parameters, {'charset': 'UTF-8'});
  });

  test('Given a Content-Type with a quoted parameter value, '
      'when parsed, '
      'then the value is unquoted and unescaped.', () {
    final header = ContentTypeHeader.parse(r'text/plain; title="a \"b\"; c"');

    expect(header.parameters, {'title': 'a "b"; c'});
  });

  test('Given a Content-Type with whitespace around its parts, '
      'when parsed, '
      'then the whitespace is left out.', () {
    final header = ContentTypeHeader.parse(
      ' multipart/form-data ;\tboundary=abc123 ; charset=utf-8 ',
    );

    expect(header.mimeType, MimeType.multipartFormData);
    expect(header.parameters, {'boundary': 'abc123', 'charset': 'utf-8'});
  });

  test('Given a Content-Type that repeats a parameter, '
      'when parsed, '
      'then the last value is kept.', () {
    final header = ContentTypeHeader.parse(
      'text/plain; charset=latin1; Charset=utf-8',
    );

    expect(header.parameters, {'charset': 'utf-8'});
  });

  test('Given a Content-Type with a quoted value outside Latin-1, '
      'when parsed, '
      'then the value is kept.', () {
    final header = ContentTypeHeader.parse(
      'text/plain; name="\u65e5\u672c.txt"',
    );

    expect(header.parameters, {'name': '\u65e5\u672c.txt'});
  });

  for (final value in const [
    'utf-8',
    '',
    'a b',
    'a;b',
    'a"b',
    r'a\b',
    'caf\u00e9',
  ]) {
    test('Given a ContentTypeHeader with the parameter value "$value", '
        'when encoded and parsed again, '
        'then the header comes back equal.', () {
      final header = ContentTypeHeader(
        mimeType: MimeType.plainText,
        parameters: {'title': value},
      );

      final encoded = ContentTypeHeader.codec.encode(header);

      expect(ContentTypeHeader.codec.decode(encoded), header);
    });
  }

  test('Given a ContentTypeHeader with a quote in a parameter value, '
      'when encoded, '
      'then the value is a quoted-string with the quote escaped.', () {
    final header = ContentTypeHeader(
      mimeType: MimeType.plainText,
      parameters: const {'title': 'a"b', 'charset': 'utf-8'},
    );

    expect(ContentTypeHeader.codec.encode(header), [
      r'text/plain; title="a\"b"; charset=utf-8',
    ]);
  });

  test('Given a ContentTypeHeader with a value outside Latin-1, '
      'when encoded, '
      'then it throws FormatException.', () {
    final header = ContentTypeHeader(
      mimeType: MimeType.plainText,
      parameters: const {'name': '\u65e5\u672c.txt'},
    );

    expect(() => ContentTypeHeader.codec.encode(header), throwsFormatException);
  });

  test('Given a ContentTypeHeader with a control character in a value, '
      'when encoded, '
      'then it throws FormatException.', () {
    final header = ContentTypeHeader(
      mimeType: MimeType.plainText,
      parameters: const {'title': 'a\u0001b'},
    );

    expect(() => ContentTypeHeader.codec.encode(header), throwsFormatException);
  });

  test('Given a Content-Type with a tab inside a quoted value, '
      'when parsed, '
      'then the tab is part of the value.', () {
    final header = ContentTypeHeader.parse('text/plain; title="a\tb"');

    expect(header.parameters, {'title': 'a\tb'});
  });

  test('Given a Content-Type folded onto a second line, '
      'when parsed, '
      'then it throws FormatException.', () {
    expect(
      () => ContentTypeHeader.parse('text/plain;\r\n charset=utf-8'),
      throwsFormatException,
    );
  });

  test('Given a Content-Type with a backslash before a control character, '
      'when parsed, '
      'then it throws FormatException.', () {
    expect(
      () => ContentTypeHeader.parse('text/plain; title="a\\\u0001b"'),
      throwsFormatException,
    );
  });

  test('Given a Content-Type that ends in a semicolon, '
      'when parsed, '
      'then it has no parameters.', () {
    final header = ContentTypeHeader.parse('application/json;');

    expect(header.mimeType, MimeType.json);
    expect(header.parameters, isEmpty);
  });

  test('Given a Content-Type with empty parameters among the others, '
      'when parsed, '
      'then only the others are kept.', () {
    final header = ContentTypeHeader.parse(
      'multipart/form-data;; boundary=abc123 ; ;charset=utf-8; ',
    );

    expect(header.parameters, {'boundary': 'abc123', 'charset': 'utf-8'});
  });

  for (final value in const [
    '',
    'text',
    'text/',
    '/plain',
    'text /plain',
    'text/ plain',
    't\u00e9xt/plain',
    'text/plain; charset',
    'text/plain; charset=',
    'text/plain; charset =utf-8',
    'text/plain; charset= utf-8',
    'text/plain; charset="utf-8',
    'text/plain; charset=utf-8 x',
    'text/plain charset=utf-8',
    'text/plain, text/html',
  ]) {
    test('Given the malformed Content-Type "$value", '
        'when parsed, '
        'then it throws FormatException.', () {
      expect(() => ContentTypeHeader.parse(value), throwsFormatException);
    });
  }
}
