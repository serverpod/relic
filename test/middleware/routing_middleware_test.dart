import 'package:relic/relic.dart';
import 'package:relic/src/context/context.dart';
import 'package:test/test.dart';

import '../util/test_util.dart';

Request _request(
  final String path, {
  final String host = 'localhost',
  final Method method = Method.get,
}) => Request(method, Uri.http(host, path));

void main() {
  group('RoutingMiddleware', () {
    late RelicRouter router;
    late Middleware middleware;

    setUp(() {
      router = RelicRouter();
      middleware = routeWith(router);
    });

    group('Parameter Propagation', () {
      test('Given a router with a parameterized route and RoutingMiddleware, '
          'When a request matches the parameterized route, '
          'Then the handler receives correct path parameters', () async {
        Map<Symbol, String>? capturedParams;
        Future<HandledContext> testHandler(final Request ctx) async {
          capturedParams = ctx.pathParameters;
          return Response(200);
        }

        router.add(Method.get, '/users/:id', testHandler);

        final initialCtx = _request('/users/123')..setToken(Object());
        final resultingCtx = await middleware(
          respondWith((_) => Response(404)),
        )(initialCtx);

        expect(capturedParams, isNotNull);
        expect(capturedParams, equals({#id: '123'}));
        expect(resultingCtx, isA<ResponseContext>());
        final response = (resultingCtx as ResponseContext).response;
        expect(response.statusCode, equals(200));
      });

      test(
        'Given a router with a non-parameterized route and RoutingMiddleware, '
        'When a request matches the non-parameterized route, '
        'Then the handler receives empty path parameters',
        () async {
          Map<Symbol, String>? capturedParams;
          Future<ResponseContext> testHandler(final Request ctx) async {
            capturedParams = ctx.pathParameters;
            return Response(200);
          }

          router.add(Method.get, '/users', testHandler);

          final initialCtx = _request('/users')..setToken(Object());
          final resultingCtx = await middleware(
            respondWith((_) => Response(404)),
          )(initialCtx);

          expect(capturedParams, isNotNull);
          expect(capturedParams, isEmpty);
          expect(resultingCtx, isA<ResponseContext>());
          final response = (resultingCtx as ResponseContext).response;
          expect(response.statusCode, equals(200));
        },
      );

      test(
        'Given RoutingMiddleware and a request that does not match any route, '
        'When the middleware processes the request, '
        'Then the next handler is called and pathParameters is empty',
        () async {
          bool nextCalled = false;
          Future<ResponseContext> nextHandler(final Request ctx) async {
            nextCalled = true;
            expect(ctx.pathParameters, isEmpty);
            return Response(404);
          }

          final initialCtx = _request('/nonexistent')..setToken(Object());
          final resultingCtx = await middleware(nextHandler)(initialCtx);

          expect(nextCalled, isTrue);
          expect(resultingCtx, isA<ResponseContext>());
          final response = (resultingCtx as ResponseContext).response;
          expect(response.statusCode, equals(404));
        },
      );
    });

    group('Multiple RoutingMiddleware in Pipeline', () {
      late RelicRouter router1;
      late RelicRouter router2;
      late Pipeline pipeline;

      setUp(() {
        router1 = RelicRouter();
        router2 = RelicRouter();
        pipeline = const Pipeline()
            .addMiddleware(routeWith(router1))
            .addMiddleware(routeWith(router2));
        // just missing the handler
      });

      test(
        'Given two RoutingMiddleware instances in a pipeline, '
        'When a request matches a route in the first router, '
        'Then the handler from the first router is executed with correct parameters',
        () async {
          Map<Symbol, String>? params1;
          bool handler1Called = false;
          bool handler2Called = false;

          router1.add(Method.get, '/router1/:item', (final Request ctx) async {
            handler1Called = true;
            params1 = ctx.pathParameters;
            return Response(201);
          });
          router2.add(
            Method.get,
            '/router2/:item',
            respondWith((_) {
              handler2Called = true;
              return Response(202);
            }),
          );

          final pipelineHandler = pipeline.addHandler(
            respondWith((_) => Response(404)),
          );

          final initialCtx = _request('/router1/apple')..setToken(Object());
          final resultingCtx = await pipelineHandler(initialCtx);
          final response = (resultingCtx as ResponseContext).response;

          expect(handler1Called, isTrue);
          expect(handler2Called, isFalse);
          expect(response.statusCode, equals(201));
          expect(params1, equals({#item: 'apple'}));
        },
      );

      test(
        'Given two RoutingMiddleware instances in a pipeline, '
        'When a request matches a route in the second router (but not the first), '
        'Then the handler from the second router is executed with correct parameters',
        () async {
          Map<Symbol, String>? params2;
          bool handler1Called = false;
          bool handler2Called = false;

          router1.add(
            Method.get,
            '/router1/:item',
            respondWith((_) {
              handler1Called = true;
              return Response(201);
            }),
          );
          router2.add(Method.get, '/router2/:data', (final Request ctx) async {
            handler2Called = true;
            params2 = ctx.pathParameters;
            return Response(202);
          });

          final pipelineHandler = pipeline.addHandler(
            respondWith((_) => Response(404)),
          );

          final initialCtx = _request('/router2/banana')..setToken(Object());
          final resultingCtx = await pipelineHandler(initialCtx);
          final response = (resultingCtx as ResponseContext).response;

          expect(handler1Called, isFalse);
          expect(handler2Called, isTrue);
          expect(response.statusCode, equals(202));
          expect(params2, equals({#data: 'banana'}));
        },
      );

      test('Given two RoutingMiddleware instances in a pipeline, '
          'When a request does not match any route in either router, '
          'Then the final next handler is called', () async {
        bool handler1Called = false;
        bool handler2Called = false;
        bool fallbackCalled = false;

        router1.add(
          Method.get,
          '/router1/:item',
          respondWith((_) {
            handler1Called = true;
            return Response(201);
          }),
        );
        router2.add(
          Method.get,
          '/router2/:data',
          respondWith((_) {
            handler2Called = true;
            return Response(202);
          }),
        );

        final pipelineHandler = pipeline.addHandler(
          respondWith((_) {
            fallbackCalled = true;
            return Response(404);
          }),
        );

        final initialCtx = _request('/neither/nor')..setToken(Object());
        final resultingCtx = await pipelineHandler(initialCtx);
        final response = (resultingCtx as ResponseContext).response;

        expect(handler1Called, isFalse);
        expect(handler2Called, isFalse);
        expect(fallbackCalled, isTrue);
        expect(response.statusCode, equals(404));
      });
    });

    group('Nested RoutingMiddleware (via Router.attach)', () {
      test(
        'Given a main Router with a nested Router attached, and RoutingMiddleware for the main Router, '
        'When a request matches a route within the nested Router, '
        'Then the handler from the nested Router is executed with merged path parameters',
        () async {
          Map<Symbol, String>? capturedParams;
          bool nestedHandlerCalled = false;

          final mainRouter = RelicRouter();
          final nestedRouter = RelicRouter();

          nestedRouter.add(Method.get, '/details/:detailId', (
            final Request ctx,
          ) async {
            nestedHandlerCalled = true;
            capturedParams = ctx.pathParameters;
            return Response(200);
          });

          // Attach nestedRouter to mainRouter under /resource/:resourceId
          mainRouter.attach('/resource/:resourceId', nestedRouter);
          mainRouter.fallback = respondWith((_) => Response(404));

          final pipelineHandler = mainRouter.asHandler;

          final initialCtx = _request('/resource/abc/details/xyz')
            ..setToken(Object());
          final resultingCtx = await pipelineHandler(initialCtx);
          final response = (resultingCtx as ResponseContext).response;

          expect(nestedHandlerCalled, isTrue);
          expect(response.statusCode, equals(200));
          expect(capturedParams, isNotNull);
          expect(
            capturedParams,
            equals({#resourceId: 'abc', #detailId: 'xyz'}),
          );
        },
      );

      test(
        'Given a main Router with a nested Router (that itself has parameters at its root) attached, '
        'When a request matches, '
        'Then parameters from both levels are correctly captured',
        () async {
          // This test addresses the user's note about potential errors in nested routing.
          // The key is that Router.lookup should correctly merge parameters.
          Map<Symbol, String>? capturedParams;
          bool deeplyNestedHandlerCalled = false;

          final mainRouter = RelicRouter();
          final intermediateRouter =
              RelicRouter(); // Will be attached to mainRouter
          final leafRouter =
              RelicRouter(); // Will be attached to intermediateRouter

          // Define handler for the leaf router
          leafRouter.add(Method.get, '/action/:actionName', (
            final Request ctx,
          ) async {
            deeplyNestedHandlerCalled = true;
            capturedParams = ctx.pathParameters;
            return Response(200);
          });

          // Attach leafRouter to intermediateRouter under a parameterized path
          intermediateRouter.attach('/:intermediateId', leafRouter);

          // Attach intermediateRouter to mainRouter under a parameterized path
          mainRouter.attach('/base/:baseId', intermediateRouter);
          mainRouter.fallback = respondWith((_) => Response(404));

          final pipelineHandler = mainRouter.asHandler;

          final initialCtx = _request('/base/b123/i456/action/doSomething')
            ..setToken(Object());
          final resultingCtx = await pipelineHandler(initialCtx);
          final response = (resultingCtx as ResponseContext).response;

          expect(deeplyNestedHandlerCalled, isTrue);
          expect(response.statusCode, equals(200));
          expect(capturedParams, isNotNull);
          expect(
            capturedParams,
            equals({
              #baseId: 'b123',
              #intermediateId: 'i456',
              #actionName: 'doSomething',
            }),
          );
        },
      );

      test(
        'Given a path with repeated parameters at different levels introduced by attach, '
        'When looked up via RoutingMiddleware, '
        'Then last extracted parameter wins (consistent with PathTrie behavior)',
        () async {
          Map<Symbol, String>? capturedParams;
          final mainRouter = RelicRouter();
          final subRouter = RelicRouter();

          subRouter.add(Method.get, '/:id/end', (final Request ctx) async {
            // sub-router uses :id
            capturedParams = ctx.pathParameters;
            return Response(200);
          });

          mainRouter.attach('/:id/sub', subRouter); // main router uses :id
          mainRouter.fallback = respondWith((_) => Response(404));

          final pipeline = mainRouter.asHandler;

          final initialCtx = _request('/123/sub/456/end')..setToken(Object());
          final resultingCtx = await pipeline(initialCtx);
          final response = (resultingCtx as ResponseContext).response;

          expect(response.statusCode, 200);
          expect(capturedParams, isNotNull);
          // PathTrie's behavior is that the parameter from the deeper segment wins.
          // Full path: /:id/sub/:id/end -> /123/sub/456/end
          // Parameters: {#id: '123', #id: '456'} -> {#id: '456'}
          expect(capturedParams, equals({#id: '456'}));
        },
      );
    });
  });

  test('Given `routeWith` adapting a `Router<String>`, '
      'When a request matches a route, '
      "Then the `toHandler` processes the route's string value", () async {
    final strRouter = Router<String>()..add(Method.get, '/', 'Hurrah!');
    final mw = routeWith<String>(
      strRouter,
      toHandler:
          (final s) =>
              respondWith((_) => Response.ok(body: Body.fromString(s))),
    );

    final ctx = _request('/')..setToken(Object());
    final resCtx =
        await mw(respondWith((_) => Response.notFound()))(ctx)
            as ResponseContext;

    expect(resCtx.response.statusCode, 200);
    expect(await resCtx.response.readAsString(), 'Hurrah!');
  });

  // Due to the decoupling of Router<T> a mapping has to happen
  // for verbs. These test ensures all mappings are exercised.
  parameterizedTest(
    variants: Method.values,
    (final v) =>
        'Given a route for verb: "${v.value}", '
        'when responding, '
        'then the request.method is "$v"',
    (final v) async {
      late Method method;
      final middleware = routeWith(
        RelicRouter()..add(
          v,
          '/',
          respondWith((final req) {
            method = req.method;
            return Response.ok();
          }),
        ),
      );
      final request = _request('/', method: v);
      final newCtx = await middleware(respondWith((_) => Response.notFound()))(
        request..setToken(Object()),
      );
      expect(newCtx, isA<ResponseContext>());
      final response = (newCtx as ResponseContext).response;
      expect(response.statusCode, 200);
      expect(method, equals(v));
    },
  );

  group('Method Not Allowed (405) responses', () {
    late RelicRouter router;
    late Middleware middleware;

    setUp(() {
      router = RelicRouter();
      middleware = routeWith(router);
    });

    test('Given a router with GET route only, '
        'when a POST request is made to the same path, '
        'then a 405 response is returned', () async {
      router.add(Method.get, '/users', respondWith((_) => Response(200)));

      final initialCtx = _request('/users', method: Method.post)
        ..setToken(Object());
      final resultingCtx = await middleware(respondWith((_) => Response(404)))(
        initialCtx,
      );

      expect(resultingCtx, isA<ResponseContext>());
      final response = (resultingCtx as ResponseContext).response;
      expect(response.statusCode, 405);
    });

    test('Given a router with GET route only, '
        'when a POST request is made to the same path, '
        'then the Allow header contains GET', () async {
      router.add(Method.get, '/users', respondWith((_) => Response(200)));

      final initialCtx = _request('/users', method: Method.post)
        ..setToken(Object());
      final resultingCtx = await middleware(respondWith((_) => Response(404)))(
        initialCtx,
      );

      expect(resultingCtx, isA<ResponseContext>());
      final response = (resultingCtx as ResponseContext).response;
      expect(response.statusCode, 405);
      expect(response.headers.allow, contains(Method.get));
    });

    test('Given a router with GET and POST routes for the same path, '
        'when a PUT request is made to that path, '
        'then the Allow header contains both GET and POST', () async {
      router.add(Method.get, '/users', respondWith((_) => Response(200)));
      router.add(Method.post, '/users', respondWith((_) => Response(201)));

      final initialCtx = _request('/users', method: Method.put)
        ..setToken(Object());
      final resultingCtx = await middleware(respondWith((_) => Response(404)))(
        initialCtx,
      );

      expect(resultingCtx, isA<ResponseContext>());
      final response = (resultingCtx as ResponseContext).response;
      expect(response.statusCode, 405);
      final allowedMethods = response.headers.allow;
      expect(allowedMethods, unorderedEquals([Method.get, Method.post]));
    });

    test('Given a router with multiple HTTP methods for a parameterized route, '
        'when a non-matching method is used with valid parameters, '
        'then a 405 response is returned with correct Allow header', () async {
      router.add(Method.get, '/users/:id', respondWith((_) => Response(200)));
      router.add(
        Method.delete,
        '/users/:id',
        respondWith((_) => Response(204)),
      );

      final initialCtx = _request('/users/123', method: Method.patch)
        ..setToken(Object());
      final resultingCtx = await middleware(respondWith((_) => Response(404)))(
        initialCtx,
      );

      expect(resultingCtx, isA<ResponseContext>());
      final response = (resultingCtx as ResponseContext).response;
      expect(response.statusCode, 405);
      final allowedMethods = response.headers.allow;
      expect(allowedMethods, unorderedEquals([Method.get, Method.delete]));
    });

    test('Given a router with routes that do not match the requested path, '
        'when a request is made, '
        'then next handler is called (path miss, not 405)', () async {
      router.add(Method.get, '/users', respondWith((_) => Response(200)));

      bool nextCalled = false;
      final initialCtx = _request('/posts', method: Method.get)
        ..setToken(Object());
      final resultingCtx = await middleware((final ctx) async {
        nextCalled = true;
        return Response(404);
      })(initialCtx);

      expect(nextCalled, isTrue);
      expect(resultingCtx, isA<ResponseContext>());
      final response = (resultingCtx as ResponseContext).response;
      expect(response.statusCode, isNot(405));
    });
  });
}
