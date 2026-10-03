import 'dart:async';
import 'dart:typed_data';

import 'package:relic_dst/relic_dst.dart';
import 'package:test/test.dart';

Uint8List _bytes(final int n) =>
    Uint8List.fromList(List.generate(n, (final i) => i & 0xff));

void main() {
  test(
    'Given a listener, '
    'when a client connects and writes 10000 bytes in one call, '
    'then the server end receives every byte in order, in several pieces.',
    () {
      final sim = Simulation(seed: 7);
      final network = SimNetwork(sim);
      final listener = network.listen();
      final received = BytesBuilder();
      var pieces = 0;

      sim.run(() async {
        final accepted = Completer<SimSocket>();
        listener.listen(accepted.complete);
        final client = await network.connect(listener.port);
        client.sink.add(_bytes(10000));
        unawaited(client.sink.close());
        final server = await accepted.future;
        await for (final piece in server.stream) {
          pieces++;
          received.add(piece);
        }
      });

      expect(received.takeBytes(), _bytes(10000));
      expect(pieces, greaterThan(1));
    },
  );

  test('Given no listener on a port, '
      'when a client connects to it, '
      'then the connection is refused.', () {
    final sim = Simulation(seed: 1);
    final network = SimNetwork(sim);

    expect(
      () => sim.run(() => network.connect(9)),
      throwsA(isA<SimConnectionRefused>()),
    );
  });

  test('Given a connection, '
      'when the client destroys it, '
      'then the server stream fails with SimConnectionReset.', () {
    final sim = Simulation(seed: 1);
    final network = SimNetwork(sim);
    final listener = network.listen();
    Object? error;

    sim.run(() async {
      final accepted = Completer<SimSocket>();
      listener.listen(accepted.complete);
      final client = await network.connect(listener.port);
      final server = await accepted.future;
      client.destroy();
      await server.stream.drain<void>().catchError((final Object e) {
        error = e;
      });
    });

    expect(error, isA<SimConnectionReset>());
  });

  test('Given a connection whose server end never reads, '
      'when the client writes twice the receive window and closes, '
      'then the close does not complete until the server reads.', () {
    final sim = Simulation(seed: 3);
    final network = SimNetwork(
      sim,
      options: const NetworkOptions(receiveWindow: 1000),
    );
    final listener = network.listen();
    var closed = false;
    var closedBeforeRead = false;
    var closedAfterRead = false;

    sim.run(() async {
      final accepted = Completer<SimSocket>();
      listener.listen(accepted.complete);
      final client = await network.connect(listener.port);
      final server = await accepted.future;
      client.sink.add(_bytes(2000));
      final closing = client.sink.close();
      unawaited(closing.then((_) => closed = true));
      await sim.sleep(const Duration(seconds: 1));
      closedBeforeRead = closed;
      await server.stream.drain<void>();
      await closing;
      closedAfterRead = closed;
    });

    expect(closedBeforeRead, isFalse);
    expect(closedAfterRead, isTrue);
  });

  test('Given a connection, '
      'when the client closes its side, '
      'then the server stream ends and the server can still write back.', () {
    final sim = Simulation(seed: 1);
    final network = SimNetwork(sim);
    final listener = network.listen();
    late List<int> answer;

    sim.run(() async {
      final accepted = Completer<SimSocket>();
      listener.listen(accepted.complete);
      final client = await network.connect(listener.port);
      final server = await accepted.future;
      await client.sink.close();
      await server.stream.drain<void>();
      server.sink.add(Uint8List.fromList([1, 2, 3]));
      await server.sink.close();
      answer = [for (final piece in await client.stream.toList()) ...piece];
    });

    expect(answer, [1, 2, 3]);
  });

  test('Given a listener with a connection in its backlog, '
      'when the listener closes, '
      'then the queued connection is reset and a new one is refused.', () {
    final sim = Simulation(seed: 1);
    final network = SimNetwork(sim);
    final listener = network.listen();
    Object? queuedError;
    Object? newError;

    sim.run(() async {
      final queued = await network.connect(listener.port);
      listener.close();
      await queued.stream.drain<void>().catchError((final Object e) {
        queuedError = e;
      });
      await network.connect(listener.port).catchError((final Object e) {
        newError = e;
        return queued;
      });
    });

    expect(queuedError, isA<SimConnectionReset>());
    expect(newError, isA<SimConnectionRefused>());
  });
}
