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
      router.inject(const _EchoHandlerObject());

      final request = Request(Method.post, Uri.parse('http://localhost/'),
          body: Body.fromString('Hello from the other side'));
      final ctx = request.toContext(Object());
      final result = await router.asHandler(ctx) as ResponseContext;

      expect(result.response.statusCode, 200);
      expect(await result.response.readAsString(), 'Hello from the other side');
    });

    test(
        'Given a HandlerObject with custom injectIn, '
        'when injected into router, '
        'then custom path and method are used', () async {
      final router = Router<Handler>();
      router.inject(const _EchoHandlerObject(mountAt: '/custom/path'));

      final request = Request(
          Method.post, Uri.parse('http://localhost/custom/path'),
          body: Body.fromString('custom handler'));
      final ctx = request.toContext(Object());
      final result = await router.asHandler(ctx) as ResponseContext;

      expect(result.response.statusCode, 200);
      expect(await result.response.readAsString(), 'custom handler');
    });
  });
}

// Test implementations - HandlerObject
class _EchoHandlerObject extends HandlerObject {
  final String mountAt;

  const _EchoHandlerObject({this.mountAt = '/'});

  @override
  void injectIn(final Router<Handler> router) => router.post(mountAt, call);

  @override
  FutureOr<HandledContext> call(final NewContext ctx) {
    final data = ctx.request.body.read();
    return ctx.respond(
      Response.ok(body: Body.fromDataStream(data)),
    );
  }
}
