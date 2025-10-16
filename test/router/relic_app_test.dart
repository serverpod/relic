import 'dart:async';

import 'package:mockito/mockito.dart';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';
import 'package:relic/src/adapter/context.dart';
import 'package:test/test.dart';

void main() {
  group('RelicApp', () {
    test(
        'Given RelicApp, '
        'when it is instantiated, '
        'then it is a Router<Handler>', () {
      final app = RelicApp();
      expect(app, isA<Router<Handler>>());
    });

    test(
        'Given a RelicApp, '
        'when using it as a callable handler, '
        'then it can be invoked directly', () async {
      final app = RelicApp()
        ..get(
            '/test',
            (final ctx) =>
                ctx.respond(Response.ok(body: Body.fromString('success'))));

      final request = Request(Method.get, Uri.parse('http://localhost/test'));
      final ctx = request.toContext(Object());
      final result = await app(ctx) as ResponseContext;

      expect(result.response.statusCode, 200);
      expect(await result.response.readAsString(), 'success');
    });

    test(
        'Given a RelicApp, '
        'when calling run with adapter factory, '
        'then it creates a RelicServer and mounts the handler', () async {
      final app = RelicApp()
        ..get('/', (final ctx) => ctx.respond(Response.ok()));

      final server = await app.run(() => _FakeAdapter());

      expect(server, isA<RelicServer>());
      // Server has been created and handler mounted
      await server.close();
    });

    test(
        'Given a RelicApp, '
        'when calling serve, '
        'then it creates a RelicServer and mounts the handler', () async {
      final app = RelicApp()
        ..get('/', (final ctx) => ctx.respond(Response.ok()));

      final server = await app.serve();

      expect(server, isA<RelicServer>());
      // Server has been created and handler mounted
      await server.close();
    });
  });
}

// Minimal fake adapter for testing
class _FakeAdapter extends Fake implements Adapter {
  @override
  Stream<AdapterRequest> get requests => const Stream.empty();

  @override
  Future<void> close() async {}
}
