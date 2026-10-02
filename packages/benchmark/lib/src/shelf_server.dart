import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

/// Builds the handler one isolate serves.
///
/// A top-level function, so the server can send it to the isolates that
/// run it.
typedef ShelfHandlerBuilder = Handler Function();

/// A shelf server on dart:io for the benchmarks to compare Relic against,
/// with the same routes as the Relic server of each tool.
///
/// Several isolates share the port the way Relic's dart:io adapter does,
/// with `shared: true` on every bind.
final class ShelfServer {
  final int port;
  final HttpServer _first;
  final List<Isolate> _isolates;

  ShelfServer._(this.port, this._first, this._isolates);

  static Future<ShelfServer> start(
    ShelfHandlerBuilder builder, {
    required int port,
    int isolates = 1,
  }) async {
    final first = await _bind(builder, port, shared: isolates > 1);
    final spawned = <Isolate>[];
    for (var i = 1; i < isolates; i++) {
      final ready = ReceivePort();
      spawned.add(
        await Isolate.spawn(_serveInIsolate, (
          builder,
          first.port,
          ready.sendPort,
        )),
      );
      await ready.first;
    }
    return ShelfServer._(first.port, first, spawned);
  }

  Future<void> close({bool force = false}) async {
    for (final isolate in _isolates) {
      isolate.kill(priority: Isolate.immediate);
    }
    await _first.close(force: force);
  }
}

Future<HttpServer> _bind(
  ShelfHandlerBuilder builder,
  int port, {
  required bool shared,
}) => shelf_io.serve(
  builder(),
  InternetAddress.loopbackIPv4,
  port,
  shared: shared,
);

Future<void> _serveInIsolate(
  (ShelfHandlerBuilder, int, SendPort) message,
) async {
  final (builder, port, ready) = message;
  await _bind(builder, port, shared: true);
  ready.send(null);
}

/// The workloads of bin/http_load.dart.
Handler shelfLoad() {
  final random = Random(1);
  return (Router()
        ..get('/plaintext', (Request req) => Response.ok('Hello, World!'))
        ..get(
          '/json',
          (Request req) => Response.ok(
            jsonEncode({'message': 'Hello, World!'}),
            headers: {'content-type': 'application/json'},
          ),
        )
        ..get('/headers', (Request req) {
          // What a page handler reads: the agent, the language and a
          // cookie. shelf hands out strings, so the cookie is split here.
          final agent = req.headers['user-agent'] ?? '';
          final language = req.headers['accept-language'] ?? '';
          final session = _cookie(req.headers['cookie'], 'session');
          return Response.ok(
            '${agent.length} ${language.length} ${session?.length ?? 0}',
          );
        })
        ..get('/alloc', (Request req) {
          // Garbage per request: a few thousand short-lived objects and a
          // 64 KiB string built from them.
          final parts = List.generate(4000, (i) => 'item-$i-${i * 7}');
          final text = parts.join(',');
          return Response.ok(text.substring(0, 1024));
        })
        ..get('/mixed', (Request req) async {
          // One request in a hundred waits on something slow.
          if (random.nextInt(100) == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
          return Response.ok('Hello, World!');
        }))
      .call;
}

String? _cookie(String? header, String name) {
  if (header == null) return null;
  for (final pair in header.split(';')) {
    final at = pair.indexOf('=');
    if (at > 0 && pair.substring(0, at).trim() == name) {
      return pair.substring(at + 1).trim();
    }
  }
  return null;
}

/// Echoes every WebSocket message, as bin/ws_echo.dart does.
Handler shelfWebSocketEcho() => webSocketHandler((channel, _) {
  channel.stream.listen(channel.sink.add);
});
