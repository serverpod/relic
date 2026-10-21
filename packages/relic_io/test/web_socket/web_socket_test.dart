// The adapter conformance suite covers the server side of WebSocket. What
// is left here exercises IORelicWebSocket as a client.
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:relic_core/relic_core.dart';
import 'package:relic_io/relic_io.dart';
import 'package:test/test.dart';
import 'package:test_utils/adapter_conformance.dart';
import 'package:web_socket/web_socket.dart';

import '../util/test_util.dart';

RelicServer? _server;
int get _serverPort => _server!.url.port;

Future<void> scheduleServer(Handler handler) async {
  await _server?.close(); // close previous, if any
  _server = await testServe(handler);
}

void main() {
  tearDown(() async {
    await _server?.close(); // close previous, if any
    _server = null;
  });

  test('Given a connected IORelicWebSocket, '
      'when the server closes it, '
      'then done completes', () async {
    await scheduleServer((req) => WebSocketUpgrade((ws) => ws.close()));

    final client = await IORelicWebSocket.connect(
      Uri.parse('ws://localhost:$_serverPort'),
    );

    await expectLater(
      client.done.timeout(const Duration(seconds: 2)),
      completes,
    );
    expect(client.isClosed, isTrue);
  });

  test('Given a web socket connection with a ping interval, '
      'when the server side disappear, '
      'then client socket closes', () async {
    const pingInterval = Duration(milliseconds: 15);

    // Setup wait points, signalled from isolate
    final port = Completer<int>();
    final ready = Completer<bool>();
    final killed = Completer<bool>();
    final completers = [port, ready, killed];
    final recv = ReceivePort();
    int idx = 0;
    recv.listen((e) {
      // Signal received! Update associated completer
      completers[idx++].complete(e);
    });

    final isolate =
        await Isolate.spawn((sendPort) async {
            final server = await testServe((req) {
              return WebSocketUpgrade((serverSocket) async {
                serverSocket.sendText('running');
                sendPort.send(true); // signal ready
              });
            });
            sendPort.send(server.url.port); // signal port
          }, recv.sendPort)
          ..addOnExitListener(recv.sendPort, response: true); // signal killed

    final clientSocket = await IORelicWebSocket.connect(
      Uri.parse('ws://localhost:${await port.future}'),
    );
    clientSocket.pingInterval = pingInterval;

    final check = expectLater(
      clientSocket.events,
      emitsInOrder([
        TextDataReceived('running'),
        CloseReceived(1001),
        emitsDone,
      ]),
    );

    await ready.future;

    isolate.kill();
    await killed.future;

    await check;
  });

  test('Given a client web socket connection that has been closed, '
      'when trying to use tryClose, trySendText, or trySendBytes, '
      'then they return false', () async {
    await scheduleServer((req) {
      return WebSocketUpgrade(expectAsync1((serverSocket) async {}));
    });
    final clientSocket = await IORelicWebSocket.connect(
      Uri.parse('ws://localhost:$_serverPort'),
    );
    await clientSocket.close();
    expect(clientSocket.tryClose(), completion(isFalse));
    expect(clientSocket.trySendText('hello'), isFalse);
    expect(clientSocket.trySendBytes(utf8.encode('hello')), isFalse);
    expect(clientSocket.events, emitsDone);
    expect(clientSocket.protocol, '');
    expect(() => clientSocket.toString(), returnsNormally);
  });

  test('Given a web socket connection, '
      'when calling close, '
      'then arguments are validated', () async {
    await scheduleServer((req) {
      return WebSocketUpgrade(expectAsync1((serverSocket) async {}));
    });
    final clientSocket = await IORelicWebSocket.connect(
      Uri.parse('ws://localhost:$_serverPort'),
    );
    expect(clientSocket.close(1002), throwsArgumentError);
    expect(clientSocket.close(3000, '-' * 124), throwsArgumentError);
  });
}
