import 'package:relic/relic.dart';
import 'package:relic/src/adapter/context.dart';
import 'package:relic/src/method/request_method.dart' as relic_req_method;
import 'package:relic/src/middleware/routing_middleware.dart';
import 'package:test/test.dart';

// Simple fake implementations for testing
class FakeRequest implements Request {
  @override
  final Uri url;
  @override
  final relic_req_method.RequestMethod method;

  @override
  dynamic noSuchMethod(final Invocation invocation) {
    throw UnimplementedError(invocation.memberName.toString());
  }

  FakeRequest(final String path,
      {this.method = relic_req_method.RequestMethod.get})
      : url = Uri.parse('http://localhost$path');
}

class FakeResponse implements Response {
  @override
  final int statusCode;
  final Map<Symbol, String>? parameters;

  FakeResponse(this.statusCode, {this.parameters});

  @override
  dynamic noSuchMethod(final Invocation invocation) {
    throw UnimplementedError(invocation.memberName.toString());
  }
}

void main() {
  group('RoutingMiddleware', () {
    late Router<Handler> router;
    late RoutingMiddleware middleware;

    setUp(() {
      router = Router<Handler>();
      middleware = RoutingMiddleware(router);
    });

    group('Parameter Propagation', () {
      test(
          'Given a router with a parameterized route and RoutingMiddleware, '
          'When a request matches the parameterized route, '
          'Then the handler receives correct path parameters', () async {
        Map<Symbol, String>? capturedParams;
        Future<ResponseContext> testHandler(final RequestContext ctx) async {
          capturedParams = ctx.pathParameters;
          return (ctx as RespondableContext)
              .withResponse(FakeResponse(200, parameters: capturedParams));
        }

        router.add(Method.get, '/users/:id', testHandler);

        final initialCtx = FakeRequest('/users/123').toContext(Object());
        final resultingCtx =
            await middleware.meddle((final RequestContext ctx) async {
          return (ctx as RespondableContext).withResponse(FakeResponse(404));
        })(initialCtx);

        expect(capturedParams, isNotNull);
        expect(capturedParams, equals({#id: '123'}));
        expect(resultingCtx, isA<ResponseContext>());
        final response =
            (resultingCtx as ResponseContext).response as FakeResponse;
        expect(response.statusCode, equals(200));
        expect(response.parameters, equals({#id: '123'}));
      });

      test(
          'Given a router with a non-parameterized route and RoutingMiddleware, '
          'When a request matches the non-parameterized route, '
          'Then the handler receives empty path parameters', () async {
        Map<Symbol, String>? capturedParams;
        Future<ResponseContext> testHandler(final RequestContext ctx) async {
          capturedParams = ctx.pathParameters;
          return (ctx as RespondableContext)
              .withResponse(FakeResponse(200, parameters: capturedParams));
        }

        router.add(Method.get, '/users', testHandler);

        final initialCtx = FakeRequest('/users').toContext(Object());
        final resultingCtx =
            await middleware.meddle((final RequestContext ctx) async {
          return (ctx as RespondableContext).withResponse(FakeResponse(404));
        })(initialCtx);

        expect(capturedParams, isNotNull);
        expect(capturedParams, isEmpty);
        expect(resultingCtx, isA<ResponseContext>());
        final response =
            (resultingCtx as ResponseContext).response as FakeResponse;
        expect(response.statusCode, equals(200));
        expect(response.parameters, isEmpty);
      });

      test(
          'Given RoutingMiddleware and a request that does not match any route, '
          'When the middleware processes the request, '
          'Then the next handler is called and pathParameters access throws StateError',
          () async {
        bool nextCalled = false;
        Future<ResponseContext> nextHandler(final RequestContext ctx) async {
          nextCalled = true;
          expect(() => ctx.pathParameters, throwsStateError);
          return (ctx as RespondableContext).withResponse(FakeResponse(404));
        }

        final initialCtx = FakeRequest('/nonexistent').toContext(Object());
        final resultingCtx = await middleware.meddle(nextHandler)(initialCtx);

        expect(nextCalled, isTrue);
        expect(resultingCtx, isA<ResponseContext>());
        final response =
            (resultingCtx as ResponseContext).response as FakeResponse;
        expect(response.statusCode, equals(404));
      });
    });

    group('Multiple RoutingMiddleware in Pipeline', () {
      late Router<Handler> router1;
      late RoutingMiddleware middleware1;
      late Router<Handler> router2;
      late RoutingMiddleware middleware2;

      setUp(() {
        router1 = Router<Handler>();
        middleware1 = RoutingMiddleware(router1);
        router2 = Router<Handler>();
        middleware2 = RoutingMiddleware(router2);
      });

      test(
          'Given two RoutingMiddleware instances in a pipeline, '
          'When a request matches a route in the first router, '
          'Then the handler from the first router is executed with correct parameters',
          () async {
        Map<Symbol, String>? params1;
        bool handler1Called = false;
        bool handler2Called = false;

        router1.add(Method.get, '/router1/:item',
            (final RequestContext ctx) async {
          handler1Called = true;
          params1 = ctx.pathParameters;
          return (ctx as RespondableContext)
              .withResponse(FakeResponse(201, parameters: params1));
        });
        router2.add(Method.get, '/router2/:item',
            (final RequestContext ctx) async {
          handler2Called = true;
          return (ctx as RespondableContext).withResponse(FakeResponse(202));
        });

        final pipeline = middleware1.meddle(middleware2.meddle(
            (final RequestContext ctx) async =>
                (ctx as RespondableContext).withResponse(FakeResponse(404))));

        final initialCtx = FakeRequest('/router1/apple').toContext(Object());
        final resultingCtx = await pipeline(initialCtx);
        final response =
            (resultingCtx as ResponseContext).response as FakeResponse;

        expect(handler1Called, isTrue);
        expect(handler2Called, isFalse);
        expect(response.statusCode, equals(201));
        expect(params1, equals({#item: 'apple'}));
        expect(response.parameters, equals({#item: 'apple'}));
      });

      test(
          'Given two RoutingMiddleware instances in a pipeline, '
          'When a request matches a route in the second router (but not the first), '
          'Then the handler from the second router is executed with correct parameters',
          () async {
        Map<Symbol, String>? params2;
        bool handler1Called = false;
        bool handler2Called = false;

        router1.add(Method.get, '/router1/:item',
            (final RequestContext ctx) async {
          handler1Called = true;
          return (ctx as RespondableContext).withResponse(FakeResponse(201));
        });
        router2.add(Method.get, '/router2/:data',
            (final RequestContext ctx) async {
          handler2Called = true;
          params2 = ctx.pathParameters;
          return (ctx as RespondableContext)
              .withResponse(FakeResponse(202, parameters: params2));
        });

        final pipeline = middleware1.meddle(middleware2.meddle(
            (final RequestContext ctx) async =>
                (ctx as RespondableContext).withResponse(FakeResponse(404))));

        final initialCtx = FakeRequest('/router2/banana').toContext(Object());
        final resultingCtx = await pipeline(initialCtx);
        final response =
            (resultingCtx as ResponseContext).response as FakeResponse;

        expect(handler1Called, isFalse);
        expect(handler2Called, isTrue);
        expect(response.statusCode, equals(202));
        expect(params2, equals({#data: 'banana'}));
        expect(response.parameters, equals({#data: 'banana'}));
      });

      test(
          'Given two RoutingMiddleware instances in a pipeline, '
          'When a request does not match any route in either router, '
          'Then the final next handler is called', () async {
        bool handler1Called = false;
        bool handler2Called = false;
        bool fallbackCalled = false;

        router1.add(Method.get, '/router1/:item',
            (final RequestContext ctx) async {
          handler1Called = true;
          return (ctx as RespondableContext).withResponse(FakeResponse(201));
        });
        router2.add(Method.get, '/router2/:data',
            (final RequestContext ctx) async {
          handler2Called = true;
          return (ctx as RespondableContext).withResponse(FakeResponse(202));
        });

        final pipeline = middleware1
            .meddle(middleware2.meddle((final RequestContext ctx) async {
          fallbackCalled = true;
          return (ctx as RespondableContext).withResponse(FakeResponse(404));
        }));

        final initialCtx = FakeRequest('/neither/nor').toContext(Object());
        final resultingCtx = await pipeline(initialCtx);
        final response =
            (resultingCtx as ResponseContext).response as FakeResponse;

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

        final mainRouter = Router<Handler>();
        final nestedRouter = Router<Handler>();

        nestedRouter.add(Method.get, '/details/:detailId',
            (final RequestContext ctx) async {
          nestedHandlerCalled = true;
          capturedParams = ctx.pathParameters;
          return (ctx as RespondableContext)
              .withResponse(FakeResponse(200, parameters: capturedParams));
        });

        // Attach nestedRouter to mainRouter under /resource/:resourceId
        mainRouter.attach('/resource/:resourceId', nestedRouter);

        final mainMiddleware = RoutingMiddleware(mainRouter);
        final pipeline = mainMiddleware.meddle(
            (final RequestContext ctx) async =>
                (ctx as RespondableContext).withResponse(FakeResponse(404)));

        final initialCtx =
            FakeRequest('/resource/abc/details/xyz').toContext(Object());
        final resultingCtx = await pipeline(initialCtx);
        final response =
            (resultingCtx as ResponseContext).response as FakeResponse;

        expect(nestedHandlerCalled, isTrue);
        expect(response.statusCode, equals(200));
        expect(capturedParams, isNotNull);
        expect(capturedParams, equals({#resourceId: 'abc', #detailId: 'xyz'}));
        expect(response.parameters,
            equals({#resourceId: 'abc', #detailId: 'xyz'}));
      });

      test(
          'Given a main Router with a nested Router (that itself has parameters at its root) attached, '
          'When a request matches, '
          'Then parameters from both levels are correctly captured', () async {
        // This test addresses the user's note about potential errors in nested routing.
        // The key is that Router.lookup should correctly merge parameters.
        Map<Symbol, String>? capturedParams;
        bool deeplyNestedHandlerCalled = false;

        final mainRouter = Router<Handler>();
        final intermediateRouter =
            Router<Handler>(); // Will be attached to mainRouter
        final leafRouter =
            Router<Handler>(); // Will be attached to intermediateRouter

        // Define handler for the leaf router
        leafRouter.add(Method.get, '/action/:actionName',
            (final RequestContext ctx) async {
          deeplyNestedHandlerCalled = true;
          capturedParams = ctx.pathParameters;
          return (ctx as RespondableContext)
              .withResponse(FakeResponse(200, parameters: capturedParams));
        });

        // Attach leafRouter to intermediateRouter under a parameterized path
        intermediateRouter.attach('/:intermediateId', leafRouter);

        // Attach intermediateRouter to mainRouter under a parameterized path
        mainRouter.attach('/base/:baseId', intermediateRouter);

        final mainMiddleware = RoutingMiddleware(mainRouter);
        final pipeline = mainMiddleware.meddle(
            (final RequestContext ctx) async =>
                (ctx as RespondableContext).withResponse(FakeResponse(404)));

        final initialCtx = FakeRequest('/base/b123/i456/action/doSomething')
            .toContext(Object());
        final resultingCtx = await pipeline(initialCtx);
        final response =
            (resultingCtx as ResponseContext).response as FakeResponse;

        expect(deeplyNestedHandlerCalled, isTrue);
        expect(response.statusCode, equals(200));
        expect(capturedParams, isNotNull);
        expect(
            capturedParams,
            equals({
              #baseId: 'b123',
              #intermediateId: 'i456',
              #actionName: 'doSomething'
            }));
        expect(
            response.parameters,
            equals({
              #baseId: 'b123',
              #intermediateId: 'i456',
              #actionName: 'doSomething'
            }));
      });

      test(
          'Given a path with repeated parameters at different levels introduced by attach, '
          'When looked up via RoutingMiddleware, '
          'Then last extracted parameter wins (consistent with PathTrie behavior)',
          () async {
        Map<Symbol, String>? capturedParams;
        final mainRouter = Router<Handler>();
        final subRouter = Router<Handler>();

        subRouter.add(Method.get, '/:id/end', (final RequestContext ctx) async {
          // sub-router uses :id
          capturedParams = ctx.pathParameters;
          return (ctx as RespondableContext)
              .withResponse(FakeResponse(200, parameters: capturedParams));
        });

        mainRouter.attach('/:id/sub', subRouter); // main router uses :id

        final middleware = RoutingMiddleware(mainRouter);
        final pipeline = middleware.meddle((final RequestContext ctx) async =>
            (ctx as RespondableContext).withResponse(FakeResponse(404)));

        final initialCtx = FakeRequest('/123/sub/456/end').toContext(Object());
        final resultingCtx = await pipeline(initialCtx);
        final response =
            (resultingCtx as ResponseContext).response as FakeResponse;

        expect(response.statusCode, 200);
        expect(capturedParams, isNotNull);
        // PathTrie's behavior is that the parameter from the deeper segment wins.
        // Full path: /:id/sub/:id/end -> /123/sub/456/end
        // Parameters: {#id: '123', #id: '456'} -> {#id: '456'}
        expect(capturedParams, equals({#id: '456'}));
        expect(response.parameters, equals({#id: '456'}));
      });
    });

    group('routeWith utility', () {
      test(
          'Given a router, When routeWith is used to create middleware, Then it functions like RoutingMiddleware',
          () async {
        Map<Symbol, String>? capturedParams;
        Future<ResponseContext> testHandler(final RequestContext ctx) async {
          capturedParams = ctx.pathParameters;
          return (ctx as RespondableContext)
              .withResponse(FakeResponse(200, parameters: capturedParams));
        }

        router.add(Method.get, '/utils/:param', testHandler);

        final middlewareFunc = routeWith(router);
        final handlerChain = middlewareFunc((final RequestContext ctx) async {
          return (ctx as RespondableContext).withResponse(FakeResponse(404));
        });

        final initialCtx = FakeRequest('/utils/testValue').toContext(Object());
        final resultingCtx = await handlerChain(initialCtx);

        expect(capturedParams, isNotNull);
        expect(capturedParams, equals({#param: 'testValue'}));
        expect(resultingCtx, isA<ResponseContext>());
        final response =
            (resultingCtx as ResponseContext).response as FakeResponse;
        expect(response.statusCode, equals(200));
        expect(response.parameters, equals({#param: 'testValue'}));
      });
    });
  });
}
