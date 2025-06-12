import 'package:relic/src/adapter/connection_info.dart';
import 'package:relic/src/adapter/ip_address.dart';
import 'package:test/test.dart';

void main() {
  group('ConnectionInfo', () {
    group('Constructor', () {
      test(
          'Given valid remote address, remote port, and local port, '
          'when a ConnectionInfo object is created, '
          'then its properties are set correctly.', () {
        // Arrange
        final remoteAddress = IPAddress.parse('192.168.1.100');
        const remotePort = 12345;
        const localPort = 8080;

        // Act
        final connectionInfo = ConnectionInfo(
          remoteAddress: remoteAddress,
          remotePort: remotePort,
          localPort: localPort,
        );

        // Assert
        expect(connectionInfo.remoteAddress, equals(remoteAddress));
        expect(connectionInfo.remotePort, equals(remotePort));
        expect(connectionInfo.localPort, equals(localPort));
      });
    });

    group('Static ConnectionInfo.unknown()', () {
      test(
          'Given ConnectionInfo.unknown(), '
          'when its properties are accessed, '
          'then they match the expected default values.', () {
        // Act
        final unknownInfo = ConnectionInfo.unknown();

        // Assert
        expect(unknownInfo.remoteAddress, equals(IPv6Address.any));
        expect(unknownInfo.remotePort, equals(0));
        expect(unknownInfo.localPort, equals(0));
      });
    });

    group('toString() method', () {
      test(
          'Given a ConnectionInfo object, '
          'when toString() is called, '
          'then it returns the correctly formatted string.', () {
        // Arrange
        final connectionInfo = ConnectionInfo(
          remoteAddress: IPAddress.parse('10.0.0.5'),
          remotePort: 54321,
          localPort: 9000,
        );
        const expectedString =
            'ConnectionInfo(remote: 10.0.0.5:54321, local port:9000)';

        // Act

        // Assert
        expect(connectionInfo.toString(), equals(expectedString));
      });

      test(
          'Given a ConnectionInfo object with IPv6 address, '
          'when toString() is called, '
          'then it returns the correctly formatted string with brackets.', () {
        // Arrange
        final connectionInfo = ConnectionInfo(
          remoteAddress: IPAddress.parse('2001:db8::1'),
          remotePort: 443,
          localPort: 8080,
        );
        const expectedString =
            'ConnectionInfo(remote: [2001:db8::1]:443, local port:8080)';

        // Act & Assert
        expect(connectionInfo.toString(), equals(expectedString));
      });

      test(
          'Given ConnectionInfo.unknown(), '
          'when toString() is called, '
          'then it returns the correctly formatted string for empty.', () {
        // Arrange
        final emptyInfo = ConnectionInfo.unknown();
        const expectedString = 'ConnectionInfo(remote: [::]:0, local port:0)';

        // Act & Assert
        expect(emptyInfo.toString(), equals(expectedString));
      });
    });
  });
}
