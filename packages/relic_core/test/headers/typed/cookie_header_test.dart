import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('CookieHeader cookie lookup', () {
    group('Given duplicate cookies with the same name,', () {
      test('when getCookies is called, '
          'then all matches are returned in order.', () {
        final h = CookieHeader.parse('sid=a; other=x; sid=b');

        expect(
          h.getCookies('sid').map((final c) => c.value).toList(),
          equals(['a', 'b']),
        );
      });

      test('when getCookie is called, '
          'then only the first match is returned.', () {
        final h = CookieHeader.parse('sid=a; other=x; sid=b');

        expect(h.getCookie('sid')?.value, equals('a'));
      });

      test('when the duplicates are byte-identical, '
          'then they are not collapsed and getCookies returns each.', () {
        final h = CookieHeader.parse('sid=a; sid=a');

        expect(
          h.getCookies('sid').map((final c) => c.value),
          equals(['a', 'a']),
        );
      });
    });

    group('Given no cookie with the requested name,', () {
      test('when getCookies is called, '
          'then the result is empty.', () {
        final h = CookieHeader.parse('sid=a');

        expect(h.getCookies('missing'), isEmpty);
        expect(h.getCookie('missing'), isNull);
      });
    });
  });

  group('CookieHeader skip-malformed ordering', () {
    group('Given a malformed cookie before a valid one,', () {
      test('when parsed, '
          'then the malformed cookie is skipped and the valid one kept.', () {
        final h = CookieHeader.parse('invalid cookie; sessionId=abc');

        expect(h.cookies.map((final c) => c.name), equals(['sessionId']));
      });
    });

    group('Given a malformed cookie after a valid one,', () {
      test('when parsed, '
          'then the malformed cookie is skipped and the valid one kept.', () {
        final h = CookieHeader.parse('sessionId=abc; invalid cookie');

        expect(h.cookies.map((final c) => c.name), equals(['sessionId']));
      });
    });
  });

  group('CookieHeader grammar', () {
    test('Given a value with a comma, when parsed, '
        'then that cookie is skipped and the others kept', () {
      final h = CookieHeader.parse(
        'session=abc; consent=analytics,marketing; theme=dark',
      );

      expect(h.cookies.map((final c) => c.name), ['session', 'theme']);
    });

    test('Given tabs and spaces around names and values, when parsed, '
        'then they are trimmed', () {
      final h = CookieHeader.parse('\t sid = abc \t;theme= dark ');

      expect(h.cookies.map((final c) => '${c.name}=${c.value}'), [
        'sid=abc',
        'theme=dark',
      ]);
    });

    test('Given a quoted value, when parsed, then the quotes are kept', () {
      final h = CookieHeader.parse('sid="abc"');

      expect(h.cookies.single.value, '"abc"');
    });

    test('Given a value with = in it, when parsed, '
        'then the value is everything after the first =', () {
      final h = CookieHeader.parse('tok=a=b==');

      expect(h.cookies.single.name, 'tok');
      expect(h.cookies.single.value, 'a=b==');
    });

    test('Given an empty value, when parsed, '
        'then the cookie is kept with an empty value', () {
      final h = CookieHeader.parse('sid=; theme=dark');

      expect(h.cookies.map((final c) => '${c.name}=${c.value}'), [
        'sid=',
        'theme=dark',
      ]);
    });

    test('Given a name with a separator character, when parsed, '
        'then that cookie is skipped', () {
      final h = CookieHeader.parse('s:id=1; ok=2');

      expect(h.cookies.map((final c) => c.name), ['ok']);
    });

    test('Given a value with a space in it, when parsed, '
        'then that cookie is skipped', () {
      final h = CookieHeader.parse('a=b c; ok=2');

      expect(h.cookies.map((final c) => c.name), ['ok']);
    });

    test('Given only segments without =, when parsed, then it throws', () {
      expect(
        () => CookieHeader.parse('abc; def'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('CookieHeader name case-sensitivity', () {
    group('Given two cookies whose names differ only in case,', () {
      test('when parsed, '
          'then they are kept distinct (RFC 6265 4.2.2/5.4).', () {
        final h = CookieHeader.parse('Sid=a; sid=b');

        expect(h.cookies.map((final c) => c.name), equals(['Sid', 'sid']));
        expect(h.getCookie('Sid')?.value, equals('a'));
        expect(h.getCookie('sid')?.value, equals('b'));
      });
    });
  });

  group('CookieHeader nameless segments', () {
    group('Given a nameless `=value` segment alongside a valid cookie,', () {
      test(
        'when parsed, '
        'then the nameless segment is dropped and the valid cookie kept.',
        () {
          final h = CookieHeader.parse('auth=tok; =garbage');

          expect(h.cookies.map((final c) => c.name), equals(['auth']));
          expect(h.getCookie(''), isNull);
        },
      );
    });

    group('Given a header that is only nameless segments,', () {
      test('when parsed, '
          'then it throws (no usable cookie remains).', () {
        expect(() => CookieHeader.parse('='), throwsFormatException);
        expect(() => CookieHeader.parse('=a; =b'), throwsFormatException);
      });
    });
  });
}
