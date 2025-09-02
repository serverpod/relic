@Timeout.none
library;

import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Host
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group(
    'Given a Host header with the strict flag true',
    () {
      late RelicServer server;

      setUp(() async {
        server = await createServer(strictHeaders: true);
      });

      tearDown(() => server.close());
      test(
        'when an empty Host header is passed then the server responds '
        'with a bad request including a message that states the header value '
        'cannot be empty',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'host': ''},
              touchHeaders: (final h) => h.host,
            ),
            throwsA(
              isA<BadRequestException>().having(
                (final e) => e.message,
                'message',
                contains('Value cannot be empty'),
              ),
            ),
          );
        },
      );

      test(
        'when a Host header with an invalid format is passed '
        'then the server responds with a bad request including a message that '
        'states the format is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'host': 'h@ttp://example.com'},
              touchHeaders: (final h) => h.host,
            ),
            throwsA(
              isA<BadRequestException>().having(
                (final e) => e.message,
                'message',
                contains('Invalid radix-10 number'),
              ),
            ),
          );
        },
      );

      test(
        'when a Host header with an invalid port number is passed '
        'then the server responds with a bad request including a message that '
        'states the format is invalid',
        () async {
          expect(
            getServerRequestHeaders(
              server: server,
              headers: {'host': 'example.com:test'},
              touchHeaders: (final h) => h.host,
            ),
            throwsA(isA<BadRequestException>()),
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

      test(
        'when a valid Host header is passed then it should parse the host correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'host': 'example.com'},
            touchHeaders: (final h) => h.host,
          );

          expect(headers.host, equals(HostHeader('example.com', null)));
        },
      );

      test(
        'when a Host header with a port number is passed then it should parse '
        'the port number correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'host': 'example.com:8080'},
            touchHeaders: (final h) => h.host,
          );

          expect(headers.host?.port, equals(8080));
        },
      );

      test(
        'when a Host header with extra whitespace is passed then it should parse correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'host': ' example.com '},
            touchHeaders: (final h) => h.host,
          );

          expect(headers.host, equals(HostHeader('example.com', null)));
        },
      );

      test(
        'when no Host header is passed then it should default to machine address',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {},
            touchHeaders: (final h) => h.host,
          );

          expect(headers.host, isNotNull);
        },
      );

      group('when IPv6 addresses are used', () {
        test(
          'when a valid IPv6 address in brackets is passed '
          'then it should parse the host correctly',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              headers: {'host': '[2001:db8::1]'},
              touchHeaders: (final h) => h.host,
            );

            expect(headers.host, equals(HostHeader('[2001:db8::1]', null)));
          },
        );

        test(
          'when a valid IPv6 address in brackets with port is passed '
          'then it should parse both host and port correctly',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              headers: {'host': '[2001:db8::1]:8080'},
              touchHeaders: (final h) => h.host,
            );

            expect(headers.host?.port, equals(8080));
          },
        );

        test(
          'when an IPv6 loopback address in brackets is passed '
          'then it should parse correctly',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              headers: {'host': '[::1]'},
              touchHeaders: (final h) => h.host,
            );

            expect(headers.host, equals(HostHeader('[::1]', null)));
          },
        );

        test(
          'when an IPv6 loopback address in brackets with port is passed '
          'then it should parse both host and port correctly',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              headers: {'host': '[::1]:3000'},
              touchHeaders: (final h) => h.host,
            );

            expect(headers.host?.port, equals(3000));
          },
        );

        test(
          'when IPv6 address with whitespace is passed '
          'then it should parse correctly',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              headers: {'host': ' [2001:db8::1] '},
              touchHeaders: (final h) => h.host,
            );

            expect(headers.host, equals(HostHeader('[2001:db8::1]', null)));
          },
        );

        test(
          'when full IPv6 address in brackets is passed '
          'then it should parse correctly',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              headers: {'host': '[2001:0db8:85a3:0000:0000:8a2e:0370:7334]'},
              touchHeaders: (final h) => h.host,
            );

            expect(
                headers.host,
                equals(HostHeader(
                    '[2001:0db8:85a3:0000:0000:8a2e:0370:7334]', null)));
          },
        );

        test(
          'when IPv6 address with double colon compression is passed '
          'then it should parse correctly',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              headers: {'host': '[2001:db8::8a2e:370:7334]:9000'},
              touchHeaders: (final h) => h.host,
            );

            expect(headers.host?.port, equals(9000));
          },
        );

        group('when ambiguous IPv6 addresses are used', () {
          test(
            'when IPv6 address ending with numbers that could be port is passed '
            'then it should parse correctly with brackets',
            () async {
              final headers = await getServerRequestHeaders(
                server: server,
                headers: {'host': '[2001:db8:85a3::8a2e:370:7334]:80'},
                touchHeaders: (final h) => h.host,
              );

              expect(headers.host?.port, equals(80));
            },
          );

          test(
            'when IPv6 loopback with port-like ending is passed '
            'then it should parse correctly with brackets',
            () async {
              final headers = await getServerRequestHeaders(
                server: server,
                headers: {'host': '[::1]:8080'},
                touchHeaders: (final h) => h.host,
              );

              expect(headers.host?.port, equals(8080));
            },
          );

          test(
            'when IPv6 compressed notation that could be ambiguous is passed '
            'then it should parse correctly with brackets',
            () async {
              final headers = await getServerRequestHeaders(
                server: server,
                headers: {'host': '[::ffff:192.0.2.1]:443'},
                touchHeaders: (final h) => h.host,
              );

              expect(headers.host?.port, equals(443));
            },
          );

          test(
            'when IPv6 address with embedded IPv4 notation is passed '
            'then it should parse correctly with brackets',
            () async {
              final headers = await getServerRequestHeaders(
                server: server,
                headers: {'host': '[::ffff:192.168.1.1]'},
                touchHeaders: (final h) => h.host,
              );

              expect(headers.host,
                  equals(HostHeader('[::ffff:192.168.1.1]', null)));
            },
          );

          test(
            'when IPv6 zero compression at end that could look like port is passed '
            'then it should parse correctly with brackets',
            () async {
              final headers = await getServerRequestHeaders(
                server: server,
                headers: {'host': '[2001:db8::]:3000'},
                touchHeaders: (final h) => h.host,
              );

              expect(headers.host?.port, equals(3000));
            },
          );
        });

        group('when extremely ambiguous IPv6 addresses are used', () {
          test(
            'when IPv6 address ending exactly like common port 80 is passed '
            'then it should parse correctly with brackets',
            () async {
              final headers = await getServerRequestHeaders(
                server: server,
                headers: {'host': '[fe80::1:80]:8080'},
                touchHeaders: (final h) => h.host,
              );

              expect(headers.host?.port, equals(8080));
            },
          );

          test(
            'when IPv6 address ending like port 443 is passed '
            'then it should parse correctly with brackets',
            () async {
              final headers = await getServerRequestHeaders(
                server: server,
                headers: {'host': '[2001:db8::443]:443'},
                touchHeaders: (final h) => h.host,
              );

              expect(headers.host?.port, equals(443));
            },
          );

          test(
            'when minimal IPv6 with short notation is passed '
            'then it should parse correctly with brackets',
            () async {
              final headers = await getServerRequestHeaders(
                server: server,
                headers: {'host': '[::1:1]:1'},
                touchHeaders: (final h) => h.host,
              );

              expect(headers.host?.port, equals(1));
            },
          );

          test(
            'when IPv6 with multiple consecutive numbers is passed '
            'then it should parse correctly with brackets',
            () async {
              final headers = await getServerRequestHeaders(
                server: server,
                headers: {'host': '[2001:0:0:0:0:0:0:8080]'},
                touchHeaders: (final h) => h.host,
              );

              expect(headers.host,
                  equals(HostHeader('[2001:0:0:0:0:0:0:8080]', null)));
            },
          );

          test(
            'when IPv6 with embedded IPv4 ending in port-like numbers is passed '
            'then it should parse correctly with brackets',
            () async {
              final headers = await getServerRequestHeaders(
                server: server,
                headers: {'host': '[64:ff9b::192.0.2.80]:80'},
                touchHeaders: (final h) => h.host,
              );

              expect(headers.host?.port, equals(80));
            },
          );

          // Note: Unbracketed IPv6 addresses like '::1' cannot be tested here
          // because they cause URL parsing failures at the HTTP client level
          // before reaching the header validation logic. This demonstrates
          // why RFC 3986 requires brackets for all IPv6 addresses in URIs.
        });
      });
    },
  );

  group('Given a Host header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

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

    test(
      'when no Host header is passed then it should default to machine address',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          headers: {},
          touchHeaders: (final h) => h.host,
        );

        expect(headers.host, isNotNull);
      },
    );

    group('when IPv6 Host headers are passed', () {
      test(
        'when a valid IPv6 address in brackets is passed '
        'then it should parse correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'host': '[2001:db8::1]'},
            touchHeaders: (final h) => h.host,
          );

          expect(headers.host, equals(HostHeader('[2001:db8::1]', null)));
        },
      );

      test(
        'when a valid IPv6 address in brackets with port is passed '
        'then it should parse both host and port correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'host': '[::1]:3000'},
            touchHeaders: (final h) => h.host,
          );

          expect(headers.host?.port, equals(3000));
        },
      );

      test(
        'when IPv6 address with whitespace is passed '
        'then it should parse correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'host': ' [::1]:8080 '},
            touchHeaders: (final h) => h.host,
          );

          expect(headers.host?.port, equals(8080));
        },
      );

      test(
        'when full IPv6 address in brackets with port is passed '
        'then it should parse correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'host': '[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:443'},
            touchHeaders: (final h) => h.host,
          );

          expect(headers.host?.port, equals(443));
        },
      );

      test(
        'when IPv6 address with double colon compression is passed '
        'then it should parse correctly',
        () async {
          final headers = await getServerRequestHeaders(
            server: server,
            headers: {'host': '[2001:db8::8a2e:370:7334]'},
            touchHeaders: (final h) => h.host,
          );

          expect(headers.host,
              equals(HostHeader('[2001:db8::8a2e:370:7334]', null)));
        },
      );

      group('when ambiguous IPv6 addresses are used', () {
        test(
          'when IPv6 address ending with numbers that could be port is passed '
          'then it should parse correctly with brackets',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              headers: {'host': '[2001:db8:85a3::8a2e:370:7334]:80'},
              touchHeaders: (final h) => h.host,
            );

            expect(headers.host?.port, equals(80));
          },
        );

        test(
          'when IPv6 loopback with port-like ending is passed '
          'then it should parse correctly with brackets',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              headers: {'host': '[::1]:8080'},
              touchHeaders: (final h) => h.host,
            );

            expect(headers.host?.port, equals(8080));
          },
        );

        test(
          'when IPv6 compressed notation that could be ambiguous is passed '
          'then it should parse correctly with brackets',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              headers: {'host': '[::ffff:192.0.2.1]:443'},
              touchHeaders: (final h) => h.host,
            );

            expect(headers.host?.port, equals(443));
          },
        );

        test(
          'when IPv6 address with embedded IPv4 notation is passed '
          'then it should parse correctly with brackets',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              headers: {'host': '[::ffff:192.168.1.1]'},
              touchHeaders: (final h) => h.host,
            );

            expect(
                headers.host, equals(HostHeader('[::ffff:192.168.1.1]', null)));
          },
        );

        test(
          'when IPv6 zero compression at end that could look like port is passed '
          'then it should parse correctly with brackets',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              headers: {'host': '[2001:db8::]:3000'},
              touchHeaders: (final h) => h.host,
            );

            expect(headers.host?.port, equals(3000));
          },
        );
      });

      group('when extremely ambiguous IPv6 addresses are used', () {
        test(
          'when IPv6 address ending exactly like common port 80 is passed '
          'then it should parse correctly with brackets',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              headers: {'host': '[fe80::1:80]:8080'},
              touchHeaders: (final h) => h.host,
            );

            expect(headers.host?.port, equals(8080));
          },
        );

        test(
          'when IPv6 address ending like port 443 is passed '
          'then it should parse correctly with brackets',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              headers: {'host': '[2001:db8::443]:443'},
              touchHeaders: (final h) => h.host,
            );

            expect(headers.host?.port, equals(443));
          },
        );

        test(
          'when minimal IPv6 with short notation is passed '
          'then it should parse correctly with brackets',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              headers: {'host': '[::1:1]:1'},
              touchHeaders: (final h) => h.host,
            );

            expect(headers.host?.port, equals(1));
          },
        );

        test(
          'when IPv6 with multiple consecutive numbers is passed '
          'then it should parse correctly with brackets',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              headers: {'host': '[2001:0:0:0:0:0:0:8080]'},
              touchHeaders: (final h) => h.host,
            );

            expect(headers.host,
                equals(HostHeader('[2001:0:0:0:0:0:0:8080]', null)));
          },
        );

        test(
          'when IPv6 with embedded IPv4 ending in port-like numbers is passed '
          'then it should parse correctly with brackets',
          () async {
            final headers = await getServerRequestHeaders(
              server: server,
              headers: {'host': '[64:ff9b::192.0.2.80]:80'},
              touchHeaders: (final h) => h.host,
            );

            expect(headers.host?.port, equals(80));
          },
        );

        // Note: Unbracketed IPv6 addresses like '::1' cannot be tested here
        // because they cause URL parsing failures at the HTTP client level
        // before reaching the header validation logic. This demonstrates
        // why RFC 3986 requires brackets for all IPv6 addresses in URIs.
      });
    });
  });
}
