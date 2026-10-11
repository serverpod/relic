import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:relic_core/relic_core.dart';
import 'package:relic_native/relic_native.dart';
import 'package:test/test.dart';

void main() {
  test('Given an idle connection and a request in flight, '
      'when the adapter closes gracefully, '
      'then the idle connection and the listener close '
      'and the close completes once the request is answered', () async {
    final adapter = await NativeAdapter.bind(InternetAddress.loopbackIPv4);
    addTearDown(() => adapter.close(force: true));
    final held = Completer<AdapterExchange>();
    adapter.start(held.complete);
    final port = adapter.listeners.first.port;
    final idle = await Socket.connect('127.0.0.1', port);
    final idleEnded = idle.drain<void>();
    final busy = await Socket.connect('127.0.0.1', port);
    busy.write('GET /hold HTTP/1.1\r\nHost: x\r\n\r\n');
    await busy.flush();
    final exchange = await held.future;

    final closing = adapter.close();

    await idleEnded.timeout(const Duration(seconds: 3));
    expect(await _refusedWithin(port, const Duration(seconds: 3)), isTrue);
    await exchange.respond(Response.ok());
    await closing.timeout(const Duration(seconds: 3));
    final reply = await utf8.decodeStream(busy);
    expect(reply, startsWith('HTTP/1.1 200'));
  });
}

/// Whether a connection to [port] is refused before [limit] passes. The
/// acceptor closes the listener a moment after the stop.
Future<bool> _refusedWithin(int port, Duration limit) async {
  final clock = Stopwatch()..start();
  while (clock.elapsed < limit) {
    try {
      final probe = await Socket.connect('127.0.0.1', port);
      probe.destroy();
    } on SocketException {
      return true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return false;
}
