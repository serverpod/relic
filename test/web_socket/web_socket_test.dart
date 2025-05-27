import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:relic/relic.dart';
import 'package:relic/src/adapter/duplex_stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../headers/headers_test_utils.dart';
import '../util/test_util.dart';

RelicServer? _server;
int get _serverPort => _server!.url.port;

Future<void> scheduleServer(
  final Handler handler, {
  final SecurityContext? securityContext,
}) async {
  assert(_server == null, 'Server already scheduled. Call tearDown first.');
  _server = await testServe(
    handler,
    context: securityContext,
  );
}

void main() {
  tearDown(() async {
    final server = _server;
    if (server != null) {
      try {
        // Attempt a graceful shutdown with a timeout.
        await server.close().timeout(const Duration(seconds: 5));
      } catch (e) {
        // If timeout or other error occurs, force close.
        // This is important to ensure tests don't hang or affect subsequent tests.
        await server.close();
      } finally {
        _server = null;
      }
    }
  });

  group('WebSocket Tests', () {
    test(
        'Given a WebSocket server, '
        'when a client connects and sends "ping", '
        'then the server responds with "pong" and the client receives it',
        () async {
      await scheduleServer((final ctx) {
        return ctx.connect(expectAsync1((final channel) async {
          // Expect a message from the client
          expect(
            channel.stream.first,
            completion(isA<TextPayload>()
                .having((final p) => p.data, 'data', equals('ping'))),
          );
          // Send a message back to the client
          channel.sink.add(const TextPayload('pong'));
          // Close the server-side of the connection after sending the message.
          // This also signals the client that no more messages are coming from the server.
          await channel.close();
        }));
      });

      final socket = await WebSocket.connect('ws://localhost:$_serverPort');

      // Send a message to the server
      socket.add('ping');

      // Expect a response from the server
      expect(socket, emitsInOrder(['pong', emitsDone]));
    });

    test(
        'Given a WebSocket server, '
        'when a client sends multiple messages, '
        'then the server receives all messages in order', () async {
      final serverReceivedMessages = <String>[];
      await scheduleServer((final ctx) {
        return ctx.connect(expectAsync1((final channel) {
          channel.stream.listen(
            (final message) async {
              if (message is TextPayload) {
                serverReceivedMessages.add(message.data);
                if (serverReceivedMessages.length == 2) {
                  await channel.close();
                }
              }
            },
          );
        }));
      });

      final clientSocket =
          await WebSocket.connect('ws://localhost:$_serverPort');

      clientSocket.add('msg1');
      clientSocket.add('msg2');

      await expectLater(clientSocket, emits(emitsDone));
      expect(serverReceivedMessages, equals(['msg1', 'msg2']));

      await clientSocket.close();
    });

    test(
        'Given a WebSocket server that sends multiple messages upon client connection, '
        'when a client connects and sends an initial message, '
        'then the client receives all server messages in order', () async {
      await scheduleServer((final ctx) {
        return ctx.connect(expectAsync1((final channel) async {
          // Wait for first client message
          await channel.stream.first;

          channel.sink.add(const TextPayload('server_msg1'));
          channel.sink.add(const TextPayload('server_msg2'));
        }));
      });

      final clientSocket =
          await WebSocket.connect('ws://localhost:$_serverPort');

      // Send one message to trigger server responses
      clientSocket.add('initial_ping');

      await expectLater(
        clientSocket,
        emitsInOrder(['server_msg1', 'server_msg2']),
      );
      await clientSocket.close();
    });

    // This test is mostly a proof for why you should not never use
    // WebSocketChannel client-side.
    test(
        'Given a server that does not upgrade to WebSocket, '
        'when a client using WebSocketChannel.connect attempts to send a message, '
        'then a WebSocketChannelException occurs', () async {
      await scheduleServer(respondWith((final _) {
        // Intentionally do nothing to handle the WebSocket upgrade request
        return Response.notFound(
            body: Body.fromString('Not a WebSocket endpoint'));
      }));

      // Attempt to send a message should cause a failure
      final done = Completer<void>();
      var endOfScope = false;
      await runZonedGuarded(() async {
        // We use runZoneGuarded to capture the unhandled exception.
        // There are unfortunately nowhere we can use await to
        // capture the error.
        final wsUri = Uri.parse('ws://localhost:$_serverPort');
        final channel = WebSocketChannel.connect(wsUri); // <-- why not async!!
        // Waiting for ready will just hang here, unless a timeout is configured :-/
        // It is also easy to forget
        // await channel.ready;
        channel.sink.add('ping');
        // Now we have caused an unhandled error from an un-awaited future,
        // which is really annoying and require runZoneGuarded to capture.
        endOfScope = true; // to prove we make it here without error
      }, (final e, final _) {
        expect(e, isA<WebSocketChannelException>());
        done.complete();
      });
      await done.future; // wait for error to be captured
      expect(endOfScope, isTrue,
          reason: 'Sanity check that test reached end of scope');
    });

    test(
        'Given a server that does not upgrade to WebSocket, '
        'when a client uses WebSocket.connect, '
        'then the connection attempt throws a WebSocketException', () async {
      await scheduleServer(respondWith((final _) {
        // Intentionally do nothing to handle the WebSocket upgrade request
        return Response.notFound(
            body: Body.fromString('Not a WebSocket endpoint'));
      }));

      // Attempt to send a message should cause a failure
      expect(WebSocket.connect('ws://localhost:$_serverPort'),
          throwsA(isA<WebSocketException>())); // <-- this is the way!!
    });

    test(
        'Given a WebSocket server, '
        'when a client sends a binary message, '
        'then the server processes it and sends a binary response which the client receives',
        () async {
      final binaryData = List<int>.generate(10, (final i) => i);
      final responseBinaryData =
          Uint8List.fromList(List<int>.generate(10, (final i) => i * 2));

      await scheduleServer((final ctx) {
        return ctx.connect(expectAsync1((final channel) {
          channel.stream.first.then((final message) {
            expect(message, isA<BinaryPayload>());
            expect((message as BinaryPayload).data, equals(binaryData));

            channel.sink.add(BinaryPayload(responseBinaryData));
            channel.close();
          });
        }));
      });

      final clientSocket =
          await WebSocket.connect('ws://localhost:$_serverPort');

      clientSocket.add(binaryData);

      await expectLater(
        clientSocket,
        emitsInOrder([responseBinaryData, emitsDone]),
      );
      await clientSocket.close();
    });
  });
}
