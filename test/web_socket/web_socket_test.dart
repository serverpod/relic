import 'dart:async';
import 'dart:io' as io;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../headers/headers_test_utils.dart';
import '../util/test_util.dart';

RelicServer? _server;
int get _serverPort => _server!.url.port;

Future<void> scheduleServer(
  final Handler handler, {
  final io.SecurityContext? securityContext,
}) async {
  await _server?.close(); // close previous, if any
  _server = await testServe(
    handler,
    context: securityContext,
  );
}

void main() {
  tearDown(() async {
    await _server?.close(); // close previous, if any
    _server = null;
  });

  group('WebSocket Tests', () {
    test(
        'Given a WebSocket server, '
        'when a client connects and sends "tick", '
        'then the server responds with "tock" and the client receives it',
        () async {
      await scheduleServer((final ctx) {
        return ctx.connect(expectAsync1((final serverSocket) async {
          // Expect a message from the client
          await for (final e in serverSocket.events) {
            expect(e, TextDataReceived('tick'));
            // Send a message back to the client
            serverSocket.sendText('tock');
            // Close the server-side of the connection after sending the message.
            // This also signals the client that no more messages are coming from the server.
            await serverSocket.close();
          }
        }));
      });

      final clientSocket =
          await WebSocket.connect(Uri.parse('ws://localhost:$_serverPort'));

      // Send a message to the server
      clientSocket.sendText('tick');

      // Expect a response from the server
      await expectLater(
        clientSocket.events,
        emitsInOrder([
          TextDataReceived('tock'),
          CloseReceived(1005),
          emitsDone,
        ]),
      );
    });

    test(
        'Given a WebSocket server, '
        'when a client sends multiple messages, '
        'then the server receives all messages in order', () async {
      final serverReceivedMessages = <String>[];
      await scheduleServer((final ctx) {
        return ctx.connect(expectAsync1((final serverSocket) {
          serverSocket.events.listen(
            (final message) async {
              if (message is TextDataReceived) {
                serverReceivedMessages.add(message.text);
                if (serverReceivedMessages.length == 2) {
                  await serverSocket.close();
                }
              }
            },
          );
        }));
      });

      final clientSocket =
          await WebSocket.connect(Uri.parse('ws://localhost:$_serverPort'));

      clientSocket.sendText('msg1');
      clientSocket.sendText('msg2');

      await expectLater(
          clientSocket.events, emitsInOrder([CloseReceived(1005), emitsDone]));
      expect(serverReceivedMessages, equals(['msg1', 'msg2']));
    });

    test(
        'Given a WebSocket server that sends multiple messages upon client connection, '
        'when a client connects and sends an initial message, '
        'then the client receives all server messages in order', () async {
      await scheduleServer((final ctx) {
        return ctx.connect(expectAsync1((final serverSocket) async {
          serverSocket.sendText('tock1');
          serverSocket.sendText('tock2');
        }));
      });

      final clientSocket =
          await WebSocket.connect(Uri.parse('ws://localhost:$_serverPort'));

      await expectLater(
        clientSocket.events,
        emitsInOrder(['tock1', 'tock2'].map(TextDataReceived.new)),
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
      expect(WebSocket.connect(Uri.parse('ws://localhost:$_serverPort')),
          throwsA(isA<WebSocketException>())); // <-- this is the way!!
    });

    test(
        'Given a WebSocket server, '
        'when a client sends a binary message, '
        'then the server processes it and sends a binary response which the client receives',
        () async {
      final binaryData =
          Uint8List.fromList(List<int>.generate(10, (final i) => i));
      final responseBinaryData =
          Uint8List.fromList(List<int>.generate(10, (final i) => i * 2));

      await scheduleServer((final ctx) {
        return ctx.connect(expectAsync1((final serverSocket) async {
          final message = await serverSocket.events.first;
          expect(message, isA<BinaryDataReceived>());
          expect((message as BinaryDataReceived).data, equals(binaryData));

          serverSocket.sendBytes(responseBinaryData);
          await serverSocket.close();
        }));
      });

      final clientSocket =
          await WebSocket.connect(Uri.parse('ws://localhost:$_serverPort'));

      clientSocket.sendBytes(binaryData);

      await expectLater(
        clientSocket.events,
        emitsInOrder([
          BinaryDataReceived(responseBinaryData),
          CloseReceived(1005),
          emitsDone
        ]),
      );
    });

    test(
        'Given a WebSocket server, '
        'when a client connects and then closes the connection, '
        'then the server-side events stream completes', () async {
      final serverSocketClosed = Completer<void>();

      await scheduleServer((final ctx) {
        return ctx.connect(expectAsync1((final serverSocket) async {
          // Wait for the client to close the connection by
          // consuming the stream until it's done
          await serverSocket.events.drain(null);
          serverSocketClosed.complete();
        }));
      });

      final clientSocket =
          await WebSocket.connect(Uri.parse('ws://localhost:$_serverPort'));

      // Client closes the connection
      unawaited(clientSocket.close());

      // Verify that the server-side events stream completed
      expect(serverSocketClosed.future, completes);
    });

    test(
        'Given a WebSocket server that closes the connection immediately, '
        'when a client connects, '
        'then the client-side stream completes', () async {
      await scheduleServer((final ctx) {
        return ctx.connect(expectAsync1((final serverSocket) async {
          // Server immediately closes the connection
          await serverSocket.close();
        }));
      });

      final clientSocket =
          await WebSocket.connect(Uri.parse('ws://localhost:$_serverPort'));

      // Expect the client-side stream to complete because the server closed it
      await expectLater(
          clientSocket.events, emitsInOrder([CloseReceived(1005), emitsDone]));
    });

    test(
        'Given a web socket connection with a ping interval, '
        'when a client connects and remains idle for a period, '
        'then the connection is maintained by pings and subsequent communication is successful',
        () async {
      const pingInterval = Duration(milliseconds: 5);
      final tooLong = pingInterval * 3; // Must be > pingInterval

      _server = await testServe(
        (final ctx) {
          return ctx.connect(
            (final serverSocket) async {
              serverSocket.pingInterval = pingInterval;
              int i = 0;
              await for (final e in serverSocket.events) {
                expect(e, TextDataReceived('tick-$i'));
                if (e is CloseReceived) break;
                // Server remains idle for a period, relying on pings to keep connection alive.
                await Future<void>.delayed(tooLong);
                serverSocket.sendText('tock-$i');
                ++i;
              }
            },
          );
        },
      );

      final clientSocket =
          await WebSocket.connect(Uri.parse('ws://localhost:$_serverPort'));

      final check = expectLater(
        clientSocket.events,
        emitsInOrder(
            List.generate(n, (final i) => TextDataReceived('tock-$i'))),
      );

      for (int i = 0; i < n; ++i) {
        // Client remains idle for a period, relying on pings to keep connection alive.
        await Future<void>.delayed(tooLong);
        clientSocket.sendText('tick-$i');
      }

      await check;
    });

    test(
      'Given a web socket connection with a ping interval, '
      'when the server side disappear, '
      'then client socket closes',
      () async {
        const pingInterval = Duration(milliseconds: 5);

        final recv = ReceivePort();
        final isolate = await Isolate.spawn((final sendPort) async {
          final server = await testServe((final ctx) {
            return ctx.connect((final serverSocket) async {
              serverSocket.events.listen((final _) {});
              serverSocket.pingInterval = pingInterval;
              serverSocket.sendText('running');
            });
          });
          sendPort.send(server.url.port);
        }, recv.sendPort);

        final port = (await recv.first) as int;
        final clientSocket =
            await WebSocket.connect(Uri.parse('ws://localhost:$port'));

        final check = expectLater(
            clientSocket.events,
            emitsInOrder([
              TextDataReceived('running'),
              // 1006 CLOSE_ABNORMAL. Indicates that the connection was closed
              // abnormally, e.g., without sending or receiving a Close control
              // frame.
              //CloseReceived(1006), // <-- correct, but
              isA<CloseReceived>(), // older dart versions gets it wrong
              emitsDone,
            ]));

        isolate.kill(); // kill the isolate to stop the server

        await check;
      },
    );

    test(
      'Given a web socket connection with a ping interval, '
      'when the client side blocks, '
      'then the server socket closes',
      () async {
        const pingInterval = Duration(milliseconds: 5);
        final done = Completer<void>();

        await scheduleServer((final ctx) {
          return ctx.connect(expectAsync1((final serverSocket) async {
            serverSocket.pingInterval = pingInterval;
            await expectLater(
                serverSocket.events,
                emitsInOrder([
                  TextDataReceived('running'),
                  CloseReceived(1001), // 1001 indicates normal closure?!
                  emitsDone,
                ]));
            done.complete();
          }));
        });

        final isolate = await Isolate.spawn((final port) async {
          final clientSocket =
              await WebSocket.connect(Uri.parse('ws://localhost:$port'));
          clientSocket.sendText('running');
          // no flush, so leave a bit of time before blocking
          await Future<void>.delayed(const Duration(milliseconds: 100));
          while (true) {} // busy wait to simulate offline client
        }, _serverPort);

        await done.future;

        isolate.kill();
      },
    );
  });
}
