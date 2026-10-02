import 'dart:async';
import 'dart:io';

import 'package:relic/relic.dart';
import 'package:relic_native/relic_native.dart';

import 'shelf_server.dart';

/// A started server: where it listens and how to stop it.
typedef Server = ({int port, Future<void> Function() close});

/// What a bin serves: on `io` and `native` a Relic server from an adapter
/// factory and an isolate count, on `shelf` the same routes on shelf.
final class Served {
  final Future<RelicServer> Function(
    FutureOr<Adapter> Function() adapter,
    int isolates,
  )
  relic;
  final ShelfHandlerBuilder shelf;

  Served.app(final RelicApp app, this.shelf)
    : relic = ((final adapter, final isolates) =>
          app.run(adapter, noOfIsolates: isolates));

  Served.handler(final Handler handler, this.shelf)
    : relic = ((final adapter, final isolates) async {
        final server = RelicServer(adapter, noOfIsolates: isolates);
        await server.mountAndStart(handler);
        return server;
      });
}

var _serveCount = 0;

/// Starts [served] on [kind], `io`, `native` or `shelf`, at [port] on the
/// IPv4 loopback with [isolates] isolates.
///
/// Port 0 picks a free port.
Future<Server> startServer(
  final String kind,
  final Served served, {
  required final int port,
  final int isolates = 1,
}) async {
  final address = InternetAddress.loopbackIPv4;
  switch (kind) {
    case 'shelf':
      final server = await ShelfServer.start(
        served.shelf,
        port: port,
        isolates: isolates,
      );
      return (port: server.port, close: () => server.close(force: true));
    case 'io':
      final server = await served.relic(
        () => IOAdapter.bind(address, port: port, shared: isolates > 1),
        isolates,
      );
      return (port: server.port, close: () => server.close(force: true));
    case 'native':
      // The group ties the isolates to one native server, as serveNative
      // does, so port 0 works with several of them.
      final group = 'benchmark/$pid/${_serveCount++}';
      final server = await served.relic(
        () => NativeAdapter.bind(address, port: port, group: group),
        isolates,
      );
      return (port: server.port, close: () => server.close(force: true));
    default:
      throw ArgumentError.value(kind, 'kind', 'Not io, native or shelf');
  }
}

/// Prints `ready <pid>` for whoever started this process, waits for
/// SIGTERM and closes [server].
Future<void> serveUntilSigterm(final Server server) async {
  stdout.writeln('ready $pid');
  await ProcessSignal.sigterm.watch().first;
  await server.close();
}
