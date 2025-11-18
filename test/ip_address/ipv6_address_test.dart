import 'dart:typed_data';

import 'package:relic/src/adapter/ip_address.dart';
import 'package:test/test.dart';

void main() {
  group('Factory IPv6Address._parse (via IPAddress.parse)', () {
    test('Given a full, uncompressed IPv6 string, '
        'when parsed, '
        'then bytes and compressed toString are correct', () {
      const addressString = '2001:0db8:85a3:0000:0000:8a2e:0370:7334';
      const expectedCompressedString = '2001:db8:85a3::8a2e:370:7334';
      final expectedBytes = Uint8List.fromList([
        0x20, 0x01, 0x0d, 0xb8, 0x85, 0xa3, 0x00, 0x00, //
        0x00, 0x00, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x34,
      ]);

      final ipAddress = IPAddress.parse(addressString) as IPv6Address;

      expect(ipAddress.bytes, equals(expectedBytes));
      expect(ipAddress.toString(), equals(expectedCompressedString));
    });

    test('Given an IPv6 string with "::" at the beginning, '
        'when parsed, '
        'then bytes and toString are correct', () {
      const addressString = '::1'; // Loopback
      const expectedString = '::1';
      final expectedBytes = Uint8List.fromList([
        0, 0, 0, 0, // ::
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 1, // 1
      ]);

      final ipAddress = IPAddress.parse(addressString) as IPv6Address;

      expect(ipAddress.bytes, equals(expectedBytes));
      expect(ipAddress.toString(), equals(expectedString));
    });

    test('Given an IPv6 string with "::" at the end, '
        'when parsed, '
        'then bytes and toString are correct', () {
      const addressString = '2001:db8::';
      const expectedString = '2001:db8::';
      final expectedBytes = Uint8List.fromList([
        0x20, 0x01, 0x0d, 0xb8, // 2001:db8
        0, 0, 0, 0, // ::
        0, 0, 0, 0,
        0, 0, 0, 0,
      ]);

      final ipAddress = IPAddress.parse(addressString) as IPv6Address;

      expect(ipAddress.bytes, equals(expectedBytes));
      expect(ipAddress.toString(), equals(expectedString));
    });

    test('Given an IPv6 string with "::" in the middle, '
        'when parsed, '
        'then bytes and toString are correct', () {
      const addressString = '2001:db8:a::b:c';
      const expectedString = '2001:db8:a::b:c';
      final expectedBytes = Uint8List.fromList([
        0x20, 0x01, 0x0d, 0xb8, // 2001:db8
        0x00, 0x0a, 0, 0, // a
        0, 0, 0, 0, // ::
        0x00, 0x0b, 0x00, 0x0c, // b:c
      ]);

      final ipAddress = IPAddress.parse(addressString) as IPv6Address;

      expect(ipAddress.bytes, equals(expectedBytes));
      expect(ipAddress.toString(), equals(expectedString));
    });

    test('Given an IPv6 string "::" (all zeros), '
        'when parsed, '
        'then bytes and toString are correct', () {
      const addressString = '::';
      const expectedString = '::';
      final expectedBytes = Uint8List.fromList(List.filled(16, 0));

      final ipAddress = IPAddress.parse(addressString) as IPv6Address;

      expect(ipAddress.bytes, equals(expectedBytes));
      expect(ipAddress.toString(), equals(expectedString));
    });

    test('Given an IPv6 string with mixed case hex, '
        'when parsed, '
        'then it is handled correctly', () {
      const addressString = '2001:DB8:aBcD::1234:Ef0';
      const expectedString =
          '2001:db8:abcd::1234:ef0'; // toString normalizes to lowercase
      final expectedBytes = Uint8List.fromList([
        0x20, 0x01, 0x0d, 0xb8, // 2001:db8
        0xab, 0xcd, 0, 0, // abcd
        0, 0, 0, 0, // ::
        0x12, 0x34, 0x0e, 0xf0, // 1234:ef0
      ]);

      final ipAddress = IPAddress.parse(addressString) as IPv6Address;

      expect(ipAddress.bytes, equals(expectedBytes));
      expect(ipAddress.toString(), equals(expectedString));
    });

    test('Given an IPv6 string with more than one "::", '
        'when parsed, '
        'then FormatException is thrown', () {
      const addressString = '2001::db8::1';

      expect(
        () => IPAddress.parse(addressString),
        throwsA(isA<FormatException>()),
      );
    });

    test('Given an IPv6 string with too few segments (without "::"), '
        'when parsed, '
        'then FormatException is thrown', () {
      const addressString = '2001:db8:1:2:3:4:5'; // 7 segments

      expect(
        () => IPAddress.parse(addressString),
        throwsA(isA<FormatException>()),
      );
    });

    test('Given an IPv6 string with "::" but still too many explicit segments, '
        'when parsed, '
        'then FormatException is thrown', () {
      const addressString =
          '1:2:3:4::5:6:7:8'; // 8 explicit segments + :: => too many

      expect(
        () => IPAddress.parse(addressString),
        throwsA(isA<FormatException>()),
      );
    });

    test('Given an IPv6 string with too many segments (parts between colons), '
        'when parsed, '
        'then FormatException is thrown', () {
      const addressString = '1:2:3:4:5:6:7:8:9'; // 9 segments

      expect(
        () => IPAddress.parse(addressString),
        throwsA(isA<FormatException>()),
      );
    });

    test('Given an IPv6 string with an invalid (non-hex) segment, '
        'when parsed, '
        'then FormatException is thrown', () {
      const addressString = '2001:db8:GHIJ::1';

      expect(
        () => IPAddress.parse(addressString),
        throwsA(isA<FormatException>()),
      );
    });

    test('Given an IPv6 string with a segment value > 0xFFFF, '
        'when parsed, '
        'then FormatException is thrown', () {
      const addressString = '2001:db8:10000::1';

      expect(
        () => IPAddress.parse(addressString),
        throwsA(isA<FormatException>()),
      );
    });
    test('Given an IPv6 string with a segment containing > 4 hex chars, '
        'when parsed, '
        'then FormatException is thrown', () {
      const addressString = '2001:db8:0abcd::1'; // 5 chars in '0abcd'

      expect(
        () => IPAddress.parse(addressString),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Factory IPv6Address.fromSegments()', () {
    test('Given 8 valid 16-bit segments, '
        'when created, '
        'then bytes and toString are correct', () {
      final segments = Uint16List.fromList([
        0x2001, 0x0db8, 0x85a3, 0x0000, //
        0x0000, 0x8a2e, 0x0370, 0x7334,
      ]);
      const expectedString = '2001:db8:85a3::8a2e:370:7334';
      final expectedBytes = Uint8List.fromList([
        0x20, 0x01, 0x0d, 0xb8, 0x85, 0xa3, 0x00, 0x00, //
        0x00, 0x00, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x34,
      ]);

      final ipAddress = IPv6Address.fromSegments(segments);

      expect(ipAddress.bytes, equals(expectedBytes));
      expect(ipAddress.toString(), equals(expectedString));
    });

    test('Given fewer than 8 segments, '
        'when created, '
        'then ArgumentError is thrown', () {
      final segments = Uint16List.fromList([0x2001, 0x0db8]);

      expect(
        () => IPv6Address.fromSegments(segments),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Given more than 8 segments, '
        'when created, '
        'then ArgumentError is thrown', () {
      final segments = Uint16List.fromList(List.filled(9, 0x1));

      expect(
        () => IPv6Address.fromSegments(segments),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Given a segment value < 0, '
        'when created, '
        'then ArgumentError is thrown', () {
      expect(
        () => IPv6Address.fromHextets(0x2001, -1, 0, 0, 0, 0, 0, 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Given a segment value > 0xFFFF, '
        'when created, '
        'then ArgumentError is thrown', () {
      expect(
        () => IPv6Address.fromHextets(0x2001, 0x10000, 0, 0, 0, 0, 0, 0),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('segments getter', () {
    test('Given an IPv6Address, '
        'when segments is accessed, '
        'then it returns the correct list of 16-bit integers', () {
      final expectedSegments = Uint16List.fromList([
        0x2001, 0x0db8, 0x0000, 0x0000, 0x1234, 0x0000, 0x0000, 0x0001, //
      ]);
      final ipAddress = IPv6Address.fromSegments(expectedSegments);

      final actualSegments = ipAddress.segments;

      expect(actualSegments, orderedEquals(expectedSegments));
    });
  });

  group('toString() compression logic (_compressed getter)', () {
    test('Given an IPv6 address with no zeros, '
        'when toString(), '
        'then it is not compressed', () {
      final ip = IPv6Address.fromHextets(1, 2, 3, 4, 5, 6, 7, 8);

      expect(ip.toString(), equals('1:2:3:4:5:6:7:8'));
    });

    test('Given an IPv6 address with a single zero segment, '
        'when toString(), '
        'then it is not compressed', () {
      final ip = IPv6Address.fromHextets(1, 2, 0, 4, 5, 6, 7, 8);

      expect(ip.toString(), equals('1:2:0:4:5:6:7:8'));
    });

    test('Given an IPv6 address with a short run of zeros (length 2), '
        'when toString(), '
        'then it is compressed', () {
      final ip = IPv6Address.fromHextets(1, 0, 0, 4, 5, 6, 7, 8);

      expect(ip.toString(), equals('1::4:5:6:7:8'));
    });
    test('Given an IPv6 address with zeros at start (length 2), '
        'when toString(), '
        'then it is compressed', () {
      final ip = IPv6Address.fromHextets(0, 0, 3, 4, 5, 6, 7, 8);

      expect(ip.toString(), equals('::3:4:5:6:7:8'));
    });
    test('Given an IPv6 address with zeros at end (length 2), '
        'when toString(), '
        'then it is compressed', () {
      final ip = IPv6Address.fromHextets(1, 2, 3, 4, 5, 6, 0, 0);

      expect(ip.toString(), equals('1:2:3:4:5:6::'));
    });

    test('Given an IPv6 address with multiple runs of zeros, '
        'when toString(), '
        'then the longest run is compressed', () {
      final ip = IPv6Address.fromHextets(1, 0, 0, 0, 5, 0, 0, 8);

      expect(ip.toString(), equals('1::5:0:0:8'));
    });

    test(
      'Given an IPv6 address with multiple runs of zeros of equal longest length, '
      'when toString(), '
      'then the first longest run is compressed',
      () {
        final ip = IPv6Address.fromHextets(1, 0, 0, 4, 0, 0, 7, 8);

        expect(ip.toString(), equals('1::4:0:0:7:8'));
      },
    );

    test('Given an IPv6 address of all zeros, '
        'when toString(), '
        'then it is "::"', () {
      final ip = IPv6Address.any;

      expect(ip.toString(), equals('::'));
    });

    test('Given an IPv6 address like fe80::1:2:3:4, '
        'when toString(), '
        'then it is correct', () {
      final ip = IPv6Address.fromHextets(0xfe80, 0, 0, 0, 1, 2, 3, 4);

      expect(ip.toString(), equals('fe80::1:2:3:4'));
    });

    test('Given an IPv6 address like 1:2:3:4:0:0:0:0, '
        'when toString(), '
        'then :: is at the end', () {
      final ip = IPv6Address.fromHextets(1, 2, 3, 4, 0, 0, 0, 0);

      expect(ip.toString(), equals('1:2:3:4::'));
    });

    test('Given an IPv6 address like 0:0:0:0:1:2:3:4, '
        'when toString(), '
        'then :: is at the start', () {
      final ip = IPv6Address.fromHextets(0, 0, 0, 0, 1, 2, 3, 4);

      expect(ip.toString(), equals('::1:2:3:4'));
    });
  });

  group('Static Instances', () {
    test('Given IPv6Address.any, '
        'then its value is "::"', () {
      final ip = IPv6Address.any;

      expect(ip.toString(), equals('::'));
      expect(ip.bytes, equals(Uint8List(16))); // All zeros
    });

    test('Given IPv6Address.loopback, '
        'then its value is "::1"', () {
      final ip = IPv6Address.loopback;

      expect(ip.toString(), equals('::1'));
      final expectedBytes = Uint8List(16);
      expectedBytes[15] = 1;
      expect(ip.bytes, equals(expectedBytes));
    });
  });

  test('toString() method caches the string representation', () {
    final ip = IPv6Address.fromHextets(0x2001, 0xdb8, 0, 0, 0, 0, 0, 1);
    final firstCallResult = ip.toString(); // Call it once to cache

    final secondCallResult = ip.toString();

    expect(secondCallResult, equals('2001:db8::1'));
    expect(
      identical(firstCallResult, secondCallResult),
      isTrue,
      reason: 'toString() should return the same cached String instance.',
    );
  });

  test('Uint8List returned from bytes getter is immutable', () {
    final ip = IPAddress.parse('::');

    expect(() => ip.bytes[0] = 1, throwsUnsupportedError);
  });

  test('Changing Uint8List passed in ctor has no effect', () {
    final bytes = Uint8List(16);
    final ip = IPAddress.fromBytes(bytes);
    expect(ip, IPv6Address.any);

    bytes[0] = 1;

    expect(ip, IPv6Address.any);
    expect(ip.bytes[0], isNot(1));
  });
}
