import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../util/test_util.dart';

void main() {
  group('Router Method Specific Tests', () {
    late Router<String> router;

    setUp(() {
      router = Router<String>();
    });

    parameterizedGroup(
      variants:
          <Method, void Function(String, String) Function(Router<String>)>{
        Method.get: (final r) => r.get,
        Method.head: (final r) => r.head,
        Method.post: (final r) => r.post,
        Method.put: (final r) => r.put,
        Method.delete: (final r) => r.delete,
        Method.patch: (final r) => r.patch,
        Method.options: (final r) => r.options,
        Method.trace: (final r) => r.trace,
        Method.connect: (final r) => r.connect,
      }.entries,
      (final v) =>
          'Given router.${v.key.name} used to register a handler for a path,',
      (final v) {
        test(
          'when looking up with ${v.key} for that path, '
          'then returns the correct handler',
          () {
            v.value(router)('/path', 'handler'); // register handler
            final result = router.lookup(v.key, '/path');
            expect(result, isNotNull);
            expect(result!.value, 'handler');
          },
        );

        parameterizedTest(
          (final vv) => 'when looking up with $vv for that path, '
              'then returns null',
          (final vv) {
            final result = router.lookup(vv, '/path');
            expect(result, isNull);
          },
          // all other verbs
          variants: Method.values.toSet().difference({v.key}).toList(),
        );
      },
    );

    test(
        'Given a GET handler registered for a path, '
        'when looking up with Method.post for the same path, '
        'then returns null', () {
      router.get('/specific-method-mismatch', 'get_handler');
      final result = router.lookup(Method.post, '/specific-method-mismatch');
      expect(result, isNull);
    });

    group('ANY Method Registration (router.any)', () {
      test(
          'Given router.any() used to register a handler, '
          'when looking up with Method.get for that path, '
          'then returns the handler registered by any()', () {
        router.any('/any-path', 'any_handler');
        final result = router.lookup(Method.get, '/any-path');
        expect(result, isNotNull);
        expect(result!.value, 'any_handler');
      });

      test(
          'Given router.any() used to register a handler, '
          'when looking up with Method.post for that path, '
          'then returns the handler registered by any()', () {
        router.any('/any-path', 'any_handler');
        final result = router.lookup(Method.post, '/any-path');
        expect(result, isNotNull);
        expect(result!.value, 'any_handler');
      });

      test(
          'Given router.any() used to register a handler, '
          'when looking up with all defined methods for that path, '
          'then returns the handler registered by any() for each method', () {
        router.any('/any-path-all-methods', 'any_handler_all');
        for (final method in Method.values) {
          final result = router.lookup(method, '/any-path-all-methods');
          expect(result, isNotNull, reason: 'Expected handler for $method');
          expect(result!.value, 'any_handler_all',
              reason: 'Expected correct value for $method');
        }
      });
    });

    group('Method Registration Conflicts', () {
      test(
          'Given a GET handler registered via router.get(), '
          'when attempting to register another GET handler for the same path via router.get(), '
          'then throws ArgumentError', () {
        router.get('/conflict-path', 'get_handler_1');
        expect(
          () => router.get('/conflict-path', 'get_handler_2'),
          throwsArgumentError,
        );
      });

      test(
          'Given a GET handler registered via router.add(), '
          'when attempting to register another GET handler for the same path via router.add(), '
          'then throws ArgumentError', () {
        router.add(Method.get, '/conflict-add-path', 'get_handler_add_1');
        expect(
          () =>
              router.add(Method.get, '/conflict-add-path', 'get_handler_add_2'),
          throwsArgumentError,
        );
      });

      test(
          'Given router.any() used for a path, '
          'when attempting to register a specific GET handler for the same path, '
          'then throws ArgumentError', () {
        router.any('/any-conflict-path', 'any_handler_conflict');
        expect(
          () => router.get('/any-conflict-path', 'get_handler_conflict'),
          throwsArgumentError,
        );
      });

      test(
          'Given a specific GET handler registered for a path, '
          'when attempting to use router.any() for the same path, '
          'then throws ArgumentError (on the first conflicting method, which is GET)',
          () {
        router.get('/specific-conflict-path', 'get_handler_specific_conflict');
        expect(
          () => router.any(
              '/specific-conflict-path', 'any_handler_specific_conflict'),
          throwsArgumentError,
        );
      });

      test(
          'Given GET and POST handlers registered for different paths, '
          'when looking them up, '
          'then each returns their correct handler (no cross-path interference)',
          () {
        router.get('/path-alpha', 'get_alpha');
        router.post('/path-beta', 'post_beta');

        final resultAlpha = router.lookup(Method.get, '/path-alpha');
        expect(resultAlpha, isNotNull);
        expect(resultAlpha!.value, 'get_alpha');
        expect(router.lookup(Method.post, '/path-alpha'), isNull);

        final resultBeta = router.lookup(Method.post, '/path-beta');
        expect(resultBeta, isNotNull);
        expect(resultBeta!.value, 'post_beta');
        expect(router.lookup(Method.get, '/path-beta'), isNull);
      });
    });

    group('Method Handling with Parameters', () {
      test(
          'Given a GET handler for a parameterized path /users/:id, '
          'when looking up with Method.get and a matching path, '
          'then returns the handler and correct parameters', () {
        router.get('/users/:id', 'get_user_handler');
        final result = router.lookup(Method.get, '/users/123');
        expect(result, isNotNull);
        expect(result!.value, 'get_user_handler');
        expect(result.parameters, equals({#id: '123'}));
      });

      test(
          'Given a POST handler for a parameterized path /posts/:postId/comments, '
          'when looking up with Method.post and a matching path, '
          'then returns the handler and correct parameters', () {
        router.post('/posts/:postId/comments', 'post_comment_handler');
        final result = router.lookup(Method.post, '/posts/abc/comments');
        expect(result, isNotNull);
        expect(result!.value, 'post_comment_handler');
        expect(result.parameters, equals({#postId: 'abc'}));
      });

      test(
          'Given GET and POST handlers for the same parameterized path /data/:key, '
          'when looking up with Method.get, then returns GET handler, '
          'when looking up with Method.post, then returns POST handler', () {
        router.get('/data/:key', 'get_data_handler');
        router.post('/data/:key', 'post_data_handler');

        final getResult = router.lookup(Method.get, '/data/xyz');
        expect(getResult, isNotNull);
        expect(getResult!.value, 'get_data_handler');
        expect(getResult.parameters, equals({#key: 'xyz'}));

        final postResult = router.lookup(Method.post, '/data/xyz');
        expect(postResult, isNotNull);
        expect(postResult!.value, 'post_data_handler');
        expect(postResult.parameters, equals({#key: 'xyz'}));
      });

      test(
          'Given a GET handler for parameterized path /files/:name, '
          'when looking up with Method.put for the same path pattern, '
          'then returns null', () {
        router.get('/files/:name', 'get_file_handler');
        final result = router.lookup(Method.put, '/files/report.txt');
        expect(result, isNull);
      });

      test(
          'Given router.any() for a parameterized path /items/:itemId, '
          'when looking up with Method.delete and matching path, '
          'then returns the any_handler and correct parameters', () {
        router.any('/items/:itemId', 'any_item_handler');
        final result = router.lookup(Method.delete, '/items/item001');
        expect(result, isNotNull);
        expect(result!.value, 'any_item_handler');
        expect(result.parameters, equals({#itemId: 'item001'}));
      });
    });

    group('Lookup for Unregistered Paths/Methods', () {
      test(
          'Given an empty router, '
          'when looking up any path with any method, '
          'then returns null', () {
        final result = router.lookup(Method.get, '/nonexistent');
        expect(result, isNull);
      });

      test(
          'Given a router with some registrations, '
          'when looking up a completely different path, '
          'then returns null', () {
        router.get('/exists', 'handler_exists');
        final result = router.lookup(Method.get, '/does-not-exist');
        expect(result, isNull);
      });

      test(
          'Given a GET handler for /path, '
          'when looking up /path with Method.post, '
          'then returns null', () {
        router.get('/another-path', 'get_another');
        final result = router.lookup(Method.post, '/another-path');
        expect(result, isNull);
      });
    });
  });
}
