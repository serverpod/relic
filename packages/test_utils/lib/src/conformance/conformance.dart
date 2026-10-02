import 'dart:convert';
import 'dart:io';

import 'package:relic_core/relic_core.dart';

/// Returns a fresh adapter factory.
///
/// The suite calls it once per server it starts. [shared] is true when
/// several isolates will each call the returned factory to serve one port.
typedef AdapterFactoryBuilder = Factory<Adapter> Function({bool shared});

/// The adapter under test and the servers the suite starts on it.
final class AdapterConformance {
  final String name;
  final AdapterFactoryBuilder bind;
  final AdapterCapabilities capabilities;

  /// Whether the transport reports a peer that went away before anything
  /// was written, and one that goes away while a response body streams.
  ///
  /// dart:io reports neither.
  final bool seesPeerGone;

  /// Whether `respond` fails when the connection is lost or the exchange
  /// is aborted while the body streams.
  ///
  /// dart:io swallows both and completes.
  final bool failsRespondMidStream;

  /// Whether bytes that arrived in the same packet as the request body
  /// reach a hijacked channel.
  ///
  /// dart:io's parser has consumed them by then.
  final bool keepsPipelinedBytes;

  AdapterConformance(
    this.name, {
    required this.bind,
    required this.capabilities,
    this.seesPeerGone = true,
    this.failsRespondMidStream = true,
    this.keepsPipelinedBytes = true,
  });

  /// Why the tests of a peer that went away are skipped, or null.
  String? get skipPeerGone =>
      seesPeerGone ? null : '$name cannot see the peer go away';

  /// Why the tests of respond failing mid-stream are skipped, or null.
  String? get skipRespondFailure => failsRespondMidStream
      ? null
      : '$name completes respond when the connection is lost mid-stream';

  /// Why the test of pipelined bytes on a hijacked channel is skipped, or
  /// null.
  String? get skipPipelined => keepsPipelinedBytes
      ? null
      : '$name drops the bytes that arrived with the request body';

  /// Whether WebSocket upgrades can work at all.
  ///
  /// The adapter either upgrades itself or exposes a raw channel the core
  /// can frame over.
  bool get supportsWebSocket => capabilities.webSocket || capabilities.hijack;

  /// Why WebSocket tests are skipped, or null when they run.
  String? get skipWebSocket =>
      supportsWebSocket ? null : '$name has no WebSocket support';

  /// Why hijack tests are skipped, or null when they run.
  String? get skipHijack =>
      capabilities.hijack ? null : '$name has no hijack support';

  /// A bound adapter with nothing started, for a test that drives the
  /// exchanges itself.
  Future<Adapter> bindAdapter() async => await bind()();

  /// A server on port 0 that has not started yet.
  RelicServer create({int noOfIsolates = 1}) =>
      RelicServer(bind(shared: noOfIsolates > 1), noOfIsolates: noOfIsolates);

  /// A started server serving [handler].
  Future<RelicServer> serve(Handler handler, {int noOfIsolates = 1}) async {
    final server = create(noOfIsolates: noOfIsolates);
    await server.mountAndStart(handler);
    return server;
  }
}

extension ConformanceServerUrl on RelicServer {
  /// The URL a local client reaches this server on.
  ///
  /// A server cannot know what URL it is addressed by before a request
  /// arrives, but for a loopback test the port is enough.
  Uri get url => Uri.http('localhost:$port');
}

/// Writes [request] on a fresh connection to [port] and returns everything
/// the server answers until it closes the connection.
///
/// The request has to make the server close, with `Connection: close` or
/// by being refused, or the read runs into [timeout].
Future<String> rawExchange(
  int port,
  String request, {
  Duration timeout = const Duration(seconds: 5),
  InternetAddress? address,
}) async {
  final socket = await Socket.connect(
    address ?? InternetAddress.loopbackIPv4,
    port,
  );
  socket.write(request);
  await socket.flush();
  final reply = await utf8.decodeStream(socket).timeout(timeout);
  socket.destroy();
  return reply;
}

/// [reply] split after the blank line that ends its first head.
///
/// The body is everything after that line, so on a pipelined reply it
/// holds the following responses too.
({String head, String body}) splitHead(String reply) {
  final at = reply.indexOf('\r\n\r\n') + 4;
  return (head: reply.substring(0, at), body: reply.substring(at));
}
