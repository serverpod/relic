import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:mockito/mockito.dart';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

import 'package:test/test.dart';
import 'package:vm_service/vm_service_io.dart' as vmi;

void main() {
  group('RelicApp', () {
    test('Given RelicApp, '
        'when it is instantiated, '
        'then it is a Router<Handler>', () {
      final app = RelicApp();
      expect(app, isA<Router<Handler>>());
    });

    test('Given a RelicApp, '
        'when calling run with adapter factory, '
        'then it creates a RelicServer and mounts the handler', () async {
      final app =
          RelicApp()..any('/', (final ctx) => ctx.respond(Response.ok()));

      final server = await app.run(() => _FakeAdapter());

      expect(server, isA<RelicServer>());
      // Server has been created and handler mounted
      await app.close();
    });

    test('Given a RelicApp, '
        'when calling serve, '
        'then it creates a RelicServer and mounts the handler', () async {
      final app =
          RelicApp()..any('/', (final ctx) => ctx.respond(Response.ok()));

      final server = await app.serve(port: 0);

      expect(server, isA<RelicServer>());
      // Server has been created and handler mounted
      await app.close();
    });

    test('Given a RelicApp, '
        'when calling serve twice, '
        'then it fails the second time', () async {
      final app =
          RelicApp()..any('/', (final ctx) => ctx.respond(Response.ok()));

      await app.serve(port: 0);
      await expectLater(app.serve(port: 0), throwsStateError);

      await app.close();
    });

    test('Given a RelicApp, '
        'when calling serve, close, serve, '
        'then it succeeds', () async {
      final app =
          RelicApp()..any('/', (final ctx) => ctx.respond(Response.ok()));

      await app.serve(port: 0);
      await app.close();
      await expectLater(app.serve(port: 0), completes);

      await app.close();
    });

    test('Given a RelicApp, '
        'when hot-reloading isolate, '
        'then it is rebuild', () async {
      final wsUri = (await Service.getInfo()).serverWebSocketUri;
      if (wsUri == null) {
        markTestSkipped(
          'VM service not available! Use: dart run --enable-vm-service',
        );
        return;
      }
      if (Platform.script.path.endsWith('.dill')) {
        markTestSkipped(
          'Cannot reload! Use: dart test --enable-vm-service --compiler source',
        );
        return;
      }

      final vmService = await vmi.vmServiceConnectUri(wsUri.toString());
      final isolateId = Service.getIsolateId(Isolate.current)!;
      final packagesUri = (await Isolate.packageConfig)?.toString();
      Future<void> hotReload() async {
        await vmService.reloadSources(
          isolateId,
          force: true,
          packagesUri: packagesUri,
        );
      }

      int count = 0;
      final called = StreamController<int>();
      final app =
          RelicApp()
            ..inject(_Injectable(() => called.add(++count))); // 1 original

      await app.serve(noOfIsolates: 2);

      await hotReload(); // 2
      await hotReload(); // 3
      await app.close();
      await hotReload(); // won't emit
      await hotReload(); // won't emit

      await expectLater(called.stream, emitsInOrder([1, 2, 3]));

      await vmService.dispose();
    }, tags: {'hot-reload'});
  });
}

class _Injectable implements RouterInjectable {
  final void Function() _action;

  _Injectable(this._action);

  @override
  void injectIn(final RelicRouter owner) => _action();
}

// Minimal fake adapter for testing
class _FakeAdapter extends Fake implements Adapter {
  @override
  Stream<AdapterRequest> get requests => const Stream.empty();

  @override
  late int port = Random().nextInt(65536);

  @override
  Future<void> close() async {}
}
