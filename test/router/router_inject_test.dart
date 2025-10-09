import 'dart:async';

import 'package:relic/relic.dart';
import 'package:relic/src/adapter/context.dart';
import 'package:test/test.dart';

void main() {
  group('Router.inject with HandlerObject', () {
    test(
        'Given a HandlerObject, '
        'when injected into router, '
        'then it is registered with default injectIn behavior', () async {
      final router = Router<Handler>();
      router.inject(_TestHandlerObject());

      final request = Request(Method.get, Uri.parse('http://localhost/'));
      final ctx = request.toContext(Object());
      final result = await router.asHandler(ctx) as ResponseContext;

      expect(result.response.statusCode, 200);
      expect(await result.response.readAsString(), 'handler object response');
    });

    test(
        'Given a HandlerObject with custom injectIn, '
        'when injected into router, '
        'then custom path and method are used', () async {
      final router = Router<Handler>();
      router.inject(_CustomHandlerObject());

      final request =
          Request(Method.post, Uri.parse('http://localhost/custom/path'));
      final ctx = request.toContext(Object());
      final result = await router.asHandler(ctx) as ResponseContext;

      expect(result.response.statusCode, 200);
      expect(await result.response.readAsString(), 'custom handler');
    });
  });
}

// Test implementations - HandlerObject
class _TestHandlerObject extends HandlerObject {
  @override
  FutureOr<HandledContext> call(final NewContext ctx) {
    return ctx.respond(
      Response.ok(body: Body.fromString('handler object response')),
    );
  }
}

class _CustomHandlerObject extends HandlerObject {
  @override
  void injectIn(final Router<Handler> router) {
    router.post('/custom/path', call);
  }

  @override
  FutureOr<HandledContext> call(final NewContext ctx) {
    return ctx.respond(
      Response.ok(body: Body.fromString('custom handler')),
    );
  }
}
