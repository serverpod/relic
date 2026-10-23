import 'dart:async';
import 'dart:io';
import 'dart:isolate';

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

/// The certificate chain and key a TLS server here presents, the test
/// certificates of relic_native. A client skips verification, or trusts
/// `ca_cert.pem` beside them.
({String chain, String key}) get testCertificates {
  final library = Isolate.resolvePackageUriSync(
    Uri.parse('package:relic_native/relic_native.dart'),
  )!;
  final certs = library.resolve('../test/certs/');
  return (
    chain: certs.resolve('localhost_cert.pem').toFilePath(),
    key: certs.resolve('localhost_key.pem').toFilePath(),
  );
}

/// Whether [kind] can serve over TLS. Shelf cannot.
bool supportsTls(final String kind) => kind != 'shelf';

/// Starts [served] on [kind], `io`, `native` or `shelf`, at [port] on the
/// IPv4 loopback with [isolates] isolates, over TLS with
/// [testCertificates] when [tls] is set.
///
/// Port 0 picks a free port.
Future<Server> startServer(
  final String kind,
  final Served served, {
  required final int port,
  final int isolates = 1,
  final bool tls = false,
}) async {
  final address = InternetAddress.loopbackIPv4;
  if (tls && !supportsTls(kind)) {
    throw ArgumentError.value(kind, 'kind', 'No TLS on $kind');
  }
  final certs = tls ? testCertificates : null;
  switch (kind) {
    case 'shelf':
      final server = await ShelfServer.start(
        served.shelf,
        port: port,
        isolates: isolates,
      );
      return (port: server.port, close: () => server.close(force: true));
    case 'io':
      // A SecurityContext cannot cross isolates, so each makes its own.
      final server = await served.relic(
        () => IOAdapter.bind(
          address,
          port: port,
          shared: isolates > 1,
          context: certs == null
              ? null
              : (SecurityContext()
                  ..useCertificateChain(certs.chain)
                  ..usePrivateKey(certs.key)),
        ),
        isolates,
      );
      return (port: server.port, close: () => server.close(force: true));
    case 'native':
      // The group ties the isolates to one native server, as serveNative
      // does, so port 0 works with several of them.
      final group = 'benchmark/$pid/${_serveCount++}';
      final server = await served.relic(
        () => NativeAdapter.bind(
          address,
          port: port,
          group: group,
          tls: certs == null
              ? null
              : NativeTls.fromFiles(
                  certificateChain: certs.chain,
                  privateKey: certs.key,
                ),
        ),
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
