import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import 'conformance.dart';

/// A response whose framing does not parse, so [AdapterExchange.respond]
/// fails before anything is written.
final _unwritable = Response.ok(
  headers: Headers.build((mh) => mh['connection'] = ['close;x']),
);

/// Chunks without end, so the response streams and the peer's buffer
/// fills.
Stream<Uint8List> _endless() async* {
  final chunk = Uint8List(1 << 16);
  while (true) {
    yield chunk;
    await Future<void>.delayed(Duration.zero);
  }
}

/// What [AdapterExchange.respond], [AdapterExchange.abort] and
/// [AdapterExchange.done] owe a sink when a response cannot be finished.
void exchangeAbortTests(AdapterConformance conformance) {
  late Adapter adapter;

  setUp(() async {
    adapter = await conformance.bindAdapter();
  });

  tearDown(() => adapter.close(force: true));

  int port() => adapter.listeners.first.port;

  Future<String> get() => rawExchange(
    port(),
    'GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
    timeout: const Duration(seconds: 2),
  );

  Future<Socket> request() async {
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, port());
    socket.write('GET / HTTP/1.1\r\nHost: x\r\n\r\n');
    await socket.flush();
    return socket;
  }

  test('Given a sink that aborts after a failed respond, '
      'when a request is made, '
      'then the connection is closed without a response', () async {
    adapter.start((exchange) async {
      try {
        await exchange.respond(_unwritable);
      } catch (_) {
        exchange.abort();
      }
    });

    final reply = await get();

    expect(reply, isEmpty);
  });

  test('Given a sink that responds again after a failed respond, '
      'when a request is made, '
      'then the second response reaches the client', () async {
    adapter.start((exchange) async {
      try {
        await exchange.respond(_unwritable);
      } catch (_) {
        await exchange.respond(Response.internalServerError());
      }
    });

    final reply = await get();

    expect(reply, startsWith('HTTP/1.1 500'));
  });

  test('Given a sink that aborts after a failed respond, '
      'when a request is made, '
      'then done reports the abort', () async {
    final ends = Completer<ExchangeEnd>();
    adapter.start((exchange) async {
      try {
        await exchange.respond(_unwritable);
      } catch (_) {
        exchange.abort();
      }
      ends.complete(await exchange.done);
    });

    await get();

    expect(await ends.future, ExchangeEnd.aborted);
  });

  test('Given a streamed response, '
      'when the peer disconnects before it ends, '
      'then respond fails instead of staying pending', () async {
    final responded = Completer<Object>();
    adapter.start((exchange) async {
      try {
        await exchange.respond(
          Response.ok(body: Body.fromDataStream(_endless())),
        );
        responded.complete('completed');
      } catch (e) {
        responded.complete(e);
      }
    });

    final socket = await request();
    await socket.first;
    socket.destroy();

    expect(
      await responded.future.timeout(const Duration(seconds: 5)),
      isA<SocketException>(),
    );
  }, skip: conformance.skipRespondFailure);

  test('Given a streamed response, '
      'when the exchange is aborted during it, '
      'then respond fails and done reports the abort', () async {
    final responded = Completer<Object>();
    late AdapterExchange current;
    adapter.start((exchange) async {
      current = exchange;
      try {
        await exchange.respond(
          Response.ok(body: Body.fromDataStream(_endless())),
        );
        responded.complete('completed');
      } catch (e) {
        responded.complete(e);
      }
    });

    final socket = await request();
    await socket.first;
    current.abort();

    expect(
      await responded.future.timeout(const Duration(seconds: 5)),
      isA<SocketException>(),
    );
    expect(await current.done, ExchangeEnd.aborted);
    socket.destroy();
  }, skip: conformance.skipRespondFailure);
}
