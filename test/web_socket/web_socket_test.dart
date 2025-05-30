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
  await _server?.close(); // close previous, if any
  _server = await testServe(
    handler,
    context: securityContext,
  );
}

void main() {
  group('WebSocket Tests', () {
    test(
        'Given a WebSocket server, '
        'when a client connects and sends "tick", '
        'then the server responds with "tock" and the client receives it',
        () async {
      await scheduleServer((final ctx) {
        return ctx.connect(expectAsync1((final channel) async {
          // Expect a message from the client
          expect(
            channel.stream.first,
            completion(isA<TextPayload>()
                .having((final p) => p.data, 'data', equals('tick'))),
          );
          // Send a message back to the client
          channel.sink.add(const TextPayload('tock'));
          // Close the server-side of the connection after sending the message.
          // This also signals the client that no more messages are coming from the server.
          await channel.close();
        }));
      });

      final socket = await WebSocket.connect('ws://localhost:$_serverPort');

      // Send a message to the server
      socket.add('tick');

      // Expect a response from the server
      expect(socket, emitsInOrder(['tock', emitsDone]));
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
          channel.sink.add(const TextPayload('tock1'));
          channel.sink.add(const TextPayload('tock2'));
        }));
      });

      final clientSocket =
          await WebSocket.connect('ws://localhost:$_serverPort');

      await expectLater(
        clientSocket,
        emitsInOrder(['tock1', 'tock2']),
      );
      await clientSocket.close();
    });

    // This test is mostly a proof for why you should never use
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
        // Waiting for ready is easy to forget
        // await channel.ready; // <-- will raise
        channel.sink.add('tick');
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
        return ctx.connect(expectAsync1((final channel) async {
          final message = await channel.stream.first;
          expect(message, isA<BinaryPayload>());
          expect((message as BinaryPayload).data, equals(binaryData));

          channel.sink.add(BinaryPayload(responseBinaryData));
          await channel.close();
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

    test(
        'Given a WebSocket server, '
        'when a client connects and then closes the connection, '
        'then the server-side channel stream completes', () async {
      final serverChannelClosed = Completer<void>();

      await scheduleServer((final ctx) {
        return ctx.connect(expectAsync1((final channel) async {
          // Wait for the client to close the connection by
          // consuming the stream until it's done
          await channel.stream.drain(null);
          serverChannelClosed.complete();
        }));
      });

      final clientSocket =
          await WebSocket.connect('ws://localhost:$_serverPort');

      // Client closes the connection
      unawaited(clientSocket.close());

      // Verify that the server-side channel stream completed
      expect(serverChannelClosed.future, completes);
    });

    test(
        'Given a WebSocket server that closes the connection immediately, '
        'when a client connects, '
        'then the client-side stream completes', () async {
      await scheduleServer((final ctx) {
        return ctx.connect(expectAsync1((final channel) async {
          // Server immediately closes the connection
          await channel.close();
        }));
      });

      final clientSocket =
          await WebSocket.connect('ws://localhost:$_serverPort');

      // Expect the client-side stream to complete because the server closed it
      await expectLater(clientSocket, emits(emitsDone));
    });
  });
}
