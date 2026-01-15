import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('Factory IPv4Address._parse (via IPAddress.parse)', () {
    test('Given a valid IPv4 string, '
        'when parsed, '
        'then bytes and toString are correct', () {
      const addressString = '10.0.0.1';
      final expectedBytes = Uint8List.fromList([10, 0, 0, 1]);

      final ipAddress = IPAddress.parse(addressString) as IPv4Address;

      expect(ipAddress.bytes, equals(expectedBytes));
      expect(ipAddress.toString(), equals(addressString));
    });

    test('Given an IPv4 string with too few parts, '
        'when parsed, '
        'then FormatException is thrown', () {
      const addressString = '192.168.1';

      expect(
        () => IPAddress.parse(addressString),
        throwsA(isA<FormatException>()),
      );
    });

    test('Given an IPv4 string with too many parts, '
        'when parsed, '
        'then FormatException is thrown', () {
      const addressString = '192.168.1.1.1';

      expect(
        () => IPAddress.parse(addressString),
        throwsA(isA<FormatException>()),
      );
    });

    test('Given an IPv4 string with a non-numeric octet, '
        'when parsed, '
        'then FormatException is thrown', () {
      const addressString = '192.168.a.1';

      expect(
        () => IPAddress.parse(addressString),
        throwsA(isA<FormatException>()),
      );
    });

    test('Given an IPv4 string with an out-of-range octet (<0), '
        'when parsed, '
        'then FormatException is thrown', () {
      const addressString = '192.168.-1.1';

      expect(
        () => IPAddress.parse(addressString),
        throwsA(isA<FormatException>()),
      );
    });

    test('Given an IPv4 string with an out-of-range octet (>255), '
        'when parsed, '
        'then FormatException is thrown', () {
      const addressString = '192.168.256.1';

      expect(
        () => IPAddress.parse(addressString),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Factory IPv4Address.fromOctets()', () {
    test('Given valid octets, '
        'when created, '
        'then bytes and toString are correct', () {
      const a = 172, b = 16, c = 0, d = 10;
      final expectedBytes = Uint8List.fromList([172, 16, 0, 10]);
      const expectedString = '172.16.0.10';

      final ipAddress = IPv4Address.fromOctets(a, b, c, d);

      expect(ipAddress.bytes, equals(expectedBytes));
      expect(ipAddress.toString(), equals(expectedString));
    });

    test('Given octets out of 0-255 range, '
        'when IPAddress created via IPAddress.fromBytes, '
        'then bytes are truncated (due to Uint8List behavior)', () {
      const a = 256, b = -1, c = 511, d = 0; // Will be 0, 255, 255, 0
      final expectedBytes = Uint8List.fromList([0, 255, 255, 0]);
      const expectedString = '0.255.255.0';

      final ipAddress = IPAddress.fromBytes(Uint8List.fromList([a, b, c, d]));

      expect(ipAddress.bytes, equals(expectedBytes));
      expect(ipAddress.toString(), equals(expectedString));
    });
  });

  test('Given octets out of 0-255 range, '
      'when created, '
      'then ArgumentError is thrown', () {
    expect(() => IPv4Address.fromOctets(256, -1, 511, 0), throwsArgumentError);
  });

  group('Factory IPv4Address.fromInt()', () {
    test('Given a valid 32-bit integer, '
        'when created, '
        'then bytes and toString are correct', () {
      const intValue = 0xC0A80101; // 192.168.1.1
      final expectedBytes = Uint8List.fromList([192, 168, 1, 1]);
      const expectedString = '192.168.1.1';

      final ipAddress = IPv4Address.fromInt(intValue);

      expect(ipAddress.bytes, equals(expectedBytes));
      expect(ipAddress.toString(), equals(expectedString));
    });

    test('Given an integer value of 0, '
        'when created, '
        'then it represents 0.0.0.0', () {
      const intValue = 0;
      final expectedBytes = Uint8List.fromList([0, 0, 0, 0]);
      const expectedString = '0.0.0.0';

      final ipAddress = IPv4Address.fromInt(intValue);

      expect(ipAddress.bytes, equals(expectedBytes));
      expect(ipAddress.toString(), equals(expectedString));
    });

    test('Given an integer value of 0xFFFFFFFF, '
        'when created, '
        'then it represents 255.255.255.255', () {
      const intValue = 0xFFFFFFFF;
      final expectedBytes = Uint8List.fromList([255, 255, 255, 255]);
      const expectedString = '255.255.255.255';

      final ipAddress = IPv4Address.fromInt(intValue);

      expect(ipAddress.bytes, equals(expectedBytes));
      expect(ipAddress.toString(), equals(expectedString));
    });

    test('Given an integer less than 0, '
        'when created, '
        'then ArgumentError is thrown', () {
      const intValue = -1;

      expect(
        () => IPv4Address.fromInt(intValue),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Given an integer greater than 0xFFFFFFFF, '
        'when created, '
        'then ArgumentError is thrown', () {
      const intValue = 0x100000000;

      expect(
        () => IPv4Address.fromInt(intValue),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Static Instances', () {
    test('Given IPv4Address.any, '
        'then its value is "0.0.0.0"', () {
      final ip = IPv4Address.any;

      expect(ip.toString(), equals('0.0.0.0'));
      expect(ip.bytes, equals(Uint8List.fromList([0, 0, 0, 0])));
    });

    test('Given IPv4Address.loopback, '
        'then its value is "127.0.0.1"', () {
      final ip = IPv4Address.loopback;

      expect(ip.toString(), equals('127.0.0.1'));
      expect(ip.bytes, equals(Uint8List.fromList([127, 0, 0, 1])));
    });

    test('Given IPv4Address.broadcast, '
        'then its value is "255.255.255.255"', () {
      final ip = IPv4Address.broadcastAddr;
      expect(ip.toString(), equals('255.255.255.255'));
      expect(ip.bytes, equals(Uint8List.fromList([255, 255, 255, 255])));
    });
  });

  test('Given an IPv4Address, '
      'when toString is called multiple times, '
      'then returns the same cached String instance', () {
    final ip = IPv4Address.fromOctets(10, 20, 30, 40);
    final firstCallResult = ip.toString(); // Call it once to cache

    // Access the internal _string via a new toString call,
    // assuming it uses the cached value.
    // There's no direct way to check if it's cached without reflection
    // or changing the class, but we can verify consistency.
    final secondCallResult = ip.toString();

    expect(secondCallResult, equals('10.20.30.40'));
    expect(
      identical(firstCallResult, secondCallResult),
      isTrue,
      reason: 'toString() should return the same cached String instance.',
    );
  });
}
