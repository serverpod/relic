import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';
import 'package:test_utils/test_utils.dart';

Request _request(
  final String path, {
  final String host = 'localhost',
  final Method method = Method.get,
}) => RequestInternal.create(method, Uri.http(host, path), Object());

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
        Future<Result> testHandler(final Request req) async {
          capturedParams = req.rawPathParameters;
          return Response(200);
        }

        router.add(Method.get, '/users/:id', testHandler);

        final initialCtx = _request('/users/123');
        final resultingCtx = await middleware(
          respondWith((_) => Response(404)),
        )(initialCtx);

        expect(capturedParams, isNotNull);
        expect(capturedParams, equals({#id: '123'}));
        expect(resultingCtx, isA<Response>());
        final response = (resultingCtx as Response);
        expect(response.statusCode, equals(200));
      });

      test(
        'Given a router with a non-parameterized route and RoutingMiddleware, '
        'When a request matches the non-parameterized route, '
        'Then the handler receives empty path parameters',
        () async {
          Map<Symbol, String>? capturedParams;
          Future<Response> testHandler(final Request req) async {
            capturedParams = req.rawPathParameters;
            return Response(200);
          }

          router.add(Method.get, '/users', testHandler);

          final initialCtx = _request('/users');
          final resultingCtx = await middleware(
            respondWith((_) => Response(404)),
          )(initialCtx);

          expect(capturedParams, isNotNull);
          expect(capturedParams, isEmpty);
          expect(resultingCtx, isA<Response>());
          final response = (resultingCtx as Response);
          expect(response.statusCode, equals(200));
        },
      );

      test(
        'Given RoutingMiddleware and a request that does not match any route, '
        'When the middleware processes the request, '
        'Then the next handler is called and rawPathParameters is empty',
        () async {
          bool nextCalled = false;
          Future<Response> nextHandler(final Request req) async {
            nextCalled = true;
            expect(req.rawPathParameters, isEmpty);
            return Response(404);
          }

          final initialCtx = _request('/nonexistent');
          final resultingCtx = await middleware(nextHandler)(initialCtx);

          expect(nextCalled, isTrue);
          expect(resultingCtx, isA<Response>());
          final response = (resultingCtx as Response);
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

          router1.add(Method.get, '/router1/:item', (final Request req) async {
            handler1Called = true;
            params1 = req.rawPathParameters;
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

          final initialCtx = _request('/router1/apple');
          final resultingCtx = await pipelineHandler(initialCtx);
          final response = (resultingCtx as Response);

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
          router2.add(Method.get, '/router2/:data', (final Request req) async {
            handler2Called = true;
            params2 = req.rawPathParameters;
            return Response(202);
          });

          final pipelineHandler = pipeline.addHandler(
            respondWith((_) => Response(404)),
          );

          final initialCtx = _request('/router2/banana');
          final resultingCtx = await pipelineHandler(initialCtx);
          final response = (resultingCtx as Response);

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

        final initialCtx = _request('/neither/nor');
        final resultingCtx = await pipelineHandler(initialCtx);
        final response = (resultingCtx as Response);

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
            final Request req,
          ) async {
            nestedHandlerCalled = true;
            capturedParams = req.rawPathParameters;
            return Response(200);
          });

          // Attach nestedRouter to mainRouter under /resource/:resourceId
          mainRouter.attach('/resource/:resourceId', nestedRouter);
          mainRouter.fallback = respondWith((_) => Response(404));

          final pipelineHandler = mainRouter.asHandler;

          final initialCtx = _request('/resource/abc/details/xyz');
          final resultingCtx = await pipelineHandler(initialCtx);
          final response = (resultingCtx as Response);

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
            final Request req,
          ) async {
            deeplyNestedHandlerCalled = true;
            capturedParams = req.rawPathParameters;
            return Response(200);
          });

          // Attach leafRouter to intermediateRouter under a parameterized path
          intermediateRouter.attach('/:intermediateId', leafRouter);

          // Attach intermediateRouter to mainRouter under a parameterized path
          mainRouter.attach('/base/:baseId', intermediateRouter);
          mainRouter.fallback = respondWith((_) => Response(404));

          final pipelineHandler = mainRouter.asHandler;

          final initialCtx = _request('/base/b123/i456/action/doSomething');
          final resultingCtx = await pipelineHandler(initialCtx);
          final response = (resultingCtx as Response);

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

          subRouter.add(Method.get, '/:id/end', (final Request req) async {
            // sub-router uses :id
            capturedParams = req.rawPathParameters;
            return Response(200);
          });

          mainRouter.attach('/:id/sub', subRouter); // main router uses :id
          mainRouter.fallback = respondWith((_) => Response(404));

          final pipeline = mainRouter.asHandler;

          final initialCtx = _request('/123/sub/456/end');
          final resultingCtx = await pipeline(initialCtx);
          final response = (resultingCtx as Response);

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
      toHandler: (final s) =>
          respondWith((_) => Response.ok(body: Body.fromString(s))),
    );

    final req = _request('/');
    final resCtx =
        await mw(respondWith((_) => Response.notFound()))(req) as Response;

    expect(resCtx.statusCode, 200);
    expect(await resCtx.readAsString(), 'Hurrah!');
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
        request,
      );
      expect(newCtx, isA<Response>());
      final response = (newCtx as Response);
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

      final initialCtx = _request('/users', method: Method.post);
      final resultingCtx = await middleware(respondWith((_) => Response(404)))(
        initialCtx,
      );

      expect(resultingCtx, isA<Response>());
      final response = (resultingCtx as Response);
      expect(response.statusCode, 405);
    });

    test('Given a router with GET route only, '
        'when a POST request is made to the same path, '
        'then the Allow header contains GET', () async {
      router.add(Method.get, '/users', respondWith((_) => Response(200)));

      final initialCtx = _request('/users', method: Method.post);
      final resultingCtx = await middleware(respondWith((_) => Response(404)))(
        initialCtx,
      );

      expect(resultingCtx, isA<Response>());
      final response = (resultingCtx as Response);
      expect(response.statusCode, 405);
      expect(response.headers.allow, contains(Method.get));
    });

    test('Given a router with GET and POST routes for the same path, '
        'when a PUT request is made to that path, '
        'then the Allow header contains both GET and POST', () async {
      router.add(Method.get, '/users', respondWith((_) => Response(200)));
      router.add(Method.post, '/users', respondWith((_) => Response(201)));

      final initialCtx = _request('/users', method: Method.put);
      final resultingCtx = await middleware(respondWith((_) => Response(404)))(
        initialCtx,
      );

      expect(resultingCtx, isA<Response>());
      final response = (resultingCtx as Response);
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

      final initialCtx = _request('/users/123', method: Method.patch);
      final resultingCtx = await middleware(respondWith((_) => Response(404)))(
        initialCtx,
      );

      expect(resultingCtx, isA<Response>());
      final response = (resultingCtx as Response);
      expect(response.statusCode, 405);
      final allowedMethods = response.headers.allow;
      expect(allowedMethods, unorderedEquals([Method.get, Method.delete]));
    });

    test('Given a router with routes that do not match the requested path, '
        'when a request is made, '
        'then next handler is called (path miss, not 405)', () async {
      router.add(Method.get, '/users', respondWith((_) => Response(200)));

      bool nextCalled = false;
      final initialCtx = _request('/posts', method: Method.get);
      final resultingCtx = await middleware((final req) async {
        nextCalled = true;
        return Response(404);
      })(initialCtx);

      expect(nextCalled, isTrue);
      expect(resultingCtx, isA<Response>());
      final response = (resultingCtx as Response);
      expect(response.statusCode, isNot(405));
    });
  });

  group('Virtual hosting', () {
    Handler _createHandler(
      final Router<int> router, {
      final bool useHostWhenRouting = true,
    }) {
      final middleware = routeWith(
        router,
        useHostWhenRouting: useHostWhenRouting,
        toHandler: (final i) =>
            respondWith((final _) => Response.ok(body: Body.fromString('$i'))),
      );
      return const Pipeline()
          .addMiddleware(middleware)
          .addHandler(respondWith((final _) => Response.notFound()));
    }

    // Router with host-specific route (1), and global route (2) for wildcard
    Router<int> _createVirtualHostRouter() {
      final globalRouter = Router<int>()..get('/bar', 2);
      return Router<int>()
        ..get('www.example.org/foo', 1)
        ..attach('www.example.org', globalRouter)
        ..attach('*', globalRouter);
    }

    test('Given virtual hosting enabled, '
        'when a request matches a host-specific route, '
        'then the correct handler is invoked', () async {
      final handler = _createHandler(_createVirtualHostRouter());

      final request = _request('/foo', host: 'www.example.org');
      final result = await handler(request);

      expect(result, isA<Response>());
      final response = result as Response;
      expect(response.statusCode, 200);
      expect(await response.readAsString(), '1');
    });

    test('Given virtual hosting enabled with attached global router, '
        'when a request matches a global route on the configured host, '
        'then the global handler is invoked', () async {
      final handler = _createHandler(_createVirtualHostRouter());

      final request = _request('/bar', host: 'www.example.org');
      final result = await handler(request);

      expect(result, isA<Response>());
      final response = result as Response;
      expect(response.statusCode, 200);
      expect(await response.readAsString(), '2');
    });

    test('Given virtual hosting enabled with wildcard fallback, '
        'when a request from an unknown host matches a global route, '
        'then the global handler is invoked via wildcard', () async {
      final handler = _createHandler(_createVirtualHostRouter());

      final request = _request('/bar', host: 'other.example.com');
      final result = await handler(request);

      expect(result, isA<Response>());
      final response = result as Response;
      expect(response.statusCode, 200);
      expect(await response.readAsString(), '2');
    });

    test('Given virtual hosting enabled, '
        'when a request from an unknown host does not match any route, '
        'then the fallback handler is invoked', () async {
      final handler = _createHandler(_createVirtualHostRouter());

      final request = _request('/unknown', host: 'other.example.com');
      final result = await handler(request);

      expect(result, isA<Response>());
      final response = result as Response;
      expect(response.statusCode, 404);
    });

    test('Given useHostWhenRouting disabled (default), '
        'when a request is made, '
        'then routing ignores the host header', () async {
      final router = Router<int>()..get('/foo', 1);
      final handler = _createHandler(router, useHostWhenRouting: false);

      final request = _request('/foo', host: 'any.host.com');
      final result = await handler(request);

      expect(result, isA<Response>());
      final response = result as Response;
      expect(response.statusCode, 200);
      expect(await response.readAsString(), '1');
    });

    test('Given virtual hosting enabled, '
        'when host header has different case, '
        'then routing normalizes to lowercase (per RFC 3986)', () async {
      final router = Router<int>()..get('www.example.org/foo', 1);
      final handler = _createHandler(router);

      final request = _request('/foo', host: 'WWW.EXAMPLE.ORG');
      final result = await handler(request);

      expect(result, isA<Response>());
      final response = result as Response;
      expect(response.statusCode, 200);
      expect(await response.readAsString(), '1');
    });

    test(
      'Given virtual hosting enabled, '
      'when host header contains port, '
      'then port is stripped from routing path (Uri.host behavior)',
      () async {
        final router = Router<int>()..get('example.com/foo', 1);
        final handler = _createHandler(router);

        // Host with port - port is stripped by Uri.host
        final requestWithPort = _request('/foo', host: 'example.com:8080');
        final resultWithPort = await handler(requestWithPort);
        expect(resultWithPort, isA<Response>());
        expect((resultWithPort as Response).statusCode, 200);
        expect(await resultWithPort.readAsString(), '1');

        // Host without port - same route matches
        final requestWithoutPort = _request('/foo', host: 'example.com');
        final resultWithoutPort = await handler(requestWithoutPort);
        expect(resultWithoutPort, isA<Response>());
        expect((resultWithoutPort as Response).statusCode, 200);
        expect(await resultWithoutPort.readAsString(), '1');
      },
    );
  });

  group('Router ContextProperty', () {
    test('Given a RelicRouter with a route and routeWith middleware, '
        'when a request matches the route, '
        'then req.router returns the router instance', () async {
      final router = RelicRouter();
      RelicRouter? capturedRouter;
      router.get('/test', (final Request req) {
        capturedRouter = req.router;
        return Response.ok();
      });

      final middleware = routeWith(router);
      final request = _request('/test');
      await middleware(respondWith((_) => Response.notFound()))(request);

      expect(capturedRouter, same(router));
    });

    test('Given a request that was not routed, '
        'when accessing req.router, '
        'then it returns null', () {
      final request = _request('/test');
      expect(request.router, isNull);
    });

    test('Given a Router<String> (non-RelicRouter) with routeWith, '
        'when a request matches the route, '
        'then req.router returns null', () async {
      final strRouter = Router<String>()..add(Method.get, '/test', 'hello');
      RelicRouter? capturedRouter;
      final middleware = routeWith<String>(
        strRouter,
        toHandler: (final s) => (final Request req) {
          capturedRouter = req.router;
          return Response.ok(body: Body.fromString(s));
        },
      );

      final request = _request('/test');
      await middleware(respondWith((_) => Response.notFound()))(request);

      expect(capturedRouter, isNull);
    });

    test('Given a RelicRouter used via asHandler, '
        'when a request matches the route, '
        'then req.router returns the router instance', () async {
      final router = RelicRouter();
      RelicRouter? capturedRouter;
      router.get('/test', (final Request req) {
        capturedRouter = req.router;
        return Response.ok();
      });

      final request = _request('/test');
      await router.asHandler(request);

      expect(capturedRouter, same(router));
    });
  });

  group('forwardTo', () {
    test('Given a router with two routes, '
        'when a handler forwards to a different path, '
        'then the forwarded route handler is invoked', () async {
      final router = RelicRouter();

      router.get('/target', (final Request req) {
        return Response.ok(body: Body.fromString('target reached'));
      });

      router.get('/source', (final Request req) {
        final newReq = req.copyWith(url: Uri.http('localhost', '/target'));
        return req.forwardTo(newReq);
      });

      final request = _request('/source');
      final result = await router.asHandler(request) as Response;

      expect(result.statusCode, 200);
      expect(await result.readAsString(), 'target reached');
    });

    test('Given a router with parameterized routes, '
        'when forwarding to a parameterized path, '
        'then the target handler receives correct path parameters', () async {
      final router = RelicRouter();
      Map<Symbol, String>? capturedParams;

      router.get('/users/:id', (final Request req) {
        capturedParams = req.rawPathParameters;
        return Response.ok();
      });

      router.get('/alias/:name', (final Request req) {
        final newReq = req.copyWith(url: Uri.http('localhost', '/users/42'));
        return req.forwardTo(newReq);
      });

      final request = _request('/alias/alice');
      final result = await router.asHandler(request) as Response;

      expect(result.statusCode, 200);
      expect(capturedParams, equals({#id: '42'}));
    });

    test('Given a request that was not routed through a RelicRouter, '
        'when forwardTo is called, '
        'then it throws a StateError', () {
      final request = _request('/test');
      final newRequest = _request('/other');

      expect(() => request.forwardTo(newRequest), throwsStateError);
    });

    test('Given a router where the forwarded path does not match any route, '
        'when forwardTo is called, '
        'then the router fallback is invoked', () async {
      final router = RelicRouter();

      router.get('/source', (final Request req) {
        final newReq = req.copyWith(url: Uri.http('localhost', '/nonexistent'));
        return req.forwardTo(newReq);
      });

      final request = _request('/source');
      final result = await router.asHandler(request) as Response;

      expect(result.statusCode, 404);
    });

    test('Given a router with middleware applied via use, '
        'when forwarding a request, '
        'then the middleware is applied to the forwarded request', () async {
      final router = RelicRouter();

      router.get('/target', (final Request req) {
        return Response.ok();
      });

      router.get('/source', (final Request req) {
        final newReq = req.copyWith(url: Uri.http('localhost', '/target'));
        return req.forwardTo(newReq);
      });

      router.use('/', (final handler) {
        return (final req) async {
          final result = await handler(req) as Response;
          return result.copyWith(
            headers: Headers.build((final h) => h['X-Forwarded'] = ['true']),
          );
        };
      });

      final request = _request('/source');
      final result = await router.asHandler(request) as Response;

      expect(result.statusCode, 200);
      expect(result.headers['X-Forwarded'], ['true']);
    });
  });
}
