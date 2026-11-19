import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import 'native_test_helpers.dart';

void main() {
  late RelicServer server;

  tearDown(() => server.close(force: true));

  test('Given a handler that awaits 20 event loop turns, '
      'when another client keeps requests arriving, '
      'then the turns are not each held back by the drain', () async {
    const turns = 20;
    server = await serveNative((req) async {
      if (req.url.path != '/turns') return Response.ok();
      final watch = Stopwatch()..start();
      for (var i = 0; i < turns; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      return Response.ok(body: Body.fromString('${watch.elapsedMicroseconds}'));
    });
    final base = 'http://127.0.0.1:${server.port}';

    var running = true;
    Future<void> keepRequestsArriving() async {
      final client = http.Client();
      try {
        while (running) {
          await client.get(Uri.parse('$base/'));
        }
      } finally {
        client.close();
      }
    }

    final busy = keepRequestsArriving();
    final client = http.Client();
    final times = <int>[];
    try {
      for (var i = 0; i < 30; i++) {
        final res = await client.get(Uri.parse('$base/turns'));
        times.add(int.parse(res.body));
      }
    } finally {
      running = false;
      client.close();
      await busy;
    }

    times.sort();
    final median = times[times.length ~/ 2];
    // A drain that lingers in the kernel with the event loop held delays
    // each turn by up to the 1 ms linger. The bound is half a linger per
    // turn, relative so that it holds on a slower runner.
    const lingerMicros = 1000;
    expect(median, lessThan(turns * lingerMicros ~/ 2));
  });
}
