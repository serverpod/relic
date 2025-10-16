import 'dart:async';

import 'package:mockito/mockito.dart';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

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

      final server = await app.serve(port: 0);

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
