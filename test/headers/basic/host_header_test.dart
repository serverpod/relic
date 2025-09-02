@Timeout.none
library;

import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../../util/test_util.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Host
void main() {
  late RelicServer server;

  setUp(() async {
    server = await createServer();
  });

  tearDown(() => server.close());

  group(
    'Given a request with a Host header',
    () {
      parameterizedTest<
          ({
            String description,
            String hostValue,
            String? expectedError,
          })>(
        variants: [
          (
            description: 'when an empty Host header is passed '
                'then the server responds with a bad request including a message that states the header value cannot be empty',
            hostValue: '',
            expectedError: 'Value cannot be empty',
          ),
          (
            description: 'when a Host header with an invalid format is passed '
                'then the server responds with a bad request including a message that states the format is invalid',
            hostValue: 'h@ttp://example.com',
            expectedError: 'Invalid radix-10 number',
          ),
          (
            description:
                'when a Host header with an invalid port number is passed '
                'then the server responds with a bad request including a message that states the format is invalid',
            hostValue: 'example.com:test',
            expectedError: null, // Just check for BadRequestException
          ),
          (
            description:
                'when a Host header with invalid port format (non-numeric) is passed '
                'then the server responds with a bad request',
            hostValue: '192.168.1.1:abc',
            expectedError: null, // Just check for BadRequestException
          ),
        ],
        (final testCase) => testCase.description,
        (final testCase) async {
          final matcher = testCase.expectedError != null
              ? throwsA(
                  isA<BadRequestException>().having(
                    (final e) => e.message,
                    'message',
                    contains(testCase.expectedError!),
                  ),
                )
              : throwsA(isA<BadRequestException>());

          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'host': testCase.hostValue},
              touchHeaders: (final h) => h.host,
            ),
            matcher,
          );
        },
      );

      test(
        'when a Host header with an invalid value is passed '
        'then the server does not respond with a bad request if the headers '
        'is not actually used',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (final _) {},
            headers: {'host': 'http://example.com'}, // scheme not allowed!
          );

          expect(headers, isNotNull);
        },
      );
      group('when an invalid Host header is passed', () {
        test(
          'then it should return null',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              touchHeaders: (final _) {},
              headers: {'host': 'h@ttp://example.com'},
            );

            expect(Headers.host[headers].valueOrNullIfInvalid, isNull);
            expect(() => headers.host, throwsInvalidHeader);
          },
        );
      });

      // Basic host parsing tests
      parameterizedTest<
          ({
            String description,
            String hostValue,
            HostHeader expectedHost,
          })>(
        variants: [
          (
            description:
                'when a valid Host header is passed then it should parse the host correctly',
            hostValue: 'example.com',
            expectedHost: HostHeader('example.com', null),
          ),
          (
            description:
                'when a Host header with a port number is passed then it should parse the port number correctly',
            hostValue: 'example.com:8080',
            expectedHost: HostHeader('example.com', 8080),
          ),
          (
            description:
                'when a Host header with extra whitespace is passed then it should parse correctly',
            hostValue: ' example.com ',
            expectedHost: HostHeader('example.com', null),
          ),
          // IPv4 address tests
          (
            description:
                'when a valid IPv4 address is passed then it should parse the host correctly',
            hostValue: '192.168.1.1',
            expectedHost: HostHeader('192.168.1.1', null),
          ),
          (
            description:
                'when a valid IPv4 address with port is passed then it should parse both host and port correctly',
            hostValue: '192.168.1.1:8080',
            expectedHost: HostHeader('192.168.1.1', 8080),
          ),
          (
            description:
                'when IPv4 loopback address is passed then it should parse correctly',
            hostValue: '127.0.0.1',
            expectedHost: HostHeader('127.0.0.1', null),
          ),
          (
            description:
                'when IPv4 loopback address with port is passed then it should parse both host and port correctly',
            hostValue: '127.0.0.1:3000',
            expectedHost: HostHeader('127.0.0.1', 3000),
          ),
          (
            description:
                'when IPv4 address with whitespace is passed then it should parse correctly',
            hostValue: ' 10.0.0.1 ',
            expectedHost: HostHeader('10.0.0.1', null),
          ),
          (
            description:
                'when IPv4 private network address is passed then it should parse correctly',
            hostValue: '10.0.0.1:9000',
            expectedHost: HostHeader('10.0.0.1', 9000),
          ),
          (
            description:
                'when IPv4 address with standard HTTP port is passed then it should parse correctly',
            hostValue: '203.0.113.1:80',
            expectedHost: HostHeader('203.0.113.1', 80),
          ),
          (
            description:
                'when IPv4 address with HTTPS port is passed then it should parse correctly',
            hostValue: '203.0.113.1:443',
            expectedHost: HostHeader('203.0.113.1', 443),
          ),
          (
            description:
                'when IPv4 address with high port number is passed then it should parse correctly',
            hostValue: '172.16.0.1:65535',
            expectedHost: HostHeader('172.16.0.1', 65535),
          ),
          (
            description:
                'when IPv4 broadcast address is passed then it should parse correctly',
            hostValue: '255.255.255.255:8080',
            expectedHost: HostHeader('255.255.255.255', 8080),
          ),
          (
            description:
                'when IPv4 zero address is passed then it should parse correctly',
            hostValue: '0.0.0.0',
            expectedHost: HostHeader('0.0.0.0', null),
          ),
          (
            description:
                'when IPv4 address with port 1 is passed then it should parse correctly',
            hostValue: '192.168.0.1:1',
            expectedHost: HostHeader('192.168.0.1', 1),
          ),
          (
            description:
                'when an IPv4-like address with high numbers is passed then it should parse as hostname correctly',
            hostValue: '256.1.1.1',
            expectedHost: HostHeader('256.1.1.1', null),
          ),
          (
            description:
                'when an IPv4-like address with extra octets is passed then it should parse as hostname correctly',
            hostValue: '192.168.1.1.1',
            expectedHost: HostHeader('192.168.1.1.1', null),
          ),
          (
            description:
                'when an IPv4-like address with negative numbers is passed then it should parse as hostname correctly',
            hostValue: '192.168.-1.1:8080',
            expectedHost: HostHeader('192.168.-1.1', 8080),
          ),
          // IPv6 address tests
          (
            description:
                'when a valid IPv6 address in brackets is passed then it should parse the host correctly',
            hostValue: '[2001:db8::1]',
            expectedHost: HostHeader('[2001:db8::1]', null),
          ),
          (
            description:
                'when a valid IPv6 address in brackets with port is passed then it should parse both host and port correctly',
            hostValue: '[2001:db8::1]:8080',
            expectedHost: HostHeader('[2001:db8::1]', 8080),
          ),
          (
            description:
                'when an IPv6 loopback address in brackets is passed then it should parse correctly',
            hostValue: '[::1]',
            expectedHost: HostHeader('[::1]', null),
          ),
          (
            description:
                'when an IPv6 loopback address in brackets with port is passed then it should parse both host and port correctly',
            hostValue: '[::1]:3000',
            expectedHost: HostHeader('[::1]', 3000),
          ),
          (
            description:
                'when IPv6 address with whitespace is passed then it should parse correctly',
            hostValue: ' [2001:db8::1] ',
            expectedHost: HostHeader('[2001:db8::1]', null),
          ),
          (
            description:
                'when full IPv6 address in brackets is passed then it should parse correctly',
            hostValue: '[2001:0db8:85a3:0000:0000:8a2e:0370:7334]',
            expectedHost:
                HostHeader('[2001:0db8:85a3:0000:0000:8a2e:0370:7334]', null),
          ),
          (
            description:
                'when IPv6 address with double colon compression is passed then it should parse correctly',
            hostValue: '[2001:db8::8a2e:370:7334]:9000',
            expectedHost: HostHeader('[2001:db8::8a2e:370:7334]', 9000),
          ),
          (
            description:
                'when IPv6 address ending with numbers that could be port is passed then it should parse correctly with brackets',
            hostValue: '[2001:db8:85a3::8a2e:370:7334]:80',
            expectedHost: HostHeader('[2001:db8:85a3::8a2e:370:7334]', 80),
          ),
          (
            description:
                'when IPv6 loopback with port-like ending is passed then it should parse correctly with brackets',
            hostValue: '[::1]:8080',
            expectedHost: HostHeader('[::1]', 8080),
          ),
          (
            description:
                'when IPv6 compressed notation that could be ambiguous is passed then it should parse correctly with brackets',
            hostValue: '[::ffff:192.0.2.1]:443',
            expectedHost: HostHeader('[::ffff:192.0.2.1]', 443),
          ),
          (
            description:
                'when IPv6 address with embedded IPv4 notation is passed then it should parse correctly with brackets',
            hostValue: '[::ffff:192.168.1.1]',
            expectedHost: HostHeader('[::ffff:192.168.1.1]', null),
          ),
          (
            description:
                'when IPv6 zero compression at end that could look like port is passed then it should parse correctly with brackets',
            hostValue: '[2001:db8::]:3000',
            expectedHost: HostHeader('[2001:db8::]', 3000),
          ),
          (
            description:
                'when IPv6 address ending exactly like common port 80 is passed then it should parse correctly with brackets',
            hostValue: '[fe80::1:80]:8080',
            expectedHost: HostHeader('[fe80::1:80]', 8080),
          ),
          (
            description:
                'when IPv6 address ending like port 443 is passed then it should parse correctly with brackets',
            hostValue: '[2001:db8::443]:443',
            expectedHost: HostHeader('[2001:db8::443]', 443),
          ),
          (
            description:
                'when minimal IPv6 with short notation is passed then it should parse correctly with brackets',
            hostValue: '[::1:1]:1',
            expectedHost: HostHeader('[::1:1]', 1),
          ),
          (
            description:
                'when IPv6 with multiple consecutive numbers is passed then it should parse correctly with brackets',
            hostValue: '[2001:0:0:0:0:0:0:8080]',
            expectedHost: HostHeader('[2001:0:0:0:0:0:0:8080]', null),
          ),
          (
            description:
                'when IPv6 with embedded IPv4 ending in port-like numbers is passed then it should parse correctly with brackets',
            hostValue: '[64:ff9b::192.0.2.80]:80',
            expectedHost: HostHeader('[64:ff9b::192.0.2.80]', 80),
          ),
          // Note: Unbracketed IPv6 addresses like '::1' cannot be tested here
          // because they cause URL parsing failures at the HTTP client level
          // before reaching the header validation logic.
        ],
        (final testCase) => testCase.description,
        (final testCase) async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'host': testCase.hostValue},
            touchHeaders: (final h) => h.host,
          );

          expect(headers.host, equals(testCase.expectedHost));
        },
      );
    },
  );
}
