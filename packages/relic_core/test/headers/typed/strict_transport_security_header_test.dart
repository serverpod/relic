import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('StrictTransportSecurityHeader.parse', () {
    group('Given directives in non-canonical case,', () {
      test('when parsed, '
          'then they are matched case-insensitively.', () {
        final hsts = StrictTransportSecurityHeader.parse(
          'Max-Age=31536000; IncludeSubDomains; Preload',
        );

        expect(hsts.maxAge, equals(31536000));
        expect(hsts.includeSubDomains, isTrue);
        expect(hsts.preload, isTrue);
      });
    });

    group('Given a quoted max-age value,', () {
      test('when parsed, '
          'then the quotes are stripped.', () {
        final hsts = StrictTransportSecurityHeader.parse('max-age="0"');

        expect(hsts.maxAge, equals(0));
      });
    });

    group('Given a negative max-age,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(
          () => StrictTransportSecurityHeader.parse('max-age=-1'),
          throwsFormatException,
        );
      });
    });
  });
}
