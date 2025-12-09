import 'package:relic/src/ip_address/ip_address.dart';
import 'package:test/test.dart';

void main() {
  group('parse with CIDR notation', () {
    test('Given a valid IPv4 CIDR string, '
        'when parsed, '
        'then an IPv4Address is returned with correct prefix', () {
      const cidr = '192.168.1.0/24';

      final ip = IPAddress.parse(cidr);

      expect(ip, isA<IPv4Address>());
      expect(ip.toString(), equals('192.168.1.0/24'));
      expect(ip.prefixLength, equals(24));
    });

    test('Given a valid IPv6 CIDR string, '
        'when parsed, '
        'then an IPv6Address is returned with correct prefix', () {
      const cidr = '2001:db8::/32';

      final ip = IPAddress.parse(cidr);

      expect(ip, isA<IPv6Address>());
      expect(ip.toString(), equals('2001:db8::/32'));
      expect(ip.prefixLength, equals(32));
    });

    test('Given an IP address without prefix length, '
        'when parsed, '
        'then default prefix length is used', () {
      const ip = '192.168.1.0';

      final result = IPAddress.parse(ip);

      expect(result.toString(), equals('192.168.1.0'));
      expect(result.prefixLength, equals(32)); // Default for IPv4
    });

    test('Given a CIDR string with invalid prefix length, '
        'when parsed, '
        'then FormatException is thrown', () {
      const cidr = '192.168.1.0/abc';

      expect(() => IPAddress.parse(cidr), throwsFormatException);
    });

    test('Given an IPv4 CIDR with prefix > 32, '
        'when parsed, '
        'then FormatException is thrown', () {
      const cidr = '192.168.1.0/33';

      expect(() => IPAddress.parse(cidr), throwsFormatException);
    });

    test('Given an IPv6 CIDR with prefix > 128, '
        'when parsed, '
        'then FormatException is thrown', () {
      const cidr = '2001:db8::/129';

      expect(() => IPAddress.parse(cidr), throwsFormatException);
    });
  });

  group('IPv4 CIDR Operations', () {
    group('Given an IPv4 subnet, when contains is called', () {
      test('then returns true for IP within subnet', () {
        final subnet = IPAddress.parse('192.168.1.0/24');
        final ip = IPAddress.parse('192.168.1.100');

        final result = subnet.contains(ip);

        expect(result, isTrue);
      });

      test('then returns false for IP outside subnet', () {
        final subnet = IPAddress.parse('192.168.1.0/24');
        final ip = IPAddress.parse('192.168.2.100');

        final result = subnet.contains(ip);

        expect(result, isFalse);
      });

      test('then returns false for IPv6 address', () {
        final subnet = IPAddress.parse('192.168.1.0/24');
        final ip = IPAddress.parse('2001:db8::1');

        final result = subnet.contains(ip);

        expect(result, isFalse);
      });
    });

    test('Given an IP with prefix, '
        'when network is accessed, '
        'then returns correct network address', () {
      final ip = IPAddress.parse('192.168.1.100/24');

      final result = ip.network;

      expect(result.toString(), equals('192.168.1.0/24'));
      expect(result.prefixLength, equals(24));
    });

    test('Given an IP with prefix, '
        'when broadcast is accessed, '
        'then returns correct broadcast address', () {
      final ip = IPAddress.parse('192.168.1.0/24');

      final result = ip.broadcast;

      expect(result.toString(), equals('192.168.1.255/24'));
    });

    test('Given an IP with non-default prefix, '
        'when toString is called, '
        'then prefix is included', () {
      final ip = IPAddress.parse('192.168.1.100/24');

      final result = ip.toString();

      expect(result, equals('192.168.1.100/24'));
    });

    test('Given an IP with default prefix, '
        'when toString is called, '
        'then prefix is excluded', () {
      final ip = IPAddress.parse('192.168.1.100');

      final result = ip.toString();

      expect(result, equals('192.168.1.100'));
    });

    test('Given an IP with explicit /32 prefix, '
        'when toString is called, '
        'then prefix is excluded', () {
      final ip = IPAddress.parse('192.168.1.100/32');

      final result = ip.toString();

      expect(result, equals('192.168.1.100'));
    });

    test('Given an IP, '
        'when withPrefixLength is called, '
        'then returns new IP with changed prefix', () {
      final ip = IPAddress.parse('192.168.1.100');

      final result = ip.withPrefixLength(24);

      expect(result.prefixLength, equals(24));
    });

    test('Given an IPv4, '
        'when withPrefixLength is called with value > 32, '
        'then ArgumentError is thrown', () {
      final ip = IPAddress.parse('192.168.1.100');

      expect(() => ip.withPrefixLength(33), throwsArgumentError);
    });

    test('Given an IPv6, '
        'when withPrefixLength is called with value > 128, '
        'then ArgumentError is thrown', () {
      final ip = IPAddress.parse('2001:db8::1');

      expect(() => ip.withPrefixLength(129), throwsArgumentError);
    });

    test('Given an IPv4Address, '
        'when toInt is called, '
        'then returns correct 32-bit integer', () {
      final ip = IPv4Address.fromOctets(192, 168, 1, 1);

      final result = ip.toInt();

      expect(result, equals(0xC0A80101));
    });
  });

  group('IPv6 CIDR Operations', () {
    group('Given an IPv6 subnet, when contains is called', () {
      test('then returns true for IPv6 address within subnet', () {
        final subnet = IPAddress.parse('2001:db8:1234:5678::/64');
        final ip = IPAddress.parse('2001:db8:1234:5678::abcd');

        final result = subnet.contains(ip);

        expect(result, isTrue);
      });

      test('then returns false for IPv6 address outside subnet', () {
        final subnet = IPAddress.parse('2001:db8:1234:5678::/64');
        final ip = IPAddress.parse('2001:db8:1234:5679::abcd');

        final result = subnet.contains(ip);

        expect(result, isFalse);
      });
    });

    test('Given an IPv6 with prefix, '
        'when network is accessed, '
        'then returns correct network address', () {
      final ip = IPAddress.parse('2001:db8:1234:5678::abcd/64');

      final result = ip.network;

      expect(result.toString(), equals('2001:db8:1234:5678::/64'));
    });

    test('Given an IPv6 with prefix, '
        'when broadcast is accessed, '
        'then returns last address in subnet', () {
      final ip = IPAddress.parse('2001:db8:1234:5678::1/64');

      final result = ip.broadcast;

      expect(
        result.toString(),
        equals('2001:db8:1234:5678:ffff:ffff:ffff:ffff/64'),
      );
    });

    test('Given an IPv6 with explicit /128 prefix, '
        'when toString is called, '
        'then prefix is excluded', () {
      final ip = IPAddress.parse('2001:db8::1/128');

      final result = ip.toString();

      expect(result, equals('2001:db8::1'));
    });
  });

  group('Network and Broadcast Edge Cases', () {
    test('Given an IPv4 subnet at byte boundary, '
        'when network and broadcast are accessed, '
        'then correct addresses are returned', () {
      final ip = IPAddress.parse('192.168.1.128/25');

      final networkAddr = ip.network;
      final broadcastAddr = ip.broadcast;

      expect(networkAddr.toString(), equals('192.168.1.128/25'));
      expect(broadcastAddr.toString(), equals('192.168.1.255/25'));
    });
  });

  group('Edge Cases', () {
    test('Given IPs without explicit prefix, '
        'when parsed, '
        'then default prefix lengths are used', () {
      final ipv4 = IPAddress.parse('192.168.1.1');
      final ipv6 = IPAddress.parse('2001:db8::1');

      expect(ipv4.prefixLength, equals(32));
      expect(ipv6.prefixLength, equals(128));
    });

    test('Given a host address, '
        'when isHost is checked, '
        'then returns true', () {
      final host = IPAddress.parse('192.168.1.1');

      expect(host.isHost, isTrue);
    });

    test('Given a subnet, '
        'when isHost is checked, '
        'then returns false', () {
      final subnet = IPAddress.parse('192.168.1.100/24');

      expect(subnet.isHost, isFalse);
    });

    test('Given a network address, '
        'when isNetworkAddress is checked, '
        'then returns true', () {
      final subnet = IPAddress.parse('192.168.1.100/24');

      final networkAddr = subnet.network;

      expect(networkAddr.isNetworkAddress, isTrue);
    });

    test('Given an IP address string with multiple slashes, '
        'when parsed, '
        'then FormatException is thrown', () {
      const invalidCidr = '192.168.1.0/24/32';

      expect(() => IPAddress.parse(invalidCidr), throwsFormatException);
    });

    test('Given two IP addresses with different byte lengths, '
        'when compared for equality, '
        'then they are not equal', () {
      final ipv4 = IPAddress.parse('192.168.1.1');
      final ipv6 = IPAddress.parse('::1');

      expect(ipv4 == ipv6, isFalse);
    });

    test('Given a CIDR string with negative prefix length, '
        'when parsed, '
        'then FormatException is thrown', () {
      const cidr = '192.168.1.0/-1';

      expect(() => IPAddress.parse(cidr), throwsFormatException);
    });
  });
}
