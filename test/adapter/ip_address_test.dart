import 'dart:typed_data';

import 'package:relic/src/adapter/ip_address.dart';
import 'package:test/test.dart';

void main() {
  group('IPAddress', () {
    group('Factory IPAddress.parse()', () {
      test(
          'Given a valid IPv4 string, '
          'when parsed, '
          'then an IPv4Address is returned', () {
        // Arrange
        const addressString = '192.168.1.1';

        // Act
        final ipAddress = IPAddress.parse(addressString);

        // Assert
        expect(ipAddress, isA<IPv4Address>());
        expect(ipAddress.toString(), equals(addressString));
      });

      test(
          'Given a valid IPv6 string, '
          'when parsed, '
          'then an IPv6Address is returned', () {
        // Arrange
        const addressString = '2001:0db8:85a3:0000:0000:8a2e:0370:7334';
        const compressedString = '2001:db8:85a3::8a2e:370:7334';

        // Act
        final ipAddress = IPAddress.parse(addressString);

        // Assert
        expect(ipAddress, isA<IPv6Address>());
        expect(ipAddress.toString(), equals(compressedString));
      });

      test(
          'Given a valid compressed IPv6 string, '
          'when parsed, '
          'then an IPv6Address is returned', () {
        // Arrange
        const addressString = '2001:db8::1';

        // Act
        final ipAddress = IPAddress.parse(addressString);

        // Assert
        expect(ipAddress, isA<IPv6Address>());
        expect(ipAddress.toString(), equals(addressString));
      });
    });

    group('Factory IPAddress.fromBytes()', () {
      test(
          'Given a 4-byte Uint8List, '
          'when IPAddress.fromBytes is called, '
          'then an IPv4Address is returned', () {
        // Arrange
        final bytes = Uint8List.fromList([192, 168, 1, 1]);

        // Act
        final ipAddress = IPAddress.fromBytes(bytes);

        // Assert
        expect(ipAddress, isA<IPv4Address>());
        expect(ipAddress.bytes, equals(bytes));
      });

      test(
          'Given a 16-byte Uint8List, '
          'when IPAddress.fromBytes is called, '
          'then an IPv6Address is returned', () {
        // Arrange
        final bytes = Uint8List.fromList([
          32,
          1,
          13,
          184,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          1
        ]); // 2001:0db8::1

        // Act
        final ipAddress = IPAddress.fromBytes(bytes);

        // Assert
        expect(ipAddress, isA<IPv6Address>());
        expect(ipAddress.bytes, equals(bytes));
      });

      test(
          'Given a Uint8List with an invalid length, '
          'when IPAddress.fromBytes is called, '
          'then an ArgumentError is thrown', () {
        // Arrange
        final bytes = Uint8List.fromList([1, 2, 3]);

        // Act & Assert
        expect(() => IPAddress.fromBytes(bytes), throwsA(isA<ArgumentError>()));
      });
    });

    group('Equality and HashCode', () {
      test(
          'Given two identical IPAddress objects, '
          'when compared, '
          'then they are equal and have the same hashCode', () {
        // Arrange
        final ip1 = IPAddress.parse('192.168.1.1');
        final ip2 = IPAddress.parse('192.168.1.1');

        // Act & Assert
        expect(ip1, equals(ip2));
        expect(ip1.hashCode, equals(ip2.hashCode));

        final ip3 = IPAddress.parse('2001:db8::1');
        final ip4 = IPAddress.parse('2001:db8::1');
        expect(ip3, equals(ip4));
        expect(ip3.hashCode, equals(ip4.hashCode));
      });

      test(
          'Given two different IPAddress objects of the same type, '
          'when compared, '
          'then they are not equal', () {
        // Arrange
        final ip1 = IPAddress.parse('192.168.1.1');
        final ip2 = IPAddress.parse('192.168.1.2');

        // Act & Assert
        expect(ip1, isNot(equals(ip2)));

        final ip3 = IPAddress.parse('2001:db8::1');
        final ip4 = IPAddress.parse('2001:db8::2');
        expect(ip3, isNot(equals(ip4)));
      });

      test(
          'Given two IPAddress objects of different types, '
          'when compared, '
          'then they are not equal', () {
        // Arrange
        final ip1 = IPAddress.parse('127.0.0.1');
        final ip2 = IPAddress.parse('::1'); // IPv6 loopback

        // Act & Assert
        expect(ip1, isNot(equals(ip2)));
      });

      test(
          'Given an IPAddress and a non-IPAddress object, '
          'when compared, '
          'then they are not equal', () {
        // Arrange
        final ip1 = IPAddress.parse('10.0.0.1');
        const otherObject = '10.0.0.1';

        // Act & Assert
        // ignore: unrelated_type_equality_checks
        expect(ip1, isNot(equals(otherObject)));
      });
    });
  });

  group('IPv4Address', () {
    group('Factory IPv4Address._parse (via IPAddress.parse)', () {
      test(
          'Given a valid IPv4 string, '
          'when parsed, '
          'then bytes and toString are correct', () {
        // Arrange
        const addressString = '10.0.0.1';
        final expectedBytes = Uint8List.fromList([10, 0, 0, 1]);

        // Act
        final ipAddress = IPAddress.parse(addressString) as IPv4Address;

        // Assert
        expect(ipAddress.bytes, equals(expectedBytes));
        expect(ipAddress.toString(), equals(addressString));
      });

      test(
          'Given an IPv4 string with too few parts, '
          'when parsed, '
          'then FormatException is thrown', () {
        // Arrange
        const addressString = '192.168.1';

        // Act & Assert
        expect(() => IPAddress.parse(addressString),
            throwsA(isA<FormatException>()));
      });

      test(
          'Given an IPv4 string with too many parts, '
          'when parsed, '
          'then FormatException is thrown', () {
        // Arrange
        const addressString = '192.168.1.1.1';

        // Act & Assert
        expect(() => IPAddress.parse(addressString),
            throwsA(isA<FormatException>()));
      });

      test(
          'Given an IPv4 string with a non-numeric octet, '
          'when parsed, '
          'then FormatException is thrown', () {
        // Arrange
        const addressString = '192.168.a.1';

        // Act & Assert
        expect(() => IPAddress.parse(addressString),
            throwsA(isA<FormatException>()));
      });

      test(
          'Given an IPv4 string with an out-of-range octet (<0), '
          'when parsed, '
          'then FormatException is thrown', () {
        // Arrange
        const addressString = '192.168.-1.1';

        // Act & Assert
        expect(() => IPAddress.parse(addressString),
            throwsA(isA<FormatException>()));
      });

      test(
          'Given an IPv4 string with an out-of-range octet (>255), '
          'when parsed, '
          'then FormatException is thrown', () {
        // Arrange
        const addressString = '192.168.256.1';

        // Act & Assert
        expect(() => IPAddress.parse(addressString),
            throwsA(isA<FormatException>()));
      });
    });

    group('Factory IPv4Address.fromOctets()', () {
      test(
          'Given valid octets, '
          'when created, '
          'then bytes and toString are correct', () {
        // Arrange
        const a = 172, b = 16, c = 0, d = 10;
        final expectedBytes = Uint8List.fromList([172, 16, 0, 10]);
        const expectedString = '172.16.0.10';

        // Act
        final ipAddress = IPv4Address.fromOctets(a, b, c, d);

        // Assert
        expect(ipAddress.bytes, equals(expectedBytes));
        expect(ipAddress.toString(), equals(expectedString));
      });
      // Note: IPv4Address.fromOctets does not validate octet range (0-255)
      // itself but relies on Uint8List.fromList to truncate values.
      // For example, fromOctets(256,0,0,0) would result in 0.0.0.0.
      // This behavior might be acceptable or might need adjustment in the class.
      // Adding a test for this behavior if it's intended.
      test(
          'Given octets out of 0-255 range, '
          'when IPAddress created via IPAddress.fromBytes, '
          'then bytes are truncated (due to Uint8List behavior)', () {
        // Arrange
        const a = 256, b = -1, c = 511, d = 0; // Will be 0, 255, 255, 0
        final expectedBytes = Uint8List.fromList([0, 255, 255, 0]);
        const expectedString = '0.255.255.0';

        // Act
        final ipAddress = IPAddress.fromBytes(Uint8List.fromList([a, b, c, d]));

        // Assert
        expect(ipAddress.bytes, equals(expectedBytes));
        expect(ipAddress.toString(), equals(expectedString));
      });
    });

    test(
        'Given octets out of 0-255 range, '
        'when created, '
        'then ArgumentError is thrown', () {
      expect(
          () => IPv4Address.fromOctets(256, -1, 511, 0), throwsArgumentError);
    });

    group('Factory IPv4Address.fromInt()', () {
      test(
          'Given a valid 32-bit integer, '
          'when created, '
          'then bytes and toString are correct', () {
        // Arrange
        const intValue = 0xC0A80101; // 192.168.1.1
        final expectedBytes = Uint8List.fromList([192, 168, 1, 1]);
        const expectedString = '192.168.1.1';

        // Act
        final ipAddress = IPv4Address.fromInt(intValue);

        // Assert
        expect(ipAddress.bytes, equals(expectedBytes));
        expect(ipAddress.toString(), equals(expectedString));
      });

      test(
          'Given an integer value of 0, '
          'when created, '
          'then it represents 0.0.0.0', () {
        // Arrange
        const intValue = 0;
        final expectedBytes = Uint8List.fromList([0, 0, 0, 0]);
        const expectedString = '0.0.0.0';

        // Act
        final ipAddress = IPv4Address.fromInt(intValue);

        // Assert
        expect(ipAddress.bytes, equals(expectedBytes));
        expect(ipAddress.toString(), equals(expectedString));
      });

      test(
          'Given an integer value of 0xFFFFFFFF, '
          'when created, '
          'then it represents 255.255.255.255', () {
        // Arrange
        const intValue = 0xFFFFFFFF;
        final expectedBytes = Uint8List.fromList([255, 255, 255, 255]);
        const expectedString = '255.255.255.255';

        // Act
        final ipAddress = IPv4Address.fromInt(intValue);

        // Assert
        expect(ipAddress.bytes, equals(expectedBytes));
        expect(ipAddress.toString(), equals(expectedString));
      });

      test(
          'Given an integer less than 0, '
          'when created, '
          'then ArgumentError is thrown', () {
        // Arrange
        const intValue = -1;

        // Act & Assert
        expect(
            () => IPv4Address.fromInt(intValue), throwsA(isA<ArgumentError>()));
      });

      test(
          'Given an integer greater than 0xFFFFFFFF, '
          'when created, '
          'then ArgumentError is thrown', () {
        // Arrange
        const intValue = 0x100000000;

        // Act & Assert
        expect(
            () => IPv4Address.fromInt(intValue), throwsA(isA<ArgumentError>()));
      });
    });

    group('Static Instances', () {
      test(
          'Given IPv4Address.any, '
          'then its value is "0.0.0.0"', () {
        // Act
        final ip = IPv4Address.any;
        // Assert
        expect(ip.toString(), equals('0.0.0.0'));
        expect(ip.bytes, equals(Uint8List.fromList([0, 0, 0, 0])));
      });

      test(
          'Given IPv4Address.loopback, '
          'then its value is "127.0.0.1"', () {
        // Act
        final ip = IPv4Address.loopback;
        // Assert
        expect(ip.toString(), equals('127.0.0.1'));
        expect(ip.bytes, equals(Uint8List.fromList([127, 0, 0, 1])));
      });

      test(
          'Given IPv4Address.broadcast, '
          'then its value is "255.255.255.255"', () {
        // Act
        final ip = IPv4Address.broadcast;
        // Assert
        expect(ip.toString(), equals('255.255.255.255'));
        expect(ip.bytes, equals(Uint8List.fromList([255, 255, 255, 255])));
      });
    });

    test('toString() method caches the string representation', () {
      // Arrange
      final ip = IPv4Address.fromOctets(10, 20, 30, 40);
      final firstCallResult = ip.toString(); // Call it once to cache

      // Act
      // Access the internal _string via a new toString call,
      // assuming it uses the cached value.
      // There's no direct way to check if it's cached without reflection
      // or changing the class, but we can verify consistency.
      final secondCallResult = ip.toString();

      // Assert
      expect(secondCallResult, equals('10.20.30.40'));
      expect(identical(firstCallResult, secondCallResult), isTrue,
          reason: 'toString() should return the same cached String instance.');
    });
  });

  group('IPv6Address', () {
    group('Factory IPv6Address._parse (via IPAddress.parse)', () {
      test(
          'Given a full, uncompressed IPv6 string, '
          'when parsed, '
          'then bytes and compressed toString are correct', () {
        // Arrange
        const addressString = '2001:0db8:85a3:0000:0000:8a2e:0370:7334';
        const expectedCompressedString = '2001:db8:85a3::8a2e:370:7334';
        final expectedBytes = Uint8List.fromList([
          0x20, 0x01, 0x0d, 0xb8, 0x85, 0xa3, 0x00, 0x00, //
          0x00, 0x00, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x34
        ]);

        // Act
        final ipAddress = IPAddress.parse(addressString) as IPv6Address;

        // Assert
        expect(ipAddress.bytes, equals(expectedBytes));
        expect(ipAddress.toString(), equals(expectedCompressedString));
      });

      test(
          'Given an IPv6 string with "::" at the beginning, '
          'when parsed, '
          'then bytes and toString are correct', () {
        // Arrange
        const addressString = '::1'; // Loopback
        const expectedString = '::1';
        final expectedBytes = Uint8List.fromList(
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]);

        // Act
        final ipAddress = IPAddress.parse(addressString) as IPv6Address;

        // Assert
        expect(ipAddress.bytes, equals(expectedBytes));
        expect(ipAddress.toString(), equals(expectedString));
      });

      test(
          'Given an IPv6 string with "::" at the end, '
          'when parsed, '
          'then bytes and toString are correct', () {
        // Arrange
        const addressString = '2001:db8::';
        const expectedString = '2001:db8::';
        final expectedBytes = Uint8List.fromList(
            [0x20, 0x01, 0x0d, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);

        // Act
        final ipAddress = IPAddress.parse(addressString) as IPv6Address;

        // Assert
        expect(ipAddress.bytes, equals(expectedBytes));
        expect(ipAddress.toString(), equals(expectedString));
      });

      test(
          'Given an IPv6 string with "::" in the middle, '
          'when parsed, '
          'then bytes and toString are correct', () {
        // Arrange
        const addressString = '2001:db8:a::b:c';
        const expectedString = '2001:db8:a::b:c';
        final expectedBytes = Uint8List.fromList([
          0x20,
          0x01,
          0x0d,
          0xb8,
          0x00,
          0x0a,
          0,
          0,
          0,
          0,
          0,
          0,
          0x00,
          0x0b,
          0x00,
          0x0c
        ]);

        // Act
        final ipAddress = IPAddress.parse(addressString) as IPv6Address;

        // Assert
        expect(ipAddress.bytes, equals(expectedBytes));
        expect(ipAddress.toString(), equals(expectedString));
      });

      test(
          'Given an IPv6 string "::" (all zeros), '
          'when parsed, '
          'then bytes and toString are correct', () {
        // Arrange
        const addressString = '::';
        const expectedString = '::';
        final expectedBytes = Uint8List.fromList(List.filled(16, 0));

        // Act
        final ipAddress = IPAddress.parse(addressString) as IPv6Address;

        // Assert
        expect(ipAddress.bytes, equals(expectedBytes));
        expect(ipAddress.toString(), equals(expectedString));
      });

      test(
          'Given an IPv6 string with mixed case hex, '
          'when parsed, '
          'then it is handled correctly', () {
        // Arrange
        const addressString = '2001:DB8:aBcD::1234:Ef0';
        const expectedString =
            '2001:db8:abcd::1234:ef0'; // toString normalizes to lowercase
        final expectedBytes = Uint8List.fromList([
          0x20,
          0x01,
          0x0d,
          0xb8,
          0xab,
          0xcd,
          0,
          0,
          0,
          0,
          0,
          0,
          0x12,
          0x34,
          0x0e,
          0xf0
        ]);

        // Act
        final ipAddress = IPAddress.parse(addressString) as IPv6Address;

        // Assert
        expect(ipAddress.bytes, equals(expectedBytes));
        expect(ipAddress.toString(), equals(expectedString));
      });

      test(
          'Given an IPv6 string with more than one "::", '
          'when parsed, '
          'then FormatException is thrown', () {
        // Arrange
        const addressString = '2001::db8::1';

        // Act & Assert
        expect(() => IPAddress.parse(addressString),
            throwsA(isA<FormatException>()));
      });

      test(
          'Given an IPv6 string with too few segments (without "::"), '
          'when parsed, '
          'then FormatException is thrown', () {
        // Arrange
        const addressString = '2001:db8:1:2:3:4:5'; // 7 segments

        // Act & Assert
        expect(() => IPAddress.parse(addressString),
            throwsA(isA<FormatException>()));
      });

      test(
          'Given an IPv6 string with "::" but still too many explicit segments, '
          'when parsed, '
          'then FormatException is thrown', () {
        // Arrange
        const addressString =
            '1:2:3:4::5:6:7:8'; // 8 explicit segments + :: => too many

        // Act & Assert
        expect(() => IPAddress.parse(addressString),
            throwsA(isA<FormatException>()));
      });

      test(
          'Given an IPv6 string with too many segments (parts between colons), '
          'when parsed, '
          'then FormatException is thrown', () {
        // Arrange
        const addressString = '1:2:3:4:5:6:7:8:9'; // 9 segments

        // Act & Assert
        expect(() => IPAddress.parse(addressString),
            throwsA(isA<FormatException>()));
      });

      test(
          'Given an IPv6 string with an invalid (non-hex) segment, '
          'when parsed, '
          'then FormatException is thrown', () {
        // Arrange
        const addressString = '2001:db8:GHIJ::1';

        // Act & Assert
        expect(() => IPAddress.parse(addressString),
            throwsA(isA<FormatException>()));
      });

      test(
          'Given an IPv6 string with a segment value > 0xFFFF, '
          'when parsed, '
          'then FormatException is thrown', () {
        // Arrange
        const addressString = '2001:db8:10000::1';

        // Act & Assert
        expect(() => IPAddress.parse(addressString),
            throwsA(isA<FormatException>()));
      });
      test(
          'Given an IPv6 string with a segment containing > 4 hex chars, '
          'when parsed, '
          'then FormatException is thrown', () {
        // Arrange
        const addressString = '2001:db8:0abcd::1'; // 5 chars in '0abcd'

        // Act & Assert
        expect(() => IPAddress.parse(addressString),
            throwsA(isA<FormatException>()));
      });
    });

    group('Factory IPv6Address.fromSegments()', () {
      test(
          'Given 8 valid 16-bit segments, '
          'when created, '
          'then bytes and toString are correct', () {
        // Arrange
        final segments = Uint16List.fromList(
            [0x2001, 0x0db8, 0x85a3, 0x0000, 0x0000, 0x8a2e, 0x0370, 0x7334]);
        const expectedString = '2001:db8:85a3::8a2e:370:7334';
        final expectedBytes = Uint8List.fromList([
          0x20, 0x01, 0x0d, 0xb8, 0x85, 0xa3, 0x00, 0x00, //
          0x00, 0x00, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x34
        ]);

        // Act
        final ipAddress = IPv6Address.fromSegments(segments);

        // Assert
        expect(ipAddress.bytes, equals(expectedBytes));
        expect(ipAddress.toString(), equals(expectedString));
      });

      test(
          'Given fewer than 8 segments, '
          'when created, '
          'then ArgumentError is thrown', () {
        // Arrange
        final segments = Uint16List.fromList([0x2001, 0x0db8]);

        // Act & Assert
        expect(() => IPv6Address.fromSegments(segments),
            throwsA(isA<ArgumentError>()));
      });

      test(
          'Given more than 8 segments, '
          'when created, '
          'then ArgumentError is thrown', () {
        // Arrange
        final segments = Uint16List.fromList(List.filled(9, 0x1));

        // Act & Assert
        expect(() => IPv6Address.fromSegments(segments),
            throwsA(isA<ArgumentError>()));
      });

      test(
          'Given a segment value < 0, '
          'when created, '
          'then ArgumentError is thrown', () {
        expect(() => IPv6Address.fromHextets(0x2001, -1, 0, 0, 0, 0, 0, 0),
            throwsA(isA<ArgumentError>()));
      });

      test(
          'Given a segment value > 0xFFFF, '
          'when created, '
          'then ArgumentError is thrown', () {
        expect(() => IPv6Address.fromHextets(0x2001, 0x10000, 0, 0, 0, 0, 0, 0),
            throwsA(isA<ArgumentError>()));
      });
    });

    group('segments getter', () {
      test(
          'Given an IPv6Address, '
          'when segments is accessed, '
          'then it returns the correct list of 16-bit integers', () {
        // Arrange
        final expectedSegments = Uint16List.fromList(
            [0x2001, 0x0db8, 0x0000, 0x0000, 0x1234, 0x0000, 0x0000, 0x0001]);
        final ipAddress = IPv6Address.fromSegments(expectedSegments);

        // Act
        final actualSegments = ipAddress.segments;

        // Assert
        expect(actualSegments, orderedEquals(expectedSegments));
      });
    });

    group('toString() compression logic (_compressed getter)', () {
      test(
          'Given an IPv6 address with no zeros, '
          'when toString(), '
          'then it is not compressed', () {
        // Arrange
        final ip = IPv6Address.fromHextets(1, 2, 3, 4, 5, 6, 7, 8);
        // Act & Assert
        expect(ip.toString(), equals('1:2:3:4:5:6:7:8'));
      });

      test(
          'Given an IPv6 address with a single zero segment, '
          'when toString(), '
          'then it is not compressed', () {
        // Arrange
        final ip = IPv6Address.fromHextets(1, 2, 0, 4, 5, 6, 7, 8);
        // Act & Assert
        expect(ip.toString(), equals('1:2:0:4:5:6:7:8'));
      });

      test(
          'Given an IPv6 address with a short run of zeros (length 2), '
          'when toString(), '
          'then it is compressed', () {
        // Arrange
        final ip = IPv6Address.fromHextets(1, 0, 0, 4, 5, 6, 7, 8);
        // Act & Assert
        expect(ip.toString(), equals('1::4:5:6:7:8'));
      });
      test(
          'Given an IPv6 address with zeros at start (length 2), '
          'when toString(), '
          'then it is compressed', () {
        // Arrange
        final ip = IPv6Address.fromHextets(0, 0, 3, 4, 5, 6, 7, 8);
        // Act & Assert
        expect(ip.toString(), equals('::3:4:5:6:7:8'));
      });
      test(
          'Given an IPv6 address with zeros at end (length 2), '
          'when toString(), '
          'then it is compressed', () {
        // Arrange
        final ip = IPv6Address.fromHextets(1, 2, 3, 4, 5, 6, 0, 0);
        // Act & Assert
        expect(ip.toString(), equals('1:2:3:4:5:6::'));
      });

      test(
          'Given an IPv6 address with multiple runs of zeros, '
          'when toString(), '
          'then the longest run is compressed', () {
        // Arrange: 1:0:0:0:5:0:0:8 (longest is 0:0:0)
        final ip = IPv6Address.fromHextets(1, 0, 0, 0, 5, 0, 0, 8);
        // Act & Assert
        expect(ip.toString(), equals('1::5:0:0:8'));
      });

      test(
          'Given an IPv6 address with multiple runs of zeros of equal longest length, '
          'when toString(), '
          'then the first longest run is compressed', () {
        // Arrange: 1:0:0:4:0:0:7:8 (two runs of 0:0)
        final ip = IPv6Address.fromHextets(1, 0, 0, 4, 0, 0, 7, 8);
        // Act & Assert
        expect(ip.toString(), equals('1::4:0:0:7:8'));
      });

      test(
          'Given an IPv6 address of all zeros, '
          'when toString(), '
          'then it is "::"', () {
        // Arrange
        final ip = IPv6Address.any;
        // Act & Assert
        expect(ip.toString(), equals('::'));
      });

      test(
          'Given an IPv6 address like fe80::1:2:3:4, '
          'when toString(), '
          'then it is correct', () {
        // Arrange
        final ip = IPv6Address.fromHextets(0xfe80, 0, 0, 0, 1, 2, 3, 4);
        // Act & Assert
        expect(ip.toString(), equals('fe80::1:2:3:4'));
      });

      test(
          'Given an IPv6 address like 1:2:3:4:0:0:0:0, '
          'when toString(), '
          'then :: is at the end', () {
        // Arrange
        final ip = IPv6Address.fromHextets(1, 2, 3, 4, 0, 0, 0, 0);
        // Act & Assert
        expect(ip.toString(), equals('1:2:3:4::'));
      });

      test(
          'Given an IPv6 address like 0:0:0:0:1:2:3:4, '
          'when toString(), '
          'then :: is at the start', () {
        // Arrange
        final ip = IPv6Address.fromHextets(0, 0, 0, 0, 1, 2, 3, 4);
        // Act & Assert
        expect(ip.toString(), equals('::1:2:3:4'));
      });
    });

    group('Static Instances', () {
      test(
          'Given IPv6Address.any, '
          'then its value is "::"', () {
        // Act
        final ip = IPv6Address.any;
        // Assert
        expect(ip.toString(), equals('::'));
        expect(ip.bytes, equals(Uint8List(16))); // All zeros
      });

      test(
          'Given IPv6Address.loopback, '
          'then its value is "::1"', () {
        // Act
        final ip = IPv6Address.loopback;
        // Assert
        expect(ip.toString(), equals('::1'));
        final expectedBytes = Uint8List(16);
        expectedBytes[15] = 1;
        expect(ip.bytes, equals(expectedBytes));
      });
    });

    test('toString() method caches the string representation', () {
      // Arrange
      final ip = IPv6Address.fromHextets(
          0x2001, 0xdb8, 0, 0, 0, 0, 0, 1); // 2001:db8::1
      final firstCallResult = ip.toString(); // Call it once to cache

      // Act
      final secondCallResult = ip.toString();

      // Assert
      expect(secondCallResult, equals('2001:db8::1'));
      expect(identical(firstCallResult, secondCallResult), isTrue,
          reason: 'toString() should return the same cached String instance.');
    });

    test('Uint8List returned from bytes gettter is immutable', () {
      // Arange
      final ip = IPAddress.parse('::');
      // Act & Assert
      expect(() => ip.bytes[0] = 1, throwsUnsupportedError);
    });

    test('Changing Uint8List passed in ctor has no effect', () {
      // Arange
      final bytes = Uint8List(16);
      final ip = IPAddress.fromBytes(bytes);
      expect(ip, IPv6Address.any);

      // Act
      bytes[0] = 1;

      // Assert
      expect(ip, IPv6Address.any);
      expect(ip.bytes[0], isNot(1));
    });
  });
}
