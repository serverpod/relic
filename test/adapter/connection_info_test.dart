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
        final remoteIp = IPAddress.parse('192.168.1.100');
        const remoteP = 12345;
        const localP = 8080;

        // Act
        final connectionInfo = ConnectionInfo(
          remoteAddress: remoteIp,
          remotePort: remoteP,
          localPort: localP,
        );

        // Assert
        expect(connectionInfo.remoteAddress, equals(remoteIp));
        expect(connectionInfo.remotePort, equals(remoteP));
        expect(connectionInfo.localPort, equals(localP));
      });
    });

    group('Static ConnectionInfo.empty', () {
      test(
          'Given ConnectionInfo.empty, '
          'when its properties are accessed, '
          'then they match the expected default values.', () {
        // Act
        final emptyInfo = ConnectionInfo.empty;

        // Assert
        expect(emptyInfo.remoteAddress, equals(IPv6Address.any));
        expect(emptyInfo.remotePort, equals(0));
        expect(emptyInfo.localPort, equals(0));
      });
    });

    group('toString() method', () {
      test(
          'Given a ConnectionInfo object, '
          'when toString() is called, '
          'then it returns the correctly formatted string.', () {
        // Arrange
        final remoteIp = IPAddress.parse('10.0.0.5');
        const remoteP = 54321;
        const localP = 9000;
        final connectionInfo = ConnectionInfo(
          remoteAddress: remoteIp,
          remotePort: remoteP,
          localPort: localP,
        );
        const expectedString =
            'ConnectionInfo(remote: 10.0.0.5:54321, local port:9000)';

        // Act
        final actualString = connectionInfo.toString();

        // Assert
        expect(actualString, equals(expectedString));
      });

      test(
          'Given ConnectionInfo.empty, '
          'when toString() is called, '
          'then it returns the correctly formatted string for empty.', () {
        // Arrange
        final emptyInfo = ConnectionInfo.empty;
        const expectedString = 'ConnectionInfo(remote: [::]:0, local port:0)';

        // Act
        final actualString = emptyInfo.toString();

        // Assert
        expect(actualString, equals(expectedString));
      });
    });
  });
}
