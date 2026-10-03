import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:web_socket/web_socket.dart';

import 'http1.dart';
import 'sim_client.dart';
import 'sim_network.dart';
import 'simulation.dart';

/// The handler a [Workload] drives. Every route has an answer the client
/// can predict, so the workload checks what came back and not only that
/// something did.
///
/// - `/echo` answers `METHOD n` with n the body length it read.
/// - `/slow?ms=n` answers `slow` after n milliseconds.
/// - `/stream?n=k` streams k lines `chunk-i` with pauses, chunked.
/// - `/large?n=k` answers k bytes of [workloadPattern].
/// - `/close` answers with `Connection: close`.
/// - `/error` throws, for a 500.
/// - `/ws` echoes WebSocket text messages.
/// - `/hijack` echoes raw bytes until the peer closes.
/// - `/wait` answers once the request is cancelled, which never arrives.
/// - Anything else is 404.
Handler workloadHandler(final Simulation sim) => (final request) async {
  final query = request.url.queryParameters;
  switch (request.url.path) {
    case '/echo':
      final body = await request.body.readAll();
      return Response.ok(
        body: Body.fromString('${request.method.value} ${body.length}'),
      );
    case '/slow':
      await sim.sleep(Duration(milliseconds: int.parse(query['ms'] ?? '0')));
      return Response.ok(body: Body.fromString('slow'));
    case '/stream':
      final n = int.parse(query['n'] ?? '1');
      return Response.ok(
        body: Body.fromDataStream(() async* {
          for (var i = 0; i < n; i++) {
            await sim.sleep(Duration(milliseconds: sim.random.nextInt(20)));
            yield Uint8List.fromList(utf8.encode('chunk-$i\n'));
          }
        }(), mimeType: MimeType.plainText),
      );
    case '/large':
      return Response.ok(
        body: Body.fromData(workloadPattern(int.parse(query['n'] ?? '0'))),
      );
    case '/close':
      return Response.ok(
        headers: Headers.build(
          (final h) => h.connection = const ConnectionHeader.directives([
            ConnectionHeaderType.close,
          ]),
        ),
        body: Body.fromString('closing'),
      );
    case '/error':
      throw StateError('the workload asked for an error');
    case '/ws':
      return WebSocketUpgrade((final socket) {
        socket.events.listen((final event) {
          if (event case TextDataReceived(:final text)) socket.sendText(text);
        });
      });
    case '/hijack':
      return Hijack((final channel) {
        channel.stream.listen(
          channel.sink.add,
          onDone: channel.sink.close,
          onError: (final _) => channel.sink.close(),
        );
      });
    case '/wait':
      await request.cancelled;
      return Response.ok();
    default:
      return Response.notFound(body: Body.fromString('no such route'));
  }
};

/// [n] bytes a client can check: byte i is `(i * 7) & 0xff`.
Uint8List workloadPattern(final int n) =>
    Uint8List.fromList(List.generate(n, (final i) => (i * 7) & 0xff));

/// What one client session does to the server.
enum WorkloadAction {
  /// A GET or a small POST on `/echo`, checked.
  plain,

  /// Three requests written before any response is read, checked in order.
  pipelined,

  /// A chunked POST, checked for its length.
  chunkedUpload,

  /// A POST over the inline body limit, so it streams, checked.
  largeUpload,

  /// A request the handler sits on for up to two seconds, checked.
  slow,

  /// A chunked streamed response, checked line by line.
  stream,

  /// A large buffered response, checked byte by byte.
  large,

  /// A handler that throws, for a 500.
  error,

  /// A 404.
  notFound,

  /// A response that closes the connection, checked to close it.
  closeHeader,

  /// Random bytes where a request should be. Any refusal is fine.
  garbage,

  /// Half a head, then silence past the header timeout, for a 408.
  slowloris,

  /// A request the client resets before the answer arrives.
  abandon,

  /// A request followed by the client's FIN, answered anyway.
  halfClose,

  /// A WebSocket echo exchange with a clean close handshake.
  webSocket,

  /// A hijacked connection echoing bytes until the client closes.
  hijack,

  /// A large response the client never reads, then resets.
  stopReading,

  /// A declared body the client resets halfway through.
  resetMidBody,
}

/// A check the workload made that failed. Carries what the client saw.
final class WorkloadFailure implements Exception {
  final int session;
  final WorkloadAction action;
  final String detail;

  WorkloadFailure(this.session, this.action, this.detail);

  @override
  String toString() => 'session $session, $action: $detail';
}

/// Random client sessions against a server running [workloadHandler], on
/// a [SimNetwork]. Every choice comes from the simulation's random, so a
/// seed names one exact workload.
///
/// Actions with a predictable answer are checked, and a mismatch throws a
/// [WorkloadFailure]. Fault actions check only that the client was not
/// left hanging. The contract and the server's state after the run are
/// the test's to check.
final class Workload {
  final Simulation sim;
  final SimNetwork network;
  final int port;

  /// How many concurrent sessions run.
  final int sessions;

  /// The most actions one session takes.
  final int actionsPerSession;

  /// The actions a session picks from.
  final List<WorkloadAction> actions;

  /// The adapter's limits, so the workload can cross them on purpose.
  final Duration headerTimeout;
  final int maxInlineBody;

  /// Every action taken, in the order it was picked.
  final taken = <(int, WorkloadAction)>[];

  /// How many answers were checked against what the handler should say.
  var checked = 0;

  Workload(
    this.sim,
    this.network,
    this.port, {
    this.sessions = 16,
    this.actionsPerSession = 4,
    this.actions = WorkloadAction.values,
    this.headerTimeout = const Duration(seconds: 10),
    this.maxInlineBody = 1 << 20,
  });

  /// Runs every session to its end.
  Future<void> run() =>
      Future.wait([for (var i = 0; i < sessions; i++) _session(i)]);

  Future<void> _session(final int id) async {
    await sim.sleep(Duration(milliseconds: sim.random.nextInt(200)));
    final count = 1 + sim.random.nextInt(actionsPerSession);
    SimHttpClient? client;
    for (var i = 0; i < count; i++) {
      final action = actions[sim.random.nextInt(actions.length)];
      taken.add((id, action));
      sim.record('workload', 'session $id $action');
      client ??= SimHttpClient(network, port);
      final reusable = await _perform(id, action, client);
      if (!reusable) {
        client.destroy();
        client = null;
      }
      await sim.sleep(Duration(milliseconds: sim.random.nextInt(100)));
    }
    client?.destroy();
  }

  /// Runs [action] on [client]. False when the connection is no longer
  /// good for another request.
  Future<bool> _perform(
    final int id,
    final WorkloadAction action,
    final SimHttpClient client,
  ) async {
    void check(final bool ok, final String detail) {
      if (!ok) throw WorkloadFailure(id, action, detail);
      checked++;
    }

    switch (action) {
      case WorkloadAction.plain:
        if (sim.random.nextBool()) {
          final response = await client.get('/echo');
          check(response.body == 'GET 0', 'got ${response.body}');
        } else {
          final n = sim.random.nextInt(2000);
          final response = await client.post('/echo', workloadPattern(n));
          check(response.body == 'POST $n', 'got ${response.body}');
        }
        return true;
      case WorkloadAction.pipelined:
        for (var i = 0; i < 3; i++) {
          await client.write(Method.get, '/echo?i=$i');
        }
        for (var i = 0; i < 3; i++) {
          final response = await client.read();
          check(response.body == 'GET 0', 'response $i was ${response.body}');
        }
        return true;
      case WorkloadAction.chunkedUpload:
        final n = 1 + sim.random.nextInt(50000);
        final response = await client.post(
          '/echo',
          workloadPattern(n),
          chunked: true,
        );
        check(response.body == 'POST $n', 'got ${response.body}');
        return true;
      case WorkloadAction.largeUpload:
        final n = maxInlineBody + 1 + sim.random.nextInt(maxInlineBody);
        final response = await client.post('/echo', workloadPattern(n));
        check(response.body == 'POST $n', 'got ${response.body}');
        return true;
      case WorkloadAction.slow:
        final response = await client.get(
          '/slow?ms=${sim.random.nextInt(2000)}',
        );
        check(response.body == 'slow', 'got ${response.body}');
        return true;
      case WorkloadAction.stream:
        final n = 1 + sim.random.nextInt(20);
        final response = await client.get('/stream?n=$n');
        final expected = [for (var i = 0; i < n; i++) 'chunk-$i\n'].join();
        check(response.head.chunked, 'not chunked');
        check(response.body == expected, 'got ${response.body}');
        return true;
      case WorkloadAction.large:
        final n = sim.random.nextInt(1 << 20);
        final response = await client.get('/large?n=$n');
        check(
          _sameBytes(response.bodyBytes, workloadPattern(n)),
          'got ${response.bodyBytes.length} bytes for $n',
        );
        return true;
      case WorkloadAction.error:
        final response = await client.get('/error');
        check(response.statusCode == 500, 'got ${response.statusCode}');
        return true;
      case WorkloadAction.notFound:
        final response = await client.get('/missing');
        check(response.statusCode == 404, 'got ${response.statusCode}');
        return true;
      case WorkloadAction.closeHeader:
        final response = await client.get('/close');
        check(response.body == 'closing', 'got ${response.body}');
        check(!await client.reader.more(), 'the server kept the connection');
        return false;
      case WorkloadAction.garbage:
        final bytes = Uint8List.fromList([
          for (var i = 0; i < 1 + sim.random.nextInt(200); i++)
            sim.random.nextInt(256),
        ]);
        await client.writeRaw(bytes);
        try {
          final response = await client.read();
          check(
            const {400, 408, 431, 501, 505}.contains(response.statusCode),
            'got ${response.statusCode}',
          );
        } on HttpParseException {
          checked++; // closed, or an answer that is not HTTP to the garbage
        } on SimConnectionReset {
          checked++;
        }
        return false;
      case WorkloadAction.slowloris:
        await client.writeText('GET /echo HTTP/1.1\r\nhost: x\r\n');
        await sim.sleep(headerTimeout + const Duration(seconds: 1));
        final response = await client.read();
        check(response.statusCode == 408, 'got ${response.statusCode}');
        return false;
      case WorkloadAction.abandon:
        await client.write(Method.get, '/slow?ms=1000');
        await sim.sleep(Duration(milliseconds: sim.random.nextInt(500)));
        return false;
      case WorkloadAction.halfClose:
        await client.write(Method.get, '/echo');
        await client.close();
        final response = await client.read();
        check(response.body == 'GET 0', 'got ${response.body}');
        check(!await client.reader.more(), 'the server kept the connection');
        return false;
      case WorkloadAction.webSocket:
        final ws = await client.upgrade('/ws');
        final count = 1 + sim.random.nextInt(5);
        for (var i = 0; i < count; i++) {
          ws.sendText('message $i');
        }
        var echoed = 0;
        while (echoed < count) {
          final frame = await ws.readFrame();
          check(frame != null, 'the connection ended after $echoed echoes');
          if (frame!.opcode != WebSocketOpcode.text) continue;
          check(
            utf8.decode(frame.payload) == 'message $echoed',
            'echo $echoed was ${utf8.decode(frame.payload)}',
          );
          echoed++;
        }
        ws.close(1000, 'done');
        WebSocketFrame? close;
        while (close == null) {
          final frame = await ws.readFrame();
          check(frame != null, 'no close frame came back');
          if (frame!.opcode == WebSocketOpcode.close) close = frame;
        }
        check(await ws.readFrame() == null, 'the connection stayed open');
        return false;
      case WorkloadAction.hijack:
        final bytes = workloadPattern(sim.random.nextInt(10000));
        await client.write(Method.get, '/hijack');
        await client.writeRaw(bytes);
        await client.close();
        final echoed = await client.reader.readToEnd();
        check(_sameBytes(echoed, bytes), 'got ${echoed.length} bytes');
        return false;
      case WorkloadAction.stopReading:
        final socket = await network.connect(port);
        socket.sink.add(
          Uint8List.fromList(
            latin1.encode(
              'GET /large?n=${2 << 20} HTTP/1.1\r\nhost: x\r\n\r\n',
            ),
          ),
        );
        await sim.sleep(Duration(milliseconds: 100 + sim.random.nextInt(900)));
        socket.destroy();
        return false;
      case WorkloadAction.resetMidBody:
        await client.writeText(
          'POST /echo HTTP/1.1\r\nhost: x\r\ncontent-length: 100000\r\n\r\n',
        );
        await client.writeRaw(
          workloadPattern(1000 + sim.random.nextInt(50000)),
        );
        await sim.sleep(Duration(milliseconds: sim.random.nextInt(200)));
        return false;
    }
  }

  static bool _sameBytes(final Uint8List a, final Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
