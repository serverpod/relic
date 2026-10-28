import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

/// The same field read from a byte store and from a map store, so the two
/// decode paths can be compared.
(Headers bytes, Headers text) _both(final String name, final String value) => (
  Headers.fromStore(ByteHeaderStore.encode([(name, value)])),
  Headers.fromMap({
    name: [value],
  }),
);

void main() {
  group('Given a Cookie header in a byte store,', () {
    const cases = [
      'sid=a; other=x; sid=b',
      ' a = 1 ;\tb=2 ',
      'q="quoted"; eq=a==b',
      'bad name=1; ok=2',
      'nameless; =v; ok=1',
      'sid=a; sid=a',
    ];
    for (final value in cases) {
      test('when "$value" is read, then the bytes path reads what the text '
          'path reads', () {
        final (bytes, text) = _both('Cookie', value);
        expect(bytes.cookie!.cookies, text.cookie!.cookies);
      });
    }

    test('when the value is only malformed cookies, '
        'then both paths reject it the same way', () {
      final (bytes, text) = _both('Cookie', 'nope; =x');
      expect(
        () => bytes.cookie,
        throwsA(
          isA<InvalidHeaderException>().having(
            (final e) => e.description,
            'description',
            contains('No valid cookies'),
          ),
        ),
      );
      expect(() => text.cookie, throwsA(isA<InvalidHeaderException>()));
    });

    test('when read twice, then the same header comes back', () {
      final (bytes, _) = _both('Cookie', 'sid=a');
      expect(bytes.cookie, same(bytes.cookie));
    });
  });

  group('Given an Accept-Language header in a byte store,', () {
    const cases = [
      'en-US,en;q=0.9,da;q=0.8',
      ' EN , fr ;Q = 0.5 , en ',
      'de;q=2,fr;q=abc,es;x=1;q=0.3',
      'en,,fr, ,',
      '*',
      'en;q=0.8;q=0.1',
    ];
    for (final value in cases) {
      test('when "$value" is read, then the bytes path reads what the text '
          'path reads', () {
        final (bytes, text) = _both('Accept-Language', value);
        expect(bytes.acceptLanguage, text.acceptLanguage);
      });
    }

    test('when the value mixes * with languages, '
        'then both paths reject it', () {
      final (bytes, text) = _both('Accept-Language', '*, en');
      expect(
        () => bytes.acceptLanguage,
        throwsA(
          isA<InvalidHeaderException>().having(
            (final e) => e.description,
            'description',
            contains('Wildcard'),
          ),
        ),
      );
      expect(() => text.acceptLanguage, throwsA(isA<InvalidHeaderException>()));
    });

    test('when the value is empty after trimming, '
        'then both paths reject it', () {
      final (bytes, text) = _both('Accept-Language', ' , ');
      expect(
        () => bytes.acceptLanguage,
        throwsA(isA<InvalidHeaderException>()),
      );
      expect(() => text.acceptLanguage, throwsA(isA<InvalidHeaderException>()));
    });

    test('when a value has a byte above 0x7f, '
        'then the text path decides and lower-cases it as Latin-1', () {
      final (bytes, text) = _both('Accept-Language', 'Én');
      expect(bytes.acceptLanguage, text.acceptLanguage);
      expect(bytes.acceptLanguage!.languages.single.language, 'én');
    });

    test('when the header has two fields, '
        'then both are read, as the text path does', () {
      final headers = Headers.fromStore(
        ByteHeaderStore.encode(const [
          ('Accept-Language', 'en'),
          ('Accept-Language', 'da;q=0.5'),
        ]),
      );
      expect(headers.acceptLanguage!.languages.map((final l) => l.language), [
        'en',
        'da',
      ]);
    });
  });
}
