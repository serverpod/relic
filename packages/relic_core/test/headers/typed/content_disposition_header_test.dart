import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  String encode(final String filename) {
    final headers = Headers.build(
      (final mh) => mh.contentDisposition = ContentDispositionHeader(
        type: 'attachment',
        parameters: [
          ContentDispositionParameter(name: 'filename', value: filename),
        ],
      ),
    );
    return headers[Headers.contentDispositionHeader]!.first;
  }

  group('Given a filename containing a quote', () {
    const attack = 'report.pdf"; filename*=UTF-8\'\'evil.html';

    test('when the header is encoded, '
        'then the value is not terminated early.', () {
      final encoded = encode(attack);

      final withoutEscapes = encoded
          .replaceAll(r'\\', '')
          .replaceAll(r'\"', '');

      expect(
        '"'.allMatches(withoutEscapes).length,
        2,
        reason:
            'The value must be delimited by exactly one pair of quotes, so '
            'the interior quote has to be escaped. Encoded as: $encoded',
      );
    });

    test('when the encoded header is parsed back, '
        'then the original filename is recovered.', () {
      final reparsed = ContentDispositionHeader.parse(encode(attack));

      expect(reparsed.parameters.single.name, 'filename');
      expect(reparsed.parameters.single.value, attack);
    });
  });

  group('Given a filename containing a control character', () {
    test('when the header is encoded, '
        'then it throws rather than emitting the character.', () {
      expect(
        () => encode('report\r\nX-Injected: 1.pdf'),
        throwsFormatException,
      );
    });
  });

  group('Given an ordinary filename', () {
    test('when the header is encoded and parsed back, '
        'then it round-trips unchanged.', () {
      for (final name in ['example.txt', 'a file with spaces.txt']) {
        final reparsed = ContentDispositionHeader.parse(encode(name));
        expect(reparsed.parameters.single.value, name, reason: name);
      }
    });
  });

  group('Given a parameter without an equals sign', () {
    test('when the header is parsed, '
        'then it throws instead of skipping the parameter.', () {
      expect(
        () => ContentDispositionHeader.parse('form-data; foo'),
        throwsFormatException,
      );
    });
  });

  group('Given a parameter with text after its quoted value', () {
    test('when the header is parsed, '
        'then it throws instead of storing the trailing text.', () {
      expect(
        () => ContentDispositionHeader.parse('form-data; name="v" evil'),
        throwsFormatException,
      );
    });
  });

  group('Given an extended parameter with charset and language', () {
    test('when the header is parsed and encoded back, '
        'then the extended form round-trips.', () {
      final header = ContentDispositionHeader.parse(
        "attachment; filename*=UTF-8'en'a%20b.txt",
      );
      final parameter = header.parameters.single;
      expect(parameter.isExtended, isTrue);
      expect(parameter.language, LanguageTag.parse('en'));
      expect(parameter.value, 'a b.txt');

      final headers = Headers.build(
        (final mh) => mh.contentDisposition = header,
      );
      expect(
        headers[Headers.contentDispositionHeader]!.first,
        "attachment; filename*=UTF-8'en'a%20b.txt",
      );
    });
  });

  test('Given an extended parameter value with characters outside attr-char, '
      'when the header is encoded, '
      'then it percent-encodes those characters as UTF-8.', () {
    const header = ContentDispositionHeader(
      type: 'attachment',
      parameters: [
        ContentDispositionParameter(
          name: 'filename',
          value: "it's (1) caf\u00e9.txt",
          isExtended: true,
        ),
      ],
    );

    final headers = Headers.build((final mh) => mh.contentDisposition = header);
    expect(
      headers[Headers.contentDispositionHeader]!.first,
      "attachment; filename*=UTF-8''it%27s%20%281%29%20caf%C3%A9.txt",
    );
  });

  test('Given an extended parameter in the ISO-8859-1 charset, '
      'when the header is parsed, '
      'then it throws FormatException.', () {
    expect(
      () => ContentDispositionHeader.parse(
        "attachment; filename*=ISO-8859-1''na%EFve.txt",
      ),
      throwsFormatException,
    );
  });

  test('Given an extended parameter without the charset and language, '
      'when the header is parsed, '
      'then it throws FormatException.', () {
    expect(
      () => ContentDispositionHeader.parse('attachment; filename*=evil.html'),
      throwsFormatException,
    );
  });

  test('Given an extended parameter with an invalid percent escape, '
      'when the header is parsed, '
      'then it throws FormatException.', () {
    expect(
      () =>
          ContentDispositionHeader.parse("form-data; filename*=UTF-8''%zz.txt"),
      throwsFormatException,
    );
  });

  test('Given an extended parameter ending in a truncated percent escape, '
      'when the header is parsed, '
      'then it throws FormatException.', () {
    expect(
      () =>
          ContentDispositionHeader.parse("form-data; filename*=UTF-8''report%"),
      throwsFormatException,
    );
  });
}
