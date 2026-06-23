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
}
