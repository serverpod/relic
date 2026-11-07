import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:relic_core/relic_core.dart';
import 'package:relic_native/relic_native.dart';
import 'package:test/test.dart';
import 'package:test_utils/adapter_conformance.dart';

import 'native_test_helpers.dart';

void main() {
  late NativeAdapter adapter;
  late StreamIterator<AdapterExchange> exchanges;

  setUp(() async {
    // No timeouts, so no sweep wakes the reactor. Only the abort can end
    // a connection.
    adapter = await NativeAdapter.bind(
      InternetAddress.loopbackIPv4,
      options: const NativeOptions(
        idleTimeout: Duration.zero,
        headerTimeout: Duration.zero,
        bodyTimeout: Duration.zero,
        writeTimeout: Duration.zero,
      ),
    );
    addTearDown(() => adapter.close(force: true));
    final controller = StreamController<AdapterExchange>();
    adapter.start(controller.add);
    exchanges = StreamIterator(controller.stream);
  });

  Future<AdapterExchange> nextExchange() async {
    expect(
      await exchanges.moveNext().timeout(const Duration(seconds: 3)),
      isTrue,
    );
    return exchanges.current;
  }

  /// A connection to the adapter, destroyed when the test ends.
  Future<Socket> connect() async {
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      adapter.listeners.first.port,
    );
    addTearDown(socket.destroy);
    return socket;
  }

  Future<String> answerNextRequest() async {
    final reply = rawExchange(
      adapter.listeners.first.port,
      'GET /next HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
      timeout: const Duration(seconds: 3),
    );
    await (await nextExchange()).respond(Response.ok());
    return reply;
  }

  test(
    'Given an upgraded exchange whose 101 the client has, '
    'when the exchange is aborted, '
    'then the connection closes and the adapter answers the next request.',
    () async {
      final socket = await connect();
      socket.write(webSocketUpgradeRequest);
      await socket.flush();
      final exchange = await nextExchange();
      await exchange.upgradeWebSocket(webSocketUpgradeAccept);
      final head = Completer<void>();
      final received = <int>[];
      final closed = socket.listen((bytes) {
        received.addAll(bytes);
        if (!head.isCompleted && latin1.decode(received).contains('\r\n\r\n')) {
          head.complete();
        }
      }).asFuture<void>();
      await head.future.timeout(const Duration(seconds: 3));

      exchange.abort();

      await closed.timeout(const Duration(seconds: 3));
      expect(latin1.decode(received), startsWith('HTTP/1.1 101 '));
      expect(await answerNextRequest(), startsWith('HTTP/1.1 200 '));
    },
  );

  test(
    'Given an exchange the handler upgraded, '
    'when the exchange is aborted before the 101 is out, '
    'then the connection closes and the adapter answers the next request.',
    () async {
      final socket = await connect();
      socket.write(webSocketUpgradeRequest);
      await socket.flush();
      final exchange = await nextExchange();
      await exchange.upgradeWebSocket(webSocketUpgradeAccept);

      exchange.abort();

      await socket.drain<void>().timeout(const Duration(seconds: 3));
      expect(await answerNextRequest(), startsWith('HTTP/1.1 200 '));
    },
  );

  test(
    'Given a hijacked exchange whose bytes the client has, on a reactor '
    'gone idle, '
    'when the exchange is aborted, '
    'then the connection closes and the adapter answers the next request',
    () async {
      final socket = await connect();
      socket.write('GET /raw HTTP/1.1\r\nHost: localhost\r\n\r\n');
      await socket.flush();
      final exchange = await nextExchange();
      final channel = await exchange.hijack();
      channel.sink.add(utf8.encode('hello'));
      final first = Completer<void>();
      final closed = socket.listen((_) {
        if (!first.isCompleted) first.complete();
      }).asFuture<void>();
      await first.future.timeout(const Duration(seconds: 3));
      // Long enough for the drain to run out of work and park the reactor.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      exchange.abort();

      await closed.timeout(const Duration(seconds: 3));
      expect(await answerNextRequest(), startsWith('HTTP/1.1 200 '));
    },
  );
}
