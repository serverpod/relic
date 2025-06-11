import 'package:relic/src/adapter/connection_info.dart';
import 'package:relic/src/ip_address/ip_address.dart';
import 'package:test/test.dart';

import '../util/test_util.dart';

void main() {
  group('SocketAddress', () {
    final address = IPAddress.parse('192.168.1.1');
    group('Constructor', () {
      parameterizedTest<int>(
        variants: [-1, -100, 65536, 100000],
        (final port) =>
            'Given port $port, '
            'when a SocketAddress is created, '
            'then it throws an ArgumentError.',
        (final port) {
          expect(
            () => SocketAddress(address: address, port: port),
            throwsA(isA<ArgumentError>()),
          );
        },
      );

      parameterizedTest<int>(
        variants: [0, 1, 1023, 1024, 65535],
        (final port) =>
            'Given port $port, '
            'when a SocketAddress is created, '
            'then it succeeds.',
        (final port) {
          final socketAddress = SocketAddress(address: address, port: port);
          expect(socketAddress.port, equals(port));
        },
      );
    });

    group('isWellKnownPort', () {
      parameterizedTest<int>(
        variants: [0, 1, 80, 443, 1023],
        (final port) =>
            'Given port $port, '
            'when isWellKnownPort is accessed, '
            'then it returns true.',
        (final port) {
          final socketAddress = SocketAddress(address: address, port: port);
          expect(socketAddress.isWellKnownPort, isTrue);
        },
      );

      parameterizedTest<int>(
        variants: [1024, 8080, 65535],
        (final port) =>
            'Given port $port, '
            'when isWellKnownPort is accessed, '
            'then it returns false.',
        (final port) {
          final socketAddress = SocketAddress(address: address, port: port);
          expect(socketAddress.isWellKnownPort, isFalse);
        },
      );
    });
  });

  group('ConnectionInfo', () {
    group('Constructor', () {
      test('Given valid remote address, remote port, and local port, '
          'when a ConnectionInfo object is created, '
          'then its properties are set correctly.', () {
        final remoteAddress = IPAddress.parse('192.168.1.100');
        const remotePort = 12345;
        const localPort = 8080;

        final connectionInfo = ConnectionInfo(
          remote: SocketAddress(address: remoteAddress, port: remotePort),
          localPort: localPort,
        );

        expect(connectionInfo.remote.address, equals(remoteAddress));
        expect(connectionInfo.remote.port, equals(remotePort));
        expect(connectionInfo.localPort, equals(localPort));
      });
    });

    group('Static ConnectionInfo.empty', () {
      test('Given ConnectionInfo.empty, '
          'when its properties are accessed, '
          'then they match the expected default values.', () {
        final unknownInfo = ConnectionInfo.empty;

        expect(unknownInfo.remote.address, equals(IPv6Address.any));
        expect(unknownInfo.remote.port, equals(0));
        expect(unknownInfo.localPort, equals(0));
      });
    });

    group('toString() method', () {
      test('Given a ConnectionInfo object, '
          'when toString() is called, '
          'then it returns the correctly formatted string.', () {
        final connectionInfo = ConnectionInfo(
          remote: SocketAddress(
            address: IPAddress.parse('10.0.0.5'),
            port: 54321,
          ),
          localPort: 9000,
        );
        const expectedString =
            'ConnectionInfo(remote: 10.0.0.5:54321, local port:9000)';

        expect(connectionInfo.toString(), equals(expectedString));
      });

      test('Given a ConnectionInfo object with IPv6 address, '
          'when toString() is called, '
          'then it returns the correctly formatted string with brackets.', () {
        final connectionInfo = ConnectionInfo(
          remote: SocketAddress(
            address: IPAddress.parse('2001:db8::1'),
            port: 443,
          ),
          localPort: 8080,
        );
        const expectedString =
            'ConnectionInfo(remote: [2001:db8::1]:443, local port:8080)';

        expect(connectionInfo.toString(), equals(expectedString));
      });

      test('Given ConnectionInfo.empty, '
          'when toString() is called, '
          'then it returns the correctly formatted string for empty.', () {
        final emptyInfo = ConnectionInfo.empty;
        const expectedString = 'ConnectionInfo(remote: [::]:0, local port:0)';

        expect(emptyInfo.toString(), equals(expectedString));
      });
    });
  });
}
