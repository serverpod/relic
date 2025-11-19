import 'dart:typed_data';

import 'package:relic/src/ip_address/ip_address.dart';
import 'package:test/test.dart';

void main() {
  group('Factory IPAddress.parse()', () {
    test('Given a valid IPv4 string, '
        'when parsed, '
        'then an IPv4Address is returned', () {
      const addressString = '192.168.1.1';

      final ipAddress = IPAddress.parse(addressString);

      expect(ipAddress, isA<IPv4Address>());
      expect(ipAddress.toString(), equals(addressString));
    });

    test('Given a valid IPv6 string, '
        'when parsed, '
        'then an IPv6Address is returned', () {
      const addressString = '2001:0db8:85a3:0000:0000:8a2e:0370:7334';
      const compressedString = '2001:db8:85a3::8a2e:370:7334';

      final ipAddress = IPAddress.parse(addressString);

      expect(ipAddress, isA<IPv6Address>());
      expect(ipAddress.toString(), equals(compressedString));
    });

    test('Given a valid compressed IPv6 string, '
        'when parsed, '
        'then an IPv6Address is returned', () {
      const addressString = '2001:db8::1';

      final ipAddress = IPAddress.parse(addressString);

      expect(ipAddress, isA<IPv6Address>());
      expect(ipAddress.toString(), equals(addressString));
    });
  });

  group('Factory IPAddress.fromBytes()', () {
    test('Given a 4-byte Uint8List, '
        'when IPAddress.fromBytes is called, '
        'then an IPv4Address is returned', () {
      final bytes = Uint8List.fromList([192, 168, 1, 1]);

      final ipAddress = IPAddress.fromBytes(bytes);

      expect(ipAddress, isA<IPv4Address>());
      expect(ipAddress.bytes, equals(bytes));
    });

    test('Given a 16-byte Uint8List, '
        'when IPAddress.fromBytes is called, '
        'then an IPv6Address is returned', () {
      final bytes = Uint8List.fromList([
        32, 1, 13, 184, // 2001:0db8
        0, 0, 0, 0, // ::
        0, 0, 0, 0,
        0, 0, 0, 1, // 1
      ]); // 2001:0db8::1

      final ipAddress = IPAddress.fromBytes(bytes);

      expect(ipAddress, isA<IPv6Address>());
      expect(ipAddress.bytes, equals(bytes));
    });

    test('Given a Uint8List with an invalid length, '
        'when IPAddress.fromBytes is called, '
        'then an ArgumentError is thrown', () {
      final bytes = Uint8List.fromList([1, 2, 3]);

      expect(() => IPAddress.fromBytes(bytes), throwsA(isA<ArgumentError>()));
    });
  });

  group('Equality and HashCode', () {
    test('Given two identical IPAddress objects, '
        'when compared, '
        'then they are equal and have the same hashCode', () {
      final ip1 = IPAddress.parse('192.168.1.1');
      final ip2 = IPAddress.parse('192.168.1.1');

      expect(ip1, equals(ip2));
      expect(ip1.hashCode, equals(ip2.hashCode));

      final ip3 = IPAddress.parse('2001:db8::1');
      final ip4 = IPAddress.parse('2001:db8::1');
      expect(ip3, equals(ip4));
      expect(ip3.hashCode, equals(ip4.hashCode));
    });

    test('Given two different IPAddress objects of the same type, '
        'when compared, '
        'then they are not equal', () {
      final ip1 = IPAddress.parse('192.168.1.1');
      final ip2 = IPAddress.parse('192.168.1.2');

      expect(ip1, isNot(equals(ip2)));

      final ip3 = IPAddress.parse('2001:db8::1');
      final ip4 = IPAddress.parse('2001:db8::2');
      expect(ip3, isNot(equals(ip4)));
    });

    test('Given two IPAddress objects of different types, '
        'when compared, '
        'then they are not equal', () {
      final ip1 = IPAddress.parse('127.0.0.1');
      final ip2 = IPAddress.parse('::1'); // IPv6 loopback

      expect(ip1, isNot(equals(ip2)));
    });

    test('Given an IPAddress and a non-IPAddress object, '
        'when compared, '
        'then they are not equal', () {
      final ip1 = IPAddress.parse('10.0.0.1');
      const otherObject = '10.0.0.1';

      // ignore: unrelated_type_equality_checks
      expect(ip1, isNot(equals(otherObject)));
    });
  });
}
