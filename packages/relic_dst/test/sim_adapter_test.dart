import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:relic_core/adapter.dart';
import 'package:relic_core/relic_core.dart';
import 'package:relic_dst/relic_dst.dart';
import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';

/// A server on a simulated network, with the contract watched.
final class _Served {
  final RelicServer server;
  final SimNetwork network;
  final SimAdapter adapter;
  final ContractAdapter contract;

  _Served(this.server, this.network, this.adapter, this.contract);

  SimHttpClient client() => SimHttpClient(network, adapter.port);

  /// Closes the server and checks what a clean end leaves: no contract
  /// violation and, once the last bytes have landed, nothing pending in
  /// the simulation.
  Future<void> shutdown({bool force = false}) async {
    await server.close(force: force);
    await network.sim.sleep(const Duration(seconds: 1));
    expect(contract.violations, isEmpty);
    expectQuiescent(network.sim);
  }
}

Future<_Served> _serve(
  Simulation sim,
  Handler handler, {
  NetworkOptions network = const NetworkOptions(),
  Duration idleTimeout = const Duration(seconds: 60),
  Duration headerTimeout = const Duration(seconds: 10),
  Duration bodyTimeout = const Duration(seconds: 30),
  Duration drainTimeout = const Duration(seconds: 5),
  int maxInlineBody = 1 << 20,
  int maxHeadSize = 16 << 10,
}) async {
  final net = SimNetwork(sim, options: network);
  final adapter = SimAdapter.bind(
    net,
    idleTimeout: idleTimeout,
    headerTimeout: headerTimeout,
    bodyTimeout: bodyTimeout,
    drainTimeout: drainTimeout,
    maxInlineBody: maxInlineBody,
    maxHeadSize: maxHeadSize,
  );
  final contract = ContractAdapter(adapter, sim);
  final server = RelicServer(() => contract);
  await server.mountAndStart(handler);
  return _Served(server, net, adapter, contract);
}

Response _hello(Request request) =>
    Response.ok(body: Body.fromString('Hello from ${request.url.path}'));

Handler _echoLength() => (request) async {
  final bytes = await request.body.readAll();
  return Response.ok(
    body: Body.fromString('${bytes.length} ${request.body.contentLength}'),
  );
};

Uint8List _bytes(int n) =>
    Uint8List.fromList(List.generate(n, (i) => (i * 7) & 0xff));

void main() {
  simTest('Given a server, '
      'when a client sends a GET, '
      'then the response has the body, its length and a Date from the '
      'simulated clock.', (sim) async {
    final served = await _serve(sim, _hello);

    final response = await served.client().get('/path');

    expect(response.statusCode, 200);
    expect(response.body, 'Hello from /path');
    expect(response.header('content-length'), '16');
    expect(response.header('date'), 'Thu, 01 Jan 2026 00:00:00 GMT');
    await served.shutdown();
  });

  simTest('Given a server, '
      'when a client sends two requests on one connection, '
      'then both are answered and the connection counts as idle in between.', (
    sim,
  ) async {
    final served = await _serve(sim, _hello);
    final client = served.client();

    final first = await client.get('/one');
    final between = await served.server.connectionsInfo();
    final second = await client.get('/two');

    expect(first.body, 'Hello from /one');
    expect(second.body, 'Hello from /two');
    expect(between.idle, 1);
    expect(between.active, 0);
    await served.shutdown();
  });

  simTest('Given a server, '
      'when a client pipelines three requests, '
      'then the responses come back in order.', (sim) async {
    final served = await _serve(sim, _hello);
    final client = served.client();

    for (final path in ['/a', '/b', '/c']) {
      await client.write(Method.get, path);
    }
    final bodies = [for (var i = 0; i < 3; i++) (await client.read()).body];

    expect(bodies, ['Hello from /a', 'Hello from /b', 'Hello from /c']);
    await served.shutdown();
  });

  simTest('Given a server, '
      'when a client posts a 100 KB chunked body, '
      'then the handler reads it all with no declared length.', (sim) async {
    final served = await _serve(sim, _echoLength());

    final response = await served.client().post(
      '/upload',
      _bytes(100 * 1024),
      chunked: true,
    );

    expect(response.body, '102400 null');
    await served.shutdown();
  });

  simTest('Given a server with a 1000 byte inline body limit, '
      'when a client posts 5000 bytes, '
      'then the handler reads the whole streamed body with its length.', (
    sim,
  ) async {
    final served = await _serve(sim, _echoLength(), maxInlineBody: 1000);

    final response = await served.client().post('/upload', _bytes(5000));

    expect(response.body, '5000 5000');
    await served.shutdown();
  });

  simTest('Given a server, '
      'when a client sends a HEAD, '
      'then the response has the length and no body.', (sim) async {
    final served = await _serve(sim, _hello);

    final response = await served.client().send(Method.head, '/');

    expect(response.statusCode, 200);
    expect(response.header('content-length'), '12');
    expect(response.bodyBytes, isEmpty);
    await served.shutdown();
  });

  simTest('Given a handler that answers with Connection: close, '
      'when a client sends a request, '
      'then the response arrives and the server closes the connection.', (
    sim,
  ) async {
    final served = await _serve(
      sim,
      (_) => Response.ok(
        headers: Headers.build(
          (h) => h.connection = const ConnectionHeader.directives([
            ConnectionHeaderType.close,
          ]),
        ),
        body: Body.fromString('bye'),
      ),
    );
    final client = served.client();

    final response = await client.get('/');
    final more = await client.reader.more();

    expect(response.body, 'bye');
    expect(response.head.closes, isTrue);
    expect(more, isFalse, reason: 'the server sent its FIN');
    await served.shutdown();
  });

  simTest('Given a handler that answers with a Connection value without close, '
      'when a client asks to close the connection, '
      'then the response says close beside that value and the server closes '
      'the connection.', (sim) async {
    final served = await _serve(
      sim,
      (_) => Response.ok(
        headers: Headers.build((h) => h['connection'] = ['x-trace']),
        body: Body.fromString('bye'),
      ),
    );
    final client = served.client();

    final response = await client.get('/', close: true);
    final more = await client.reader.more();

    expect(response.body, 'bye');
    expect(response.head.closes, isTrue);
    expect(response.head.header('connection'), contains('x-trace'));
    expect(more, isFalse, reason: 'the server sent its FIN');
    await served.shutdown();
  });

  simTest('Given a server, '
      'when a client sends an HTTP/1.0 request without a Host, '
      'then it is answered and the connection closes after.', (sim) async {
    final served = await _serve(sim, _hello);
    final client = served.client();

    final response = await client.send(
      Method.get,
      '/old',
      protocol: HttpProtocol.http10,
    );
    final more = await client.reader.more();

    expect(response.body, 'Hello from /old');
    expect(more, isFalse);
    await served.shutdown();
  });

  simTest('Given a server, '
      'when an HTTP/1.0 client asks to keep the connection alive and to close '
      'it, '
      'then the connection closes after the response.', (sim) async {
    final served = await _serve(sim, _hello);
    final client = served.client();

    await client.writeText(
      'GET /first HTTP/1.0\r\nConnection: keep-alive, close\r\n\r\n'
      'GET /second HTTP/1.0\r\n\r\n',
    );
    final response = await client.read();
    final more = await client.reader.more();

    expect(response.body, 'Hello from /first');
    expect(more, isFalse, reason: 'the server sent its FIN');
    await served.shutdown();
  });

  simTest('Given a server, '
      'when an HTTP/1.0 client asks to keep the connection alive and sends a '
      'chunked body, '
      'then the connection closes after the response.', (sim) async {
    final served = await _serve(sim, (request) async {
      await request.readAsString();
      return _hello(request);
    });
    final client = served.client();

    await client.writeText(
      'POST /first HTTP/1.0\r\nConnection: keep-alive\r\n'
      'Transfer-Encoding: chunked\r\n\r\n2\r\nhi\r\n0\r\n\r\n'
      'GET /second HTTP/1.0\r\n\r\n',
    );
    final response = await client.read(method: Method.post);
    final more = await client.reader.more();

    expect(response.body, 'Hello from /first');
    expect(more, isFalse, reason: 'the server sent its FIN');
    await served.shutdown();
  });

  simTest('Given a server, '
      'when a client sends a head with bare LF line endings, '
      'then it gets 400 and the handler never runs.', (sim) async {
    var handled = 0;
    final served = await _serve(sim, (request) {
      handled++;
      return _hello(request);
    });
    final client = served.client();

    await client.writeText('GET / HTTP/1.1\nhost: x\n\n');
    final response = await client.read();

    expect(response.statusCode, 400);
    expect(handled, 0);
    await served.shutdown();
  });

  simTest('Given a server with a 1 KB head limit, '
      'when a client sends a 2 KB header, '
      'then it gets 431.', (sim) async {
    final served = await _serve(sim, _hello, maxHeadSize: 1024);
    final client = served.client();

    final response = await client.get('/', headers: {'x-big': 'v' * 2048});

    expect(response.statusCode, 431);
    await served.shutdown();
  });

  simTest('Given a server, '
      'when a client writes two requests before its connection opens, '
      'then both go down one connection and the responses come in order.', (
    sim,
  ) async {
    final served = await _serve(sim, _hello);
    final client = served.client();

    final first = client.write(Method.get, '/a');
    final second = client.write(Method.get, '/b');
    await Future.wait([first, second]);
    final a = await client.read();
    final b = await client.read();

    expect(a.body, 'Hello from /a');
    expect(b.body, 'Hello from /b');
    expect((await served.server.connectionsInfo()).idle, 1);
    await served.shutdown();
  });

  simTest('Given a handler that sleeps a second, '
      'when a client sends a GET, '
      'then the contract records the exchange starting when the handler ran '
      'and ending a second later.', (sim) async {
    var handled = Duration.zero;
    final served = await _serve(sim, (_) async {
      handled = sim.elapsed;
      await sim.sleep(const Duration(seconds: 1));
      return Response.ok();
    });

    await served.client().get('/');
    final exchange = served.contract.exchanges.single;

    expect(exchange.startedAt, handled);
    expect(exchange.endedAt - exchange.startedAt, const Duration(seconds: 1));
    await served.shutdown();
  });

  simTest('Given a server, '
      'when a client sends a Content-Length of twenty digits, '
      'then it gets 400.', (sim) async {
    final served = await _serve(sim, _hello);
    final client = served.client();

    await client.writeText(
      'POST / HTTP/1.1\r\nhost: a\r\n'
      'content-length: 99999999999999999999\r\n\r\n',
    );
    final response = await client.read(method: Method.post);

    expect(response.statusCode, 400);
    await served.shutdown();
  });

  simTest('Given a server with a 10 second header timeout on a quiet network, '
      'when a client sends half a head and waits, '
      'then it gets 408 exactly 10 seconds after the first byte.', (sim) async {
    final served = await _serve(
      sim,
      _hello,
      network: NetworkOptions.quiet,
      headerTimeout: const Duration(seconds: 10),
    );
    final client = served.client();

    await client.writeText('GET / HTTP/1.1\r\nhost: ');
    final sent = sim.elapsed;
    final response = await client.read();

    expect(response.statusCode, 408);
    expect(sim.elapsed - sent, const Duration(seconds: 10));
    await served.shutdown();
  });

  simTest('Given a server with a 30 second body timeout on a quiet network, '
      'when a client sends a chunked head and nothing more, '
      'then the handler reading the body fails 30 seconds after the head.', (
    sim,
  ) async {
    Object? failure;
    final served = await _serve(
      sim,
      (request) async {
        try {
          await request.body.readAll();
        } on Object catch (e) {
          failure = e;
        }
        return Response.ok();
      },
      network: NetworkOptions.quiet,
      bodyTimeout: const Duration(seconds: 30),
    );
    final client = served.client();

    await client.write(Method.post, '/', chunked: true);
    final sent = sim.elapsed;
    final response = await client.read(method: Method.post);

    expect(response.statusCode, 200);
    expect(failure, isA<TimeoutException>());
    expect(sim.elapsed - sent, const Duration(seconds: 30));
    await served.shutdown();
  });

  simTest('Given a server with a 60 second idle timeout on a quiet network, '
      'when a client connects and sends nothing, '
      'then the server closes the connection at 60 seconds.', (sim) async {
    final served = await _serve(
      sim,
      _hello,
      network: NetworkOptions.quiet,
      idleTimeout: const Duration(seconds: 60),
    );
    final client = served.client();

    await client.socket;
    final connected = sim.elapsed;
    final more = await client.reader.more();

    expect(more, isFalse);
    expect(sim.elapsed - connected, const Duration(seconds: 60));
    await served.shutdown();
  });

  simTest('Given a handler waiting on the request, '
      'when the client resets the connection, '
      'then request.cancelled completes and the exchange ended by the peer.', (
    sim,
  ) async {
    final cancelled = Completer<void>();
    final served = await _serve(sim, (request) async {
      await request.cancelled;
      cancelled.complete();
      return Response.ok();
    });
    final client = served.client();

    await client.write(Method.get, '/');
    await sim.sleep(const Duration(milliseconds: 100));
    client.destroy();
    await cancelled.future;

    final exchange = served.contract.exchanges.single;
    expect(await exchange.done, ExchangeEnd.cancelledByPeer);
    await served.shutdown();
  });

  simTest('Given a server with a request in flight, '
      'when the server closes gracefully, '
      'then the request completes with 200 before the close does.', (
    sim,
  ) async {
    final release = Completer<void>();
    final served = await _serve(sim, (_) async {
      await release.future;
      return Response.ok(body: Body.fromString('done'));
    });
    final client = served.client();

    await client.write(Method.get, '/');
    await sim.sleep(const Duration(milliseconds: 100));
    var closed = false;
    final closing = served.server.close().then((_) => closed = true);
    await sim.sleep(const Duration(seconds: 1));
    final closedBeforeRelease = closed;
    release.complete();
    final response = await client.read();
    await closing;

    expect(closedBeforeRelease, isFalse);
    expect(response.body, 'done');
    await served.shutdown();
  });

  simTest('Given a handler that never answers, '
      'when the server closes gracefully with a 5 second drain, '
      'then the close completes at 5 seconds and the client sees a reset.', (
    sim,
  ) async {
    final served = await _serve(
      sim,
      (_) => Completer<Response>().future,
      network: NetworkOptions.quiet,
      drainTimeout: const Duration(seconds: 5),
    );
    final client = served.client();

    await client.write(Method.get, '/');
    await sim.sleep(const Duration(milliseconds: 10));
    final started = sim.elapsed;
    await served.server.close();

    expect(sim.elapsed - started, const Duration(seconds: 5));
    await expectLater(client.read(), throwsA(isA<SimConnectionReset>()));
    expect(served.contract.exchanges.single.end, ExchangeEnd.aborted);
    await served.shutdown();
  });

  simTest('Given a server with a request in flight, '
      'when the server closes by force, '
      'then the client sees a reset at once.', (sim) async {
    final served = await _serve(sim, (_) => Completer<Response>().future);
    final client = served.client();

    await client.write(Method.get, '/');
    await sim.sleep(const Duration(milliseconds: 100));
    final started = sim.elapsed;
    await served.server.close(force: true);

    expect(sim.elapsed, started);
    await expectLater(client.read(), throwsA(isA<SimConnectionReset>()));
    await served.shutdown(force: true);
  });

  simTest('Given a handler that hijacks and echoes, '
      'when the client writes bytes after its request, '
      'then it reads the same bytes back.', (sim) async {
    final served = await _serve(
      sim,
      (_) => Hijack((channel) {
        channel.stream.listen(channel.sink.add, onDone: channel.sink.close);
      }),
    );
    final client = served.client();

    await client.write(Method.get, '/raw');
    await client.writeRaw(_bytes(3000));
    await client.close();
    final echoed = await client.reader.readToEnd();

    expect(echoed, _bytes(3000));
    expect((await served.server.connectionsInfo()).active, 0);
    await served.shutdown();
  });

  simTest('Given a handler that hijacks without reading the body, '
      'when the client sends a chunked head and nothing more, '
      'then it gets 500 and the connection closes.', (sim) async {
    final served = await _serve(
      sim,
      (_) => Hijack((channel) => channel.sink.close()),
    );
    final client = served.client();

    await client.write(Method.post, '/raw', chunked: true);
    final response = await client.read(method: Method.post);
    final more = await client.reader.more();

    expect(response.statusCode, 500);
    expect(more, isFalse);
    await served.shutdown();
  });

  simTest('Given a hijacked connection flooded towards a peer that stopped '
      'reading, '
      'when the server closes gracefully with a 5 second drain, '
      'then the close completes within the drain and the connection is gone.', (
    sim,
  ) async {
    final flooded = Completer<void>();
    final served = await _serve(
      sim,
      (_) => Hijack((channel) {
        for (var i = 0; i < 64; i++) {
          channel.sink.add(Uint8List(1 << 20));
        }
        flooded.complete();
      }),
      drainTimeout: const Duration(seconds: 5),
    );
    final client = served.client();

    await client.write(Method.get, '/flood');
    await flooded.future;
    final started = sim.elapsed;
    await served.server.close();

    expect(
      sim.elapsed - started,
      lessThanOrEqualTo(const Duration(seconds: 5)),
    );
    expect((await served.server.connectionsInfo()).active, 0);
    await served.shutdown();
  });

  simTest('Given a WebSocket handler that answers tick with tock, '
      'when the client sends tick and then a close frame, '
      'then it gets tock, the echoed close and the end of the connection.', (
    sim,
  ) async {
    final served = await _serve(
      sim,
      (_) => WebSocketUpgrade((socket) {
        socket.events.listen((event) {
          if (event case TextDataReceived(text: 'tick')) {
            socket.sendText('tock');
          }
        });
      }),
    );
    final client = served.client();

    final ws = await client.upgrade('/ws');
    ws.sendText('tick');
    final tock = await ws.readFrame();
    ws.close(1000, 'bye');
    final close = await ws.readFrame();
    final end = await ws.readFrame();

    expect(tock?.opcode, WebSocketOpcode.text);
    expect(utf8.decode(tock!.payload), 'tock');
    expect(close?.opcode, WebSocketOpcode.close);
    expect((close!.payload[0] << 8) | close.payload[1], 1000);
    expect(end, isNull);
    await served.shutdown();
  });

  simTest(
    'Given a WebSocket with a 10 second ping interval on a quiet network, '
    'when the client answers no ping, '
    'then a ping arrives at 10 seconds and a 1001 close at 20.',
    (sim) async {
      final served = await _serve(
        sim,
        (_) => WebSocketUpgrade((socket) {
          socket.pingInterval = const Duration(seconds: 10);
        }),
        network: NetworkOptions.quiet,
      );

      final ws = await served.client().upgrade('/ws');
      final upgraded = sim.elapsed;
      final ping = await ws.readFrame();
      final pingAt = sim.elapsed - upgraded;
      final close = await ws.readFrame();
      final closeAt = sim.elapsed - upgraded;

      expect(ping?.opcode, WebSocketOpcode.ping);
      expect(pingAt, const Duration(seconds: 10));
      expect(close?.opcode, WebSocketOpcode.close);
      expect((close!.payload[0] << 8) | close.payload[1], 1001);
      expect(closeAt, const Duration(seconds: 20));
      await served.shutdown();
    },
  );

  simTest('Given an open WebSocket, '
      'when the server closes gracefully, '
      'then the client gets a 1001 going-away close and the close completes '
      'once it answers.', (sim) async {
    final served = await _serve(sim, (_) => WebSocketUpgrade((_) {}));
    final ws = await served.client().upgrade('/ws');

    var closed = false;
    final closing = served.server.close().then((_) => closed = true);
    final close = await ws.readFrame();
    final closedBeforeAnswer = closed;
    ws.close(1001);
    await closing;

    expect(close?.opcode, WebSocketOpcode.close);
    expect((close!.payload[0] << 8) | close.payload[1], 1001);
    expect(utf8.decode(close.payload.sublist(2)), 'Server shutting down');
    expect(closedBeforeAnswer, isFalse);
    await served.shutdown();
  });

  simTest('Given a WebSocket handler that listens to events without an error '
      'handler, '
      'when a client started in another zone resets the connection, '
      'then the error reaches the zone the server was started in, not the '
      "client's.", (sim) async {
    final serverErrors = <Object>[];
    final clientErrors = <Object>[];
    late _Served served;
    await runZonedGuarded(() async {
      served = await _serve(
        sim,
        (_) => WebSocketUpgrade((socket) {
          socket.events.listen((_) {});
        }),
      );
    }, (error, _) => serverErrors.add(error))!;

    await runZonedGuarded(() async {
      final ws = await served.client().upgrade('/ws');
      ws.sendText('hello');
      await sim.sleep(const Duration(milliseconds: 100));
      ws.destroy();
      await sim.sleep(const Duration(milliseconds: 100));
    }, (error, _) => clientErrors.add(error))!;

    expect(serverErrors, [
      isA<WebSocketException>().having(
        (e) => e.message,
        'message',
        'Connection reset by peer',
      ),
    ]);
    expect(clientErrors, isEmpty);
    await served.shutdown();
  });

  simTest('Given a handler that throws, '
      'when a client sends a request, '
      'then it gets 500 and the connection stays usable.', (sim) async {
    final served = await _serve(sim, (_) => throw StateError('oh no'));
    final client = served.client();

    final first = await client.get('/');
    final second = await client.get('/');

    expect(first.statusCode, 500);
    expect(second.statusCode, 500);
    await served.shutdown();
  });

  test('Given a scenario of 20 concurrent clients on a lossy network, '
      'when it runs twice with the same seed, '
      'then both runs leave the same trace.', () {
    List<String> run() {
      final sim = Simulation(seed: 11);
      sim.run(() async {
        final served = await _serve(sim, (request) async {
          await sim.sleep(Duration(milliseconds: sim.random.nextInt(50)));
          return _hello(request);
        }, network: const NetworkOptions(fragmentation: 0.8));
        await Future.wait([
          for (var i = 0; i < 20; i++)
            served.client().get('/$i').then((r) {
              expect(r.body, 'Hello from /$i');
            }),
        ]);
        await served.shutdown();
      });
      return [for (final entry in sim.trace) entry.toString()];
    }

    final [first, second] = [for (var i = 0; i < 2; i++) run()];

    expect(first, second);
    expect(first.length, greaterThan(100));
  });
}
