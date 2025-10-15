// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

class _RouterSetup implements RouterInjectable {
  @override
  void injectIn(final RelicRouter router) {
    print('inject!'); // look for this on hot-reload
    router
      ..use('/', squashErrors)
      ..use('/', logRequests())
      ..put('/echo', echo)
      ..group('foobar').inject(const Greet());
  }
}

Future<void> main() async {
  // will re-run _RouterSetup.injectIn on hot-reload
  final app = RelicApp()..inject(_RouterSetup());

  final server = await app.serve(shared: true);
  print('running!');

  // Wait for Ctrl-C before proceeding
  await ProcessSignal.sigint.watch().first;

  print('shutdown');
  await server.close();
}

ResponseContext echo(final NewContext ctx) {
  final rq = ctx.request;
  return ctx.respond(Response.ok(
      body: rq.body,
      headers: Headers.build((final mh) {
        mh.server = 'relic';
      })));
}

class Greet extends HandlerObject {
  @override
  void injectIn(final Router<Handler> router) =>
      router.get('/user/:name/age/:age', asHandler);

  @override
  FutureOr<HandledContext> call(final NewContext ctx) => greet(ctx);

  const Greet();
}

ResponseContext greet(final NewContext ctx) {
  final name = ctx.pathParameters[#name];
  final age = int.parse(ctx.pathParameters[#age]!);
  return ctx.respond(Response.ok(
      body:
          Body.fromString('Hello $name to think you are $age old already?!')));
}

Handler squashErrors(final Handler next) {
  return (final ctx) {
    try {
      return next(ctx);
    } catch (_) {
      return ctx
          .respond(Response.badRequest(body: Body.fromString('Dumbass!')));
    }
  };
}

class SquashErrors extends MiddlewareObject {
  @override
  void injectIn(final Router<Handler> router) => router.use('/', asMiddleware);

  @override
  Handler call(final Handler next) => squashErrors(next);
}
