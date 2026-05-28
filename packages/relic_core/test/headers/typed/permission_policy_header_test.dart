import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('PermissionsPolicyHeader.parse', () {
    group('Given an inner-list with an sf-string containing a space,', () {
      test('when parsed, '
          'then the sf-string is kept as a single value.', () {
        final header = PermissionsPolicyHeader.parse('camera=("hello world")');

        final values = header.directives.single.values.toList();
        expect(values, equals(['hello world']));
      });
    });

    group('Given a directive value containing an "=" (URL query),', () {
      test('when parsed, '
          'then the full value after the first "=" is preserved.', () {
        final header = PermissionsPolicyHeader.parse(
          'geolocation=("https://x.com?a=1")',
        );

        final values = header.directives.single.values.toList();
        expect(values, equals(['https://x.com?a=1']));
      });
    });

    group('Given a value with a comma inside an sf-string,', () {
      test('when parsed, '
          'then the comma does not split the directive.', () {
        final header = PermissionsPolicyHeader.parse('camera=("a,b")');

        expect(header.directives, hasLength(1));
        expect(header.directives.single.values.toList(), equals(['a,b']));
      });
    });

    group('Given mixed token and sf-string items,', () {
      test('when parsed, '
          'then both are recovered.', () {
        final header = PermissionsPolicyHeader.parse(
          'geolocation=(self "https://example.com")',
        );

        expect(
          header.directives.single.values.toList(),
          equals(['self', 'https://example.com']),
        );
      });
    });
  });

  group('PermissionsPolicyHeader encoding', () {
    group('Given an origin value,', () {
      test('when encoded, '
          'then it is rendered as a quoted sf-string.', () {
        final header = PermissionsPolicyHeader.directives([
          PermissionsPolicyDirective(
            name: 'geolocation',
            values: ['self', 'https://example.com'],
          ),
        ]);

        expect(
          PermissionsPolicyHeader.codec.encode(header).single,
          equals('geolocation=(self "https://example.com")'),
        );
      });
    });

    group('Given an sf-string value round-tripped through the codec,', () {
      test('when re-parsed, '
          'then the original values are recovered.', () {
        final header = PermissionsPolicyHeader.directives([
          PermissionsPolicyDirective(name: 'camera', values: ['hello world']),
        ]);

        final wire = PermissionsPolicyHeader.codec.encode(header).single;
        final reparsed = PermissionsPolicyHeader.parse(wire);

        expect(
          reparsed.directives.single.values.toList(),
          equals(['hello world']),
        );
      });
    });

    group('Given a value containing a control character,', () {
      test('when encoded, '
          'then it throws to prevent header injection.', () {
        final header = PermissionsPolicyHeader.directives([
          PermissionsPolicyDirective(
            name: 'geolocation',
            values: ['https://x.com\r\nSet-Cookie: evil=1'],
          ),
        ]);

        expect(
          () => PermissionsPolicyHeader.codec.encode(header),
          throwsFormatException,
        );
      });
    });
  });
}
