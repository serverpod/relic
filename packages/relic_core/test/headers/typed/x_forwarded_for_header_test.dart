import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('XForwardedForHeader', () {
    group('parse', () {
      test('Given a single IP address, '
          'when parsed, '
          'then addresses list contains that IP', () {
        final values = ['192.0.2.43'];
        final expectedAddresses = ['192.0.2.43'];

        final header = XForwardedForHeader.parse(values);

        expect(header.addresses, equals(expectedAddresses));
      });

      test('Given multiple IP addresses comma-separated, '
          'when parsed, '
          'then addresses list contains all IPs in order', () {
        final values = ['192.0.2.43, 198.51.100.10, 203.0.113.60'];
        final expectedAddresses = [
          '192.0.2.43',
          '198.51.100.10',
          '203.0.113.60',
        ];

        final header = XForwardedForHeader.parse(values);

        expect(header.addresses, orderedEquals(expectedAddresses));
      });

      test('Given multiple IP addresses with varying spacing, '
          'when parsed, '
          'then addresses are trimmed and correct', () {
        final values = ['192.0.2.43,198.51.100.10  , 203.0.113.60'];
        final expectedAddresses = [
          '192.0.2.43',
          '198.51.100.10',
          '203.0.113.60',
        ];

        final header = XForwardedForHeader.parse(values);

        expect(header.addresses, orderedEquals(expectedAddresses));
      });

      test('Given IP addresses including "unknown", '
          'when parsed, '
          'then "unknown" is included as an address', () {
        final values = ['unknown, 192.0.2.43, unknown'];
        final expectedAddresses = ['unknown', '192.0.2.43', 'unknown'];

        final header = XForwardedForHeader.parse(values);

        expect(header.addresses, orderedEquals(expectedAddresses));
      });

      test('Given multiple header lines, '
          'when parsed, '
          'then addresses from all lines are combined and split correctly', () {
        final values = ['192.0.2.43, 198.51.100.10', '203.0.113.60, 10.0.0.1'];
        final expectedAddresses = [
          '192.0.2.43',
          '198.51.100.10',
          '203.0.113.60',
          '10.0.0.1',
        ];

        final header = XForwardedForHeader.parse(values);

        expect(header.addresses, orderedEquals(expectedAddresses));
      });

      test('Given empty input values, '
          'when parsed, '
          'then it throws a FormatException', () {
        final values = <String>[];

        expect(
          () => XForwardedForHeader.parse(values),
          throwsA(isA<FormatException>()),
        );
      });

      test('Given input values with only commas or whitespace, '
          'when parsed, '
          'then it throws a FormatException', () {
        final values = [', ,', '   ', ' , '];

        expect(
          () => XForwardedForHeader.parse(values),
          throwsA(isA<FormatException>()),
        );
      });

      test('Given input values that are empty strings, '
          'when parsed, '
          'then it throws a FormatException', () {
        // This case assumes that if X-Forwarded-For header is present
        // with an empty string value (e.g., X-Forwarded-For: ),
        // it's a malformed header. This may be controversial?
        final values = [''];

        expect(
          () => XForwardedForHeader.parse(values),
          throwsA(isA<FormatException>()),
        );
      });

      test('Given input values that are multiple empty strings, '
          'when parsed, '
          'then it throws a FormatException', () {
        final values = [
          '',
          '',
        ]; // Represents multiple X-Forwarded-For: headers that are empty

        expect(
          () => XForwardedForHeader.parse(values),
          throwsA(isA<FormatException>()),
        );
      });

      test('Given IPv6 addresses and obfuscated identifiers, '
          'when parsed, '
          'then they are treated as simple strings', () {
        final values = ['[2001:db8::1], _hidden, 192.0.2.43:8080'];
        final expectedAddresses = [
          '[2001:db8::1]',
          '_hidden',
          '192.0.2.43:8080',
        ]; // XFF doesn't parse ports, it's just a string

        final header = XForwardedForHeader.parse(values);

        expect(header.addresses, orderedEquals(expectedAddresses));
      });
    });

    group('Immutability', () {
      test('Given an XForwardedForHeader, '
          'when attempting to modify addresses list, '
          'then it should throw an UnsupportedError', () {
        final header = XForwardedForHeader(['192.0.2.43']);

        expect(
          () => header.addresses.add('another-ip'),
          throwsA(isA<UnsupportedError>()),
        );
        expect(
          () => header.addresses.clear(),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('Equality and hashCode', () {
      test('Given two XForwardedForHeader instances with the same addresses, '
          'when compared, '
          'then they are equal and have the same hashCode', () {
        final addresses = ['192.0.2.43', '198.51.100.10'];
        final header1 = XForwardedForHeader(
          List.of(addresses),
        ); // Ensure new list
        final header2 = XForwardedForHeader(
          List.of(addresses),
        ); // Ensure new list

        expect(header1, equals(header2));
        expect(header1.hashCode, equals(header2.hashCode));
      });

      test('Given two XForwardedForHeader instances with different addresses, '
          'when compared, '
          'then they are not equal', () {
        final header1 = XForwardedForHeader(['192.0.2.43', '198.51.100.10']);
        final header2 = XForwardedForHeader(['192.0.2.43', '203.0.113.60']);

        expect(header1, isNot(equals(header2)));
      });

      test(
        'Given two XForwardedForHeader instances with addresses in different order, '
        'when compared, '
        'then they are not equal',
        () {
          final header1 = XForwardedForHeader(['192.0.2.43', '198.51.100.10']);
          final header2 = XForwardedForHeader(['198.51.100.10', '192.0.2.43']);

          expect(header1, isNot(equals(header2)));
        },
      );

      test('Given an XForwardedForHeader and a different type, '
          'when compared, '
          'then they are not equal', () {
        final header = XForwardedForHeader(['192.0.2.43']);
        const otherObject = 'not-a-header';

        // ignore: unrelated_type_equality_checks
        expect(header, isNot(equals(otherObject)));
      });
    });

    group('codec', () {
      test('Given an XForwardedForHeader, '
          'when encoded using codec, '
          'then it produces the correct string list', () {
        final header = XForwardedForHeader([
          '192.0.2.43',
          '198.51.100.10',
          'unknown',
        ]);
        final expectedStrings = ['192.0.2.43, 198.51.100.10, unknown'];

        final encoded = XForwardedForHeader.codec.encode(header);

        expect(encoded, orderedEquals(expectedStrings));
      });

      test('Given a list of strings, '
          'when parsed using codec, '
          'then it produces the correct XForwardedForHeader', () {
        final values = ['192.0.2.43, 198.51.100.10', 'unknown, 10.0.0.1'];
        final expectedHeader = XForwardedForHeader([
          '192.0.2.43',
          '198.51.100.10',
          'unknown',
          '10.0.0.1',
        ]);

        final parsed = XForwardedForHeader.codec.decode(values);

        expect(parsed, equals(expectedHeader));
      });

      test('Given an empty list of strings, '
          'when parsed using codec, '
          'then it throws a FormatException', () {
        final values = <String>[];

        expect(
          () => XForwardedForHeader.codec.decode(values),
          throwsA(isA<FormatException>()),
        );
      });

      test(
        'Given a list of strings that result in no valid addresses after parsing, '
        'when parsed using codec, '
        'then it throws a FormatException',
        () {
          final values = [
            ', ',
            '  ',
            ',,',
          ]; // Values that would be filtered out

          expect(
            () => XForwardedForHeader.codec.decode(values),
            throwsA(isA<FormatException>()),
          );
        },
      );
    });
  });
}
