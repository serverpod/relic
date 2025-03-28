import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';

import '../headers_test_utils.dart';
import '../docs/strict_validation_docs.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control
/// About empty value test, check the [StrictValidationDocs] class for more details.
void main() {
  group('Given a Cache-Control header with the strict flag true', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: true);
    });

    tearDown(() => server.close());

    test(
      'when an empty Cache-Control header is passed then the server responds '
      'with a bad request including a message that states the header value '
      'cannot be empty',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            touchHeaders: (h) => h.cacheControl,
            headers: {'cache-control': ''},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (e) => e.message,
              'message',
              contains('Directives cannot be empty'),
            ),
          ),
        );
      },
    );

    test(
      'when an invalid Cache-Control directive is passed then the server responds '
      'with a bad request including a message that states the directive is invalid',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            touchHeaders: (h) => h.cacheControl,
            headers: {'cache-control': 'invalid-directive'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (e) => e.message,
              'message',
              contains('Invalid directive'),
            ),
          ),
        );
      },
    );

    test(
      'when a Cache-Control header with an invalid directive is passed then the server responds '
      'with a bad request including a message that states the directive is invalid',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            touchHeaders: (h) => h.cacheControl,
            headers: {'cache-control': 'public, invalid-directive'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (e) => e.message,
              'message',
              contains('Invalid directive'),
            ),
          ),
        );
      },
    );

    test(
      'when a Cache-Control header with both public and private is passed then the server responds '
      'with a bad request including a message that states the directives cannot be both public and private',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            touchHeaders: (h) => h.cacheControl,
            headers: {'cache-control': 'public, private'},
          ),
          throwsA(
            isA<BadRequestException>().having(
              (e) => e.message,
              'message',
              contains('Cannot be both public and private'),
            ),
          ),
        );
      },
    );

    test(
      'when a Cache-Control header with both max-age and stale-while-revalidate is passed then the server responds '
      'with a bad request including a message that states the directives cannot be both max-age and stale-while-revalidate',
      () async {
        expect(
          () async => await getServerRequestHeaders(
            server: server,
            touchHeaders: (h) => h.cacheControl,
            headers: {
              'cache-control': 'max-age=3600, stale-while-revalidate=300'
            },
          ),
          throwsA(
            isA<BadRequestException>().having(
              (e) => e.message,
              'message',
              contains(
                'Cannot have both max-age and stale-while-revalidate directives',
              ),
            ),
          ),
        );
      },
    );

    test(
      'when a Cache-Control header with an invalid value is passed '
      'then the server does not respond with a bad request if the headers '
      'is not actually used',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (_) {},
          headers: {},
        );

        expect(headers, isNotNull);
      },
    );

    test(
      'when a valid Cache-Control header is passed then it should parse the directives correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.cacheControl,
          headers: {'cache-control': 'no-cache, no-store, must-revalidate'},
        );

        expect(headers.cacheControl?.noCache, isTrue);
        expect(headers.cacheControl?.noStore, isTrue);
        expect(headers.cacheControl?.mustRevalidate, isTrue);
      },
    );

    test(
      'when a Cache-Control header with max-age is passed then it should parse the max-age correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.cacheControl,
          headers: {'cache-control': 'max-age=3600'},
        );

        expect(headers.cacheControl?.maxAge, equals(3600));
      },
    );

    test(
      'when a Cache-Control header with s-maxage is passed then it should parse the s-maxage correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.cacheControl,
          headers: {'cache-control': 's-maxage=7200'},
        );

        expect(headers.cacheControl?.sMaxAge, equals(7200));
      },
    );

    test(
      'when a Cache-Control header with stale-while-revalidate is passed then it should parse the directive correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.cacheControl,
          headers: {'cache-control': 'stale-while-revalidate=300'},
        );

        expect(headers.cacheControl?.staleWhileRevalidate, equals(300));
      },
    );

    test(
      'when a Cache-Control header with stale-if-error is passed then it should parse the directive correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.cacheControl,
          headers: {'cache-control': 'stale-if-error=600'},
        );

        expect(headers.cacheControl?.staleIfError, equals(600));
      },
    );

    test(
      'when a Cache-Control header with max-stale is passed then it should parse the directive correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.cacheControl,
          headers: {'cache-control': 'max-stale=100'},
        );

        expect(headers.cacheControl?.maxStale, equals(100));
      },
    );

    test(
      'when a Cache-Control header with min-fresh is passed then it should parse the directive correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.cacheControl,
          headers: {'cache-control': 'min-fresh=200'},
        );

        expect(headers.cacheControl?.minFresh, equals(200));
      },
    );

    test(
      'when a Cache-Control header with public is passed then it should parse the directive correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.cacheControl,
          headers: {'cache-control': 'public'},
        );

        expect(headers.cacheControl?.publicCache, isTrue);
      },
    );

    test(
      'when a Cache-Control header with private is passed then it should parse the directive correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.cacheControl,
          headers: {'cache-control': 'private'},
        );

        expect(headers.cacheControl?.privateCache, isTrue);
      },
    );

    test(
      'when a Cache-Control header with no-transform is passed then it should parse the directive correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.cacheControl,
          headers: {'cache-control': 'no-transform'},
        );

        expect(headers.cacheControl?.noTransform, isTrue);
      },
    );

    test(
      'when a Cache-Control header with only-if-cached is passed then it should parse the directive correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.cacheControl,
          headers: {'cache-control': 'only-if-cached'},
        );

        expect(headers.cacheControl?.onlyIfCached, isTrue);
      },
    );

    test(
      'when a Cache-Control header with immutable is passed then it should parse the directive correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.cacheControl,
          headers: {'cache-control': 'immutable'},
        );

        expect(headers.cacheControl?.immutable, isTrue);
      },
    );

    test(
      'when a Cache-Control header with must-understand is passed then it should parse the directive correctly',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.cacheControl,
          headers: {'cache-control': 'must-understand'},
        );

        expect(headers.cacheControl?.mustUnderstand, isTrue);
      },
    );

    test(
      'when no Cache-Control header is passed then it should return null',
      () async {
        var headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (h) => h.cacheControl,
          headers: {},
        );

        expect(headers.cacheControl, isNull);
      },
    );
  });

  group('Given a Cache-Control header with the strict flag false', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer(strictHeaders: false);
    });

    tearDown(() => server.close());

    group('when an invalid Cache-Control header is passed', () {
      test(
        'then it should return null',
        () async {
          var headers = await getServerRequestHeaders(
            server: server,
            touchHeaders: (_) {},
            headers: {'cache-control': 'invalid-directive'},
          );

          expect(Headers.cacheControl[headers].valueOrNullIfInvalid, isNull);
          expect(() => headers.cacheControl, throwsInvalidHeader);
        },
      );
    });
  });
}
