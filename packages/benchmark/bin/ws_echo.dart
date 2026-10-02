// WebSocket echo round trips per second through one adapter, with
// dart:io clients in isolates of their own (`--client-isolates`, 4 by
// default). The dart:io adapter frames with dart:io's
// WebSocketTransformer, the native one with relic_core's framer over a
// hijacked connection, so the two runs compare the framers.
// `--adapter=shelf` is shelf_web_socket on dart:io, for comparison.
//
//   dart run bin/ws_echo.dart --adapter=native --connections=64 --seconds=10

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:benchmark/src/echo_web_socket.dart';
import 'package:benchmark/src/options.dart';
import 'package:benchmark/src/serve.dart';
import 'package:benchmark/src/shelf_server.dart';
import 'package:config/config.dart';

enum EchoOption<V> implements OptionDefinition<V> {
  adapter(
    StringOption(
      argName: 'adapter',
      helpText: 'The adapter that serves the echo',
      defaultsTo: 'native',
      allowedValues: ['io', 'native', 'shelf'],
    ),
  ),

  connections(
    IntOption(
      argName: 'connections',
      helpText: 'Connections in all, split over the client isolates',
      defaultsTo: 64,
      min: 1,
    ),
  ),

  seconds(
    IntOption(
      argName: 'seconds',
      helpText: 'How long the clients send',
      defaultsTo: 10,
      min: 1,
    ),
  ),

  size(
    IntOption(
      argName: 'size',
      helpText: 'Bytes per message',
      defaultsTo: 64,
      min: 0,
    ),
  ),

  binary(
    FlagOption(
      argName: 'binary',
      helpText: 'Send binary messages instead of text',
      defaultsTo: false,
      negatable: false,
    ),
  ),

  clientIsolates(
    IntOption(
      argName: 'client-isolates',
      helpText: 'Isolates the clients run in',
      defaultsTo: 4,
      min: 1,
    ),
  );

  const EchoOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

Future<void> main(List<String> args) async {
  final config = resolveOptions(
    EchoOption.values,
    args,
    synopsis: 'usage: dart run bin/ws_echo.dart [options]',
  );
  final adapter = config.value(EchoOption.adapter);
  final connections = config.value(EchoOption.connections);
  final seconds = config.value(EchoOption.seconds);
  final size = config.value(EchoOption.size);
  final binary = config.value(EchoOption.binary);
  final clientIsolates = config.value(EchoOption.clientIsolates);

  final (:port, :close) = await startServer(
    adapter,
    Served.handler(echoWebSocket, shelfWebSocketEcho),
    port: 0,
  );
  final url = 'ws://127.0.0.1:$port';

  // The clients run in their own isolates. In the server's isolate they
  // would share its event loop, and the dart:io client would be what the
  // run measures.
  final perIsolate = connections ~/ clientIsolates;
  final runs = await Future.wait([
    for (var i = 0; i < clientIsolates; i++)
      _spawnClients((
        url: url,
        connections: perIsolate,
        seconds: seconds,
        size: size,
        binary: binary,
      )),
  ]);
  final latencies = [for (final run in runs) ...run]..sort();
  stdout.writeln(
    '$adapter: ${(latencies.length / seconds).round()} round trips/s, '
    'p50 ${latencies[latencies.length ~/ 2]} us, '
    'p99 ${latencies[latencies.length * 99 ~/ 100]} us, '
    '${perIsolate * clientIsolates} connections from $clientIsolates '
    'client isolates, $size bytes ${binary ? 'binary' : 'text'}',
  );
  await close();
}

typedef _ClientRun = ({
  String url,
  int connections,
  int seconds,
  int size,
  bool binary,
});

/// Starts [run] in a new isolate and completes with the latency of every
/// round trip, in microseconds.
Future<List<int>> _spawnClients(_ClientRun run) =>
    Isolate.run(() => _runClients(run));

Future<List<int>> _runClients(_ClientRun run) async {
  final sockets = [
    for (var i = 0; i < run.connections; i++) await WebSocket.connect(run.url),
  ];
  final text = 'x' * run.size;
  final bytes = Uint8List(run.size);
  var running = true;
  final latencies = <int>[];
  final clock = Stopwatch()..start();

  Future<void> drive(WebSocket socket) async {
    final echoes = StreamIterator(socket);
    while (running) {
      final sent = clock.elapsedMicroseconds;
      socket.add(run.binary ? bytes : text);
      if (!await echoes.moveNext()) break;
      latencies.add(clock.elapsedMicroseconds - sent);
    }
    await socket.close();
  }

  final drivers = sockets.map(drive).toList();
  await Future<void>.delayed(Duration(seconds: run.seconds));
  running = false;
  await Future.wait(drivers);
  return latencies;
}
