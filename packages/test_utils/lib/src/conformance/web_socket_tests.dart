import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'conformance.dart';

final _throwsWscClosed = throwsA(isA<WebSocketConnectionClosed>());

void webSocketTests(AdapterConformance conformance) {
  group('Given WebSocket support', () {
    _webSocketTests(conformance);
  }, skip: conformance.skipWebSocket);
}

void _webSocketTests(AdapterConformance conformance) {
  RelicServer? server;
  int serverPort() => server!.url.port;

  Future<void> scheduleServer(Handler handler) async {
    await server?.close();
    server = await conformance.serve(handler);
  }

  tearDown(() async {
    await server?.close();
    server = null;
  });

  group('Given a WebSocket server', () {
    test(
      'when a client connects and sends "tick", '
      'then the server responds with "tock" and the client receives it',
      () async {
        await scheduleServer((req) {
          return WebSocketUpgrade(
            expectAsync1((serverSocket) async {
              await for (final e in serverSocket.events) {
                expect(e, TextDataReceived('tick'));
                serverSocket.sendText('tock');
                // Closing the server side also tells the client no more
                // messages are coming.
                await serverSocket.close();
              }
            }),
          );
        });

        final clientSocket = await WebSocket.connect(
          Uri.parse('ws://localhost:${serverPort()}'),
        );

        clientSocket.sendText('tick');

        await expectLater(
          clientSocket.events,
          emitsInOrder([
            TextDataReceived('tock'),
            CloseReceived(1005),
            emitsDone,
          ]),
        );
      },
    );

    test('when a client sends multiple messages, '
        'then the server receives all messages in order', () async {
      final serverReceivedMessages = <String>[];
      await scheduleServer((req) {
        return WebSocketUpgrade(
          expectAsync1((serverSocket) {
            serverSocket.events.listen((message) async {
              if (message is TextDataReceived) {
                serverReceivedMessages.add(message.text);
                if (serverReceivedMessages.length == 2) {
                  await serverSocket.close();
                }
              }
            });
          }),
        );
      });

      final clientSocket = await WebSocket.connect(
        Uri.parse('ws://localhost:${serverPort()}'),
      );

      clientSocket.sendText('msg1');
      clientSocket.sendText('msg2');

      await expectLater(
        clientSocket.events,
        emitsInOrder([CloseReceived(1005), emitsDone]),
      );
      expect(serverReceivedMessages, equals(['msg1', 'msg2']));
    });

    test('when the server sends multiple messages upon connection, '
        'then the client receives all server messages in order', () async {
      await scheduleServer((req) {
        return WebSocketUpgrade(
          expectAsync1((serverSocket) async {
            serverSocket.sendText('tock1');
            serverSocket.sendText('tock2');
          }),
        );
      });

      final clientSocket = await WebSocket.connect(
        Uri.parse('ws://localhost:${serverPort()}'),
      );

      await expectLater(
        clientSocket.events,
        emitsInOrder(['tock1', 'tock2'].map(TextDataReceived.new)),
      );
      await clientSocket.close();
    });

    test(
      'when a client sends a binary message, '
      'then the server processes it and the client receives a binary reply',
      () async {
        final binaryData = Uint8List.fromList(List<int>.generate(10, (i) => i));
        final responseBinaryData = Uint8List.fromList(
          List<int>.generate(10, (i) => i * 2),
        );

        await scheduleServer((req) {
          return WebSocketUpgrade(
            expectAsync1((serverSocket) async {
              final message = await serverSocket.events.first;
              expect(message, isA<BinaryDataReceived>());
              expect((message as BinaryDataReceived).data, equals(binaryData));

              serverSocket.sendBytes(responseBinaryData);
              await serverSocket.close();
            }),
          );
        });

        final clientSocket = await WebSocket.connect(
          Uri.parse('ws://localhost:${serverPort()}'),
        );

        clientSocket.sendBytes(binaryData);

        await expectLater(
          clientSocket.events,
          emitsInOrder([
            BinaryDataReceived(responseBinaryData),
            CloseReceived(1005),
            emitsDone,
          ]),
        );
      },
    );

    test('when a client connects and then closes the connection, '
        'then the server-side events stream completes', () async {
      final serverSocketClosed = Completer<void>();

      await scheduleServer((req) {
        return WebSocketUpgrade(
          expectAsync1((serverSocket) async {
            await serverSocket.events.drain(null);
            serverSocketClosed.complete();
          }),
        );
      });

      final clientSocket = await WebSocket.connect(
        Uri.parse('ws://localhost:${serverPort()}'),
      );

      unawaited(clientSocket.close());

      expect(serverSocketClosed.future, completes);
    });

    test('when the server closes the connection immediately, '
        'then the client-side stream completes', () async {
      await scheduleServer((req) {
        return WebSocketUpgrade(
          expectAsync1((serverSocket) async {
            await serverSocket.close();
          }),
        );
      });

      final clientSocket = await WebSocket.connect(
        Uri.parse('ws://localhost:${serverPort()}'),
      );

      await expectLater(
        clientSocket.events,
        emitsInOrder([CloseReceived(1005), emitsDone]),
      );
    });
  });

  group('Given a server that does not upgrade to WebSocket', () {
    // Mostly a proof of why WebSocketChannel is a poor client.
    test('when a client using WebSocketChannel.connect sends a message, '
        'then a WebSocketChannelException surfaces in the zone', () async {
      await scheduleServer(
        respondWith((_) {
          return Response.notFound(
            body: Body.fromString('Not a WebSocket endpoint'),
          );
        }),
      );

      final done = Completer<void>();
      var endOfScope = false;
      await runZonedGuarded(
        () async {
          // Nothing here can be awaited to observe the failure, hence the
          // guarded zone.
          final wsUri = Uri.parse('ws://localhost:${serverPort()}');
          final channel = WebSocketChannel.connect(wsUri);
          // `await channel.ready` is easy to forget and would throw here.
          channel.sink.add('tick');
          endOfScope = true;
        },
        (e, _) {
          expect(e, isA<WebSocketChannelException>());
          done.complete();
        },
      );
      await done.future;
      expect(
        endOfScope,
        isTrue,
        reason: 'Sanity check that test reached end of scope',
      );
    });

    test('when a client uses WebSocket.connect, '
        'then the connection attempt throws a WebSocketException', () async {
      await scheduleServer(
        respondWith((_) {
          return Response.notFound(
            body: Body.fromString('Not a WebSocket endpoint'),
          );
        }),
      );

      expect(
        WebSocket.connect(Uri.parse('ws://localhost:${serverPort()}')),
        throwsA(isA<WebSocketException>()),
      );
    });
  });

  group('Given a web socket connection with a ping interval', () {
    test(
      'when a client connects and remains idle for a period, '
      'then pings keep the connection up and later messages arrive',
      () async {
        // Long enough for a loaded machine to answer each ping before the
        // next one is due. A framed socket closes on the first missed pong.
        const pingInterval = Duration(milliseconds: 50);
        final tooLong = pingInterval * 3;

        await scheduleServer((req) {
          return WebSocketUpgrade((serverSocket) async {
            serverSocket.pingInterval = pingInterval;
            await for (final e in serverSocket.events) {
              if (e is CloseReceived) break;
              expect(e, TextDataReceived('tick'));
              await Future<void>.delayed(tooLong);
              serverSocket.sendText('tock');
            }
          });
        });

        final clientSocket = await WebSocket.connect(
          Uri.parse('ws://localhost:${serverPort()}'),
        );

        await Future<void>.delayed(tooLong);
        clientSocket.sendText('tick');

        await expectLater(clientSocket.events, emits(TextDataReceived('tock')));
      },
    );

    test('when the client side blocks, '
        'then the server socket closes', () async {
      const pingInterval = Duration(milliseconds: 5);
      final done = Completer<void>();

      await scheduleServer((req) {
        return WebSocketUpgrade(
          expectAsync1((serverSocket) async {
            serverSocket.pingInterval = pingInterval;
            expect(serverSocket.pingInterval, pingInterval);
            await expectLater(
              serverSocket.events,
              emitsInOrder([
                TextDataReceived('running'),
                CloseReceived(1001),
                emitsDone,
              ]),
            );
            done.complete();
          }),
        );
      });

      final isolate = await Isolate.spawn((port) async {
        final clientSocket = await WebSocket.connect(
          Uri.parse('ws://localhost:$port'),
        );
        clientSocket.sendText('running');
        // No flush, so leave a bit of time before blocking.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        while (true) {} // busy wait to simulate an offline client
      }, serverPort());

      await done.future;

      isolate.kill();
    });
  });

  test('Given a web socket connection that has been closed, '
      'when trying to use close, sendText, or sendBytes, '
      'then it throws WebSocketConnectionClosed', () async {
    await scheduleServer((req) {
      return WebSocketUpgrade(
        expectAsync1((serverSocket) async {
          await for (final _ in serverSocket.events) {
            expect(serverSocket.close(), _throwsWscClosed);
            expect(() => serverSocket.sendText('hello'), _throwsWscClosed);
            expect(
              () => serverSocket.sendBytes(utf8.encode('hello')),
              _throwsWscClosed,
            );
            expect(serverSocket.protocol, '');
            expect(() => serverSocket.toString(), returnsNormally);
          }
        }),
      );
    });
    final clientSocket = await WebSocket.connect(
      Uri.parse('ws://localhost:${serverPort()}'),
    );
    await clientSocket.close();
    expect(clientSocket.close(), _throwsWscClosed);
    expect(() => clientSocket.sendText('hello'), _throwsWscClosed);
    expect(
      () => clientSocket.sendBytes(utf8.encode('hello')),
      _throwsWscClosed,
    );
    expect(clientSocket.events, emitsDone);
    expect(clientSocket.protocol, '');
    expect(() => clientSocket.toString(), returnsNormally);
  });

  test('Given a web socket connection that has been closed, '
      'when trying to use tryClose, trySendText, or trySendBytes, '
      'then they return false', () async {
    await scheduleServer((req) {
      return WebSocketUpgrade(
        expectAsync1((serverSocket) async {
          await for (final _ in serverSocket.events) {
            expect(serverSocket.tryClose(), completion(isFalse));
            expect(serverSocket.trySendText('hello'), isFalse);
            expect(serverSocket.trySendBytes(utf8.encode('hello')), isFalse);
            expect(serverSocket.protocol, '');
            expect(() => serverSocket.toString(), returnsNormally);
          }
        }),
      );
    });
    final clientSocket = await WebSocket.connect(
      Uri.parse('ws://localhost:${serverPort()}'),
    );
    await clientSocket.close();
    expect(clientSocket.events, emitsDone);
  });
}
