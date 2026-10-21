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
    final ShelfHandlerBuilder builder, {
    required final int port,
    final int isolates = 1,
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

  Future<void> close({final bool force = false}) async {
    for (final isolate in _isolates) {
      isolate.kill(priority: Isolate.immediate);
    }
    await _first.close(force: force);
  }
}

Future<HttpServer> _bind(
  final ShelfHandlerBuilder builder,
  final int port, {
  required final bool shared,
}) => shelf_io.serve(
  builder(),
  InternetAddress.loopbackIPv4,
  port,
  shared: shared,
);

Future<void> _serveInIsolate(
  final (ShelfHandlerBuilder, int, SendPort) message,
) async {
  final (builder, port, ready) = message;
  await _bind(builder, port, shared: true);
  ready.send(null);
}

/// The workloads of bin/http_load.dart.
Handler shelfLoad() {
  final random = Random(1);
  return (Router()
        ..get('/plaintext', (final Request req) => Response.ok('Hello, World!'))
        ..get(
          '/json',
          (final Request req) => Response.ok(
            jsonEncode({'message': 'Hello, World!'}),
            headers: {'content-type': 'application/json'},
          ),
        )
        ..get('/headers', (final Request req) {
          // What a page handler reads: the agent, the languages and a
          // cookie. shelf hands out strings, so this splits both.
          final agent = req.headers['user-agent'] ?? '';
          final languages =
              req.headers['accept-language']?.split(',').length ?? 0;
          final session = _cookie(req.headers['cookie'], 'session');
          return Response.ok(
            '${agent.length} $languages ${session?.length ?? 0}',
          );
        })
        ..get('/browser', (final Request req) {
          // A page handler on a real browser head: the host, a cookie and
          // the validator, answered with etag, cache-control and 1 KB of
          // JSON, or 304 when the validator matches.
          final host = req.headers['host'];
          final session = _cookie(req.headers['cookie'], 'session');
          if (req.headers['if-none-match'] == _etag) {
            return Response.notModified(headers: {'etag': _etag});
          }
          return Response.ok(
            '{"host":${jsonEncode(host)},"session":${jsonEncode(session)},'
            '"items":$_items}',
            headers: {
              'content-type': 'application/json; charset=utf-8',
              'etag': _etag,
              'cache-control': 'private, max-age=60',
            },
          );
        })
        ..get('/alloc', (final Request req) {
          // Garbage per request: a few thousand short-lived objects and a
          // 64 KiB string built from them.
          final parts = List.generate(4000, (final i) => 'item-$i-${i * 7}');
          final text = parts.join(',');
          return Response.ok(text.substring(0, 1024));
        })
        ..get('/mixed', (final Request req) async {
          // One request in a hundred waits on something slow.
          if (random.nextInt(100) == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
          return Response.ok('Hello, World!');
        }))
      .call;
}

const _etag = '"relic-browser-1"';

final _items = jsonEncode([
  for (var i = 0; i < 20; i++)
    {
      'id': i,
      'name': 'item $i',
      'tags': ['new', 'sale'],
      'price': 100 + i,
    },
]);

String? _cookie(final String? header, final String name) {
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
Handler shelfWebSocketEcho() => webSocketHandler((final channel, _) {
  channel.stream.listen(channel.sink.add);
});
