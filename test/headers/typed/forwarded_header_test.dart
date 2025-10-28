import 'package:relic/relic.dart';
import 'package:test/test.dart';

void main() {
  group('ForwardedHeader Parsing Logic', () {
    group('Given single forwarded-element strings,', () {
      test(
        'when parsing "for=_gazonk", '
        'then the ForwardedHeader contains one element with a ForwardedNode for "for".',
        () {
          const headerValue = 'for="_gazonk"';
          const expectedNode = ForwardedIdentifier('_gazonk');

          final parsedHeader = ForwardedHeader.parse([headerValue]);

          expect(parsedHeader, isNotNull);
          expect(parsedHeader.elements, hasLength(1));
          final element = parsedHeader.elements.first;
          expect(element.forwardedFor, equals(expectedNode));
          expect(element.by, isNull);
          expect(element.host, isNull);
          expect(element.proto, isNull);
          expect(element.extensions, isNull);
        },
      );

      test(
        'when parsing \'For="[2001:db8:cafe::17]:4711"\', '
        'then the ForwardedHeader contains one element with an IPv6 ForwardedNode for "for".',
        () {
          const headerValue = 'For="[2001:db8:cafe::17]:4711"';
          const expectedNode = ForwardedIdentifier(
            '[2001:db8:cafe::17]',
            '4711',
          );

          final parsedHeader = ForwardedHeader.parse([headerValue]);

          expect(parsedHeader, isNotNull);
          expect(parsedHeader.elements, hasLength(1));
          final element = parsedHeader.elements.first;
          expect(element.forwardedFor, equals(expectedNode));
        },
      );

      test('when parsing "for=192.0.2.60;proto=http;by=203.0.113.43", '
          'then all parameters are correctly parsed.', () {
        const headerValue = 'for=192.0.2.60;proto=http;by=203.0.113.43';
        const expectedForNode = ForwardedIdentifier('192.0.2.60');
        const expectedByNode = ForwardedIdentifier('203.0.113.43');

        final parsedHeader = ForwardedHeader.parse([headerValue]);

        expect(parsedHeader, isNotNull);
        expect(parsedHeader.elements, hasLength(1));
        final element = parsedHeader.elements.first;
        expect(element.forwardedFor, equals(expectedForNode));
        expect(element.proto, equals('http'));
        expect(element.by, equals(expectedByNode));
        expect(element.host, isNull);
      });

      test('when parsing "by=example.com;host=myhost.local;ext=foo", '
          'then by, host, and extension parameters are correctly parsed.', () {
        const headerValue = 'by=example.com;host=myhost.local;ext=foo';
        const expectedByNode = ForwardedIdentifier('example.com');

        final parsedHeader = ForwardedHeader.parse([headerValue]);

        expect(parsedHeader, isNotNull);
        expect(parsedHeader.elements, hasLength(1));
        final element = parsedHeader.elements.first;
        expect(element.by, equals(expectedByNode));
        expect(element.host, equals('myhost.local'));
        expect(element.extensions, isNotNull);
        expect(element.extensions, containsPair('ext', 'foo'));
        expect(element.forwardedFor, isNull);
        expect(element.proto, isNull);
      });

      test('when parsing "for=unknown", '
          'then the "for" node is "unknown".', () {
        const headerValue = 'for=unknown';
        const expectedNode = ForwardedIdentifier('unknown');

        final parsedHeader = ForwardedHeader.parse([headerValue]);

        expect(parsedHeader, isNotNull);
        expect(parsedHeader.elements.first.forwardedFor, equals(expectedNode));
      });

      test(
        'when parsing with mixed case parameter names like "FoR=1.2.3.4;PrOtO=https", '
        'then parameters are parsed case-insensitively.',
        () {
          const headerValue = 'FoR=1.2.3.4;PrOtO=https';
          const expectedForNode = ForwardedIdentifier('1.2.3.4');

          final parsedHeader = ForwardedHeader.parse([headerValue]);

          expect(parsedHeader, isNotNull);
          expect(parsedHeader.elements, hasLength(1));
          final element = parsedHeader.elements.first;
          expect(element.forwardedFor, equals(expectedForNode));
          expect(element.proto, equals('https'));
        },
      );
    });

    group('Given multiple forwarded-element strings,', () {
      test('when parsing "for=192.0.2.43, for=198.51.100.17", '
          'then two elements are parsed correctly.', () {
        const headerValue = 'for=192.0.2.43, for=198.51.100.17';
        const expectedNode1 = ForwardedIdentifier('192.0.2.43');
        const expectedNode2 = ForwardedIdentifier('198.51.100.17');

        final parsedHeader = ForwardedHeader.parse([headerValue]);

        expect(parsedHeader, isNotNull);
        expect(parsedHeader.elements, hasLength(2));
        expect(parsedHeader.elements[0].forwardedFor, equals(expectedNode1));
        expect(parsedHeader.elements[1].forwardedFor, equals(expectedNode2));
      });

      test(
        'when parsing from multiple header lines ["for=client1", "for=proxy1"], '
        'then they are combined and parsed as two elements.',
        () {
          // Simulates multiple header fields
          final headerValues = ['for=client1', 'for=proxy1'];
          const expectedNode1 = ForwardedIdentifier('client1');
          const expectedNode2 = ForwardedIdentifier('proxy1');

          // ForwardedHeader.parse internally joins with ", " which simulates HTTP combining them
          final parsedHeader = ForwardedHeader.parse(headerValues);

          expect(parsedHeader, isNotNull);
          expect(parsedHeader.elements, hasLength(2));
          expect(parsedHeader.elements[0].forwardedFor, equals(expectedNode1));
          expect(parsedHeader.elements[1].forwardedFor, equals(expectedNode2));
        },
      );

      test(
        'when parsing complex mixed elements "for=a;host=x, by=b;proto=y, for=c;ext=z", '
        'then all elements and their parameters are parsed.',
        () {
          const headerValue = 'for=a;host=x, by=b;proto=y, for=c;ext=z';

          final parsedHeader = ForwardedHeader.parse([headerValue]);

          expect(parsedHeader, isNotNull);
          expect(parsedHeader.elements, hasLength(3));

          final el1 = parsedHeader.elements[0];
          expect(el1.forwardedFor, equals(const ForwardedIdentifier('a')));
          expect(el1.host, equals('x'));
          expect(el1.by, isNull);
          expect(el1.proto, isNull);
          expect(el1.extensions, isNull);

          final el2 = parsedHeader.elements[1];
          expect(el2.by, equals(const ForwardedIdentifier('b')));
          expect(el2.proto, equals('y'));
          expect(el2.forwardedFor, isNull);
          expect(el2.host, isNull);
          expect(el2.extensions, isNull);

          final el3 = parsedHeader.elements[2];
          expect(el3.forwardedFor, equals(const ForwardedIdentifier('c')));
          expect(el3.extensions, containsPair('ext', 'z'));
          expect(el3.by, isNull);
          expect(el3.host, isNull);
          expect(el3.proto, isNull);
        },
      );
    });

    group('Given quoted values,', skip: 'Quoted values are not handled correctly yet', () {
      test('when parsing \'host="example.com, inc."\', '
          'then host is parsed as "example.com, inc."', () {
        const headerValue = 'host="example.com, inc."';

        final parsedHeader = ForwardedHeader.parse([headerValue]);

        expect(parsedHeader, isNotNull);
        expect(parsedHeader.elements, hasLength(1));
        expect(parsedHeader.elements.first.host, equals('example.com, inc.'));
      });

      test('when parsing \'ext="value with ; semicolon"\', '
          'then ext is parsed as "value with ; semicolon"', () {
        const headerValue = 'ext="value with ; semicolon"';

        final parsedHeader = ForwardedHeader.parse([headerValue]);

        expect(parsedHeader, isNotNull);
        expect(parsedHeader.elements, hasLength(1));
        expect(parsedHeader.elements.first.extensions, isNotNull);
        expect(
          parsedHeader.elements.first.extensions,
          containsPair('ext', 'value with ; semicolon'),
        );
      });

      test(
        'when parsing \'param1="val1"; param2="val2,still_val2"; param3="val3"\', '
        'then param2 is currently split if simple split is used after unquoting for params (KNOWN LIMITATION).',
        () {
          const headerValueForElementSplit =
              'for="user,group", host=example.com';

          final parsed = ForwardedHeader.parse([headerValueForElementSplit]);

          // Assert for element split (this demonstrates the current simplified behavior)
          // String.split(',') on 'for="user,group", host=example.com' yields:
          // 1. 'for="user' --> ForwardedElement(forwardedFor: ForwardedNode('user'))
          // 2. 'group"'   --> ForwardedElement() (empty, as 'group"' is not a valid pair)
          // 3. ' host=example.com' --> ForwardedElement(host: 'example.com')
          // This is because splitTrimAndFilterUnique (which relies on String.split(',')) is not quote-aware.
          expect(parsed.elements, hasLength(1));
          final element = parsed.elements[0];
          expect(element.forwardedFor, const ForwardedIdentifier('user,group'));
          expect(element.host, 'example.com');
          expect(element.by, isNull);
          expect(element.proto, isNull);
          expect(element.extensions, isNull);
        },
      );
    });

    group('Error Handling and Edge Cases,', () {
      test('Given completely empty header values, '
          'when parsing, '
          'then FormatException is thrown by ForwardedHeader.parse.', () {
        final headerValues = <String>[]; // No values

        expect(
          () => ForwardedHeader.parse(headerValues),
          throwsA(isA<FormatException>()),
        );
      });

      test('Given header values that are empty strings or only whitespace, '
          'when parsing, '
          'then FormatException is thrown', () {
        final headerValues = ['', '   '];

        // splitTrimAndFilterUnique will result in an empty list for ForwardedHeader.parse
        expect(
          () => ForwardedHeader.parse(headerValues),
          throwsA(isA<FormatException>()),
        );
      });

      test('Given malformed pairs like "for=", "keyonly", or "=value", '
          'when parsing, '
          'then they are currently ignored by the pair splitting logic.', () {
        const headerValue = 'for=1.2.3.4;keyonly;by=;proto=http;=novalue';

        final parsedHeader = ForwardedHeader.parse([headerValue]);

        // The pairs 'keyonly', 'by=', and '=novalue' will be skipped because parts.length != 2.
        expect(parsedHeader, isNotNull);
        expect(parsedHeader.elements, hasLength(1));
        final element = parsedHeader.elements.first;
        expect(
          element.forwardedFor,
          equals(const ForwardedIdentifier('1.2.3.4')),
        );
        expect(element.proto, equals('http'));
        expect(element.by, isNull); // 'by=' results in no 'by' node
        expect(element.extensions, isNull);
      });
    });
  });

  group('ForwardedHeader Encoding Logic', () {
    test('Given a ForwardedHeader with one element (for, proto, by), '
        'when toStrings() is called, '
        'then it returns the correct string representation.', () {
      final element = ForwardedElement(
        forwardedFor: const ForwardedIdentifier('192.0.2.60'),
        proto: 'http',
        by: const ForwardedIdentifier('203.0.113.43'),
      );
      final header = ForwardedHeader([element]);
      const expectedString = 'for=192.0.2.60;by=203.0.113.43;proto=http';

      final encoded = header.toStrings();

      expect(encoded, equals([expectedString]));
    });

    test('Given a ForwardedHeader with an IPv6 address that needs quoting, '
        'when toStrings() is called, '
        'then the IPv6 address is quoted.', () {
      final element = ForwardedElement(
        forwardedFor: const ForwardedIdentifier('[2001:db8::1]', '8080'),
        host: 'example.com',
      );
      final header = ForwardedHeader([element]);
      // _formatValueForPair will quote "[2001:db8::1]:8080" because it contains ':' and '[' ']'
      const expectedString = 'for="[2001:db8::1]:8080";host=example.com';

      final encoded = header.toStrings();

      expect(encoded, equals([expectedString]));
    });

    test('Given a ForwardedHeader with multiple elements, '
        'when toStrings() is called, '
        'then elements are comma-separated.', () {
      final element1 = ForwardedElement(
        forwardedFor: const ForwardedIdentifier('client1'),
      );
      final element2 = ForwardedElement(
        by: const ForwardedIdentifier('proxy1'),
        proto: 'https',
      );
      final header = ForwardedHeader([element1, element2]);
      const expectedString = 'for=client1, by=proxy1;proto=https';

      final encoded = header.toStrings();

      expect(encoded, equals([expectedString]));
    });

    test('Given a ForwardedHeader with extension parameters, '
        'when toStrings() is called, '
        'then extensions are included.', () {
      final element = ForwardedElement(
        forwardedFor: const ForwardedIdentifier('10.0.0.1'),
        extensions: {'secret': 'foo', 'other-ext': '"bar"'},
      );
      final header = ForwardedHeader([element]);
      // Order of extensions is not guaranteed by CaseInsensitiveMap, so test flexibly
      final resultString = header.toStrings().first;

      expect(resultString, contains('for=10.0.0.1'));
      // The value '\"bar\"' is not a token, so _formatValueForPair will quote it:
      // it becomes "\"\\\"bar\\\"\""
      // Check for presence of both parts, order might vary.
      expect(resultString, contains('secret=foo'));
      expect(resultString, contains('other-ext="\\"bar\\""'));
    });

    test(
      'Given a ForwardedHeader with a value requiring quoting (e.g. host with space), '
      'when toStrings() is called, '
      'then the value is quoted.',
      () {
        final element = ForwardedElement(host: 'my server');
        final header = ForwardedHeader([element]);
        const expectedString = 'host="my server"';

        final encoded = header.toStrings();

        expect(encoded, equals([expectedString]));
      },
    );
  });

  group('ForwardedNode Parsing Logic', () {
    test('Given "192.0.2.43", '
        'when ForwardedNode.parse is called, '
        'then identifier is "192.0.2.43" and port is null.', () {
      final node = ForwardedIdentifier.parse('192.0.2.43');
      expect(node.identifier, equals('192.0.2.43'));
      expect(node.port, isNull);
    });

    test('Given "192.0.2.43:8080", '
        'when ForwardedNode.parse is called, '
        'then identifier is "192.0.2.43" and port is "8080".', () {
      final node = ForwardedIdentifier.parse('192.0.2.43:8080');
      expect(node.identifier, equals('192.0.2.43'));
      expect(node.port, equals('8080'));
    });

    test('Given "[2001:db8::1]", '
        'when ForwardedNode.parse is called, '
        'then identifier is "[2001:db8::1]" and port is null.', () {
      final node = ForwardedIdentifier.parse('[2001:db8::1]');
      expect(node.identifier, equals('[2001:db8::1]'));
      expect(node.port, isNull);
    });

    test('Given "[2001:db8::1]:4711", '
        'when ForwardedNode.parse is called, '
        'then identifier is "[2001:db8::1]" and port is "4711".', () {
      final node = ForwardedIdentifier.parse('[2001:db8::1]:4711');
      expect(node.identifier, equals('[2001:db8::1]'));
      expect(node.port, equals('4711'));
    });

    test('Given "unknown", '
        'when ForwardedNode.parse is called, '
        'then identifier is "unknown" and port is null.', () {
      final node = ForwardedIdentifier.parse('unknown');
      expect(node.identifier, equals('unknown'));
      expect(node.port, isNull);
    });

    test('Given "_obfuscated", '
        'when ForwardedNode.parse is called, '
        'then identifier is "_obfuscated" and port is null.', () {
      final node = ForwardedIdentifier.parse('_obfuscated');
      expect(node.identifier, equals('_obfuscated'));
      expect(node.port, isNull);
    });

    test('Given "_obfuscated:_obfport", '
        'when ForwardedNode.parse is called, '
        'then identifier is "_obfuscated" and port is "_obfport".', () {
      final node = ForwardedIdentifier.parse('_obfuscated:_obfport');
      expect(node.identifier, equals('_obfuscated'));
      expect(node.port, equals('_obfport'));
    });

    test(
      'Given a malformed IPv6 like "[::1:8080" (missing closing bracket for address part), '
      'when ForwardedNode.parse is called, '
      'then it is treated as a simple identifier.',
      () {
        // This doesn't match the strict IPv6 w/port pattern
        final node = ForwardedIdentifier.parse('[::1:8080');
        expect(node.identifier, equals('[::1:8080'));
        expect(node.port, isNull);
      },
    );
    test('Given a malformed IPv6 with port like "[2001:db8::1]:8000:extra", '
        'when ForwardedNode.parse is called, '
        'then it takes the whole string as identifier.', () {
      final node = ForwardedIdentifier.parse('[2001:db8::1]:8000:extra');
      // This won't match the specific "[IPv6]:port" logic due to the extra colon.
      expect(node.identifier, equals('[2001:db8::1]:8000:extra'));
      expect(node.port, isNull);
    });
  });
}
