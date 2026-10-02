// Soak test for the native adapter. In-process clients send mixed
// traffic for a set time while the script samples the resident set size
// and the open file descriptors. The claim under test is that neither
// grows once the server is warm.
//
//   dart tool/soak.dart --seconds=180 --clients=32
//
// `--mix=` narrows the traffic to one route (small, big, chunked, echo,
// unread, drop). `--adapter=io` runs the same soak against the dart:io
// adapter, which tells client-side growth from server-side growth.
//
// The numbers are the whole VM's, clients included, so read the trend
// after warm-up. On macOS the RSS keeps counting pages that malloc freed
// and marked reusable until the kernel takes them back, so a native
// workload that allocates big buffers shows an RSS that climbs for
// minutes with a flat footprint. Read the footprint column there.

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:relic_io/relic_io.dart';
import 'package:relic_native/relic_native.dart';

const _inlineLimit = 64 * 1024;
const _routes = ['small', 'big', 'chunked', 'echo', 'unread', 'drop'];
const _sampleEvery = Duration(seconds: 10);

final _small = Uint8List.fromList('hello'.codeUnits);
final _big = Uint8List(1 << 20);

Future<void> main(List<String> args) async {
  final seconds = _intArg(args, 'seconds', 180);
  final clients = _intArg(args, 'clients', 32);
  final mix = _stringArg(args, 'mix', 'all');
  final adapter = _stringArg(args, 'adapter', 'native');
  if (!const {'all', ..._routes}.contains(mix) ||
      !const {'native', 'io'}.contains(adapter)) {
    stderr.writeln(
      'usage: --seconds=N --clients=N --mix=all|${_routes.join('|')} --adapter=native|io',
    );
    exitCode = 64;
    return;
  }

  final server = RelicServer(
    () => adapter == 'io'
        ? IOAdapter.bind(InternetAddress.loopbackIPv4)
        : NativeAdapter.bind(
            InternetAddress.loopbackIPv4,
            maxInlineBody: _inlineLimit,
          ),
  );
  await server.mountAndStart(_handler);
  final port = server.port;
  stdout.writeln(
    'soak: $adapter, port $port, $clients clients, ${seconds}s, mix $mix',
  );

  final stop = Completer<void>();
  final counts = _Counts();
  final workers = [
    for (var i = 0; i < clients; i++)
      _client(port, i, mix, stop.future, counts),
  ];

  final clock = Stopwatch()..start();
  stdout.writeln('elapsed_s\trss_mb\tfootprint_mb\tfds\trequests\terrors');
  final sampler = Timer.periodic(_sampleEvery, (_) {
    stdout.writeln(
      '${clock.elapsed.inSeconds}\t${ProcessInfo.currentRss >> 20}\t'
      '${_footprintMb()}\t${_openFds()}\t${counts.requests}\t'
      '${counts.errors}',
    );
  });
  await Future<void>.delayed(Duration(seconds: seconds));
  sampler.cancel();
  stop.complete();
  await Future.wait(workers);
  await server.close(force: true);
  stdout.writeln('done: ${counts.requests} requests, ${counts.errors} errors');
}

Future<Response> _handler(Request req) async {
  switch (req.url.path) {
    case '/small':
      return Response.ok(body: Body.fromBytes(_small));
    case '/big':
      return Response.ok(body: Body.fromBytes(_big));
    case '/chunked':
      return Response.ok(
        body: Body.fromDataStream(
          Stream.fromIterable(List.filled(16, Uint8List(64 * 1024))),
        ),
      );
    case '/echo':
      final bytes = await req.body.readAll();
      return Response.ok(body: Body.fromString('${bytes.length}'));
    case '/unread':
      return Response.ok(body: Body.fromString('unread'));
    default:
      return Response.notFound();
  }
}

class _Counts {
  int requests = 0;
  int errors = 0;
}

/// Runs one keep-alive client through the routes until [stop] completes,
/// dropping a connection mid-response now and then.
Future<void> _client(
  int port,
  int seed,
  String mix,
  Future<void> stop,
  _Counts counts,
) async {
  final random = Random(seed);
  final client = HttpClient();
  var running = true;
  unawaited(stop.then((_) => running = false));
  const all = [
    'small',
    'small',
    'small',
    'big',
    'chunked',
    'echo',
    'unread',
    'drop',
  ];
  while (running) {
    try {
      switch (mix == 'all' ? all[random.nextInt(all.length)] : mix) {
        case 'small':
          await _get(client, port, '/small');
        case 'big':
          await _get(client, port, '/big');
        case 'chunked':
          await _get(client, port, '/chunked');
        case 'echo':
          await _post(client, port, '/echo', random.nextInt(4 * _inlineLimit));
        case 'unread':
          await _post(client, port, '/unread', 2 * _inlineLimit);
        case 'drop':
          await _dropMidResponse(port);
      }
      counts.requests++;
    } catch (_) {
      counts.errors++;
    }
  }
  client.close(force: true);
}

Future<void> _get(HttpClient client, int port, String path) async {
  final request = await client.get('127.0.0.1', port, path);
  final response = await request.close();
  await response.drain<void>();
}

Future<void> _post(HttpClient client, int port, String path, int length) async {
  final request = await client.post('127.0.0.1', port, path);
  request.contentLength = length;
  request.add(Uint8List(length));
  final response = await request.close();
  await response.drain<void>();
}

Future<void> _dropMidResponse(int port) async {
  final socket = await Socket.connect('127.0.0.1', port);
  socket.write('GET /big HTTP/1.1\r\nHost: x\r\n\r\n');
  await socket.flush();
  await socket.first;
  socket.destroy();
}

/// The physical footprint on macOS, or a dash elsewhere.
String _footprintMb() {
  if (!Platform.isMacOS) return '-';
  final vmmap = Process.runSync('vmmap', ['--summary', '$pid']);
  final line = (vmmap.stdout as String)
      .split('\n')
      .firstWhere((l) => l.startsWith('Physical footprint:'), orElse: () => '');
  final value = line.split(':').last.trim();
  if (value.endsWith('M')) return value.substring(0, value.length - 1);
  if (value.endsWith('G')) {
    return (double.parse(value.substring(0, value.length - 1)) * 1024)
        .round()
        .toString();
  }
  return value;
}

int _openFds() {
  if (Platform.isLinux) return Directory('/proc/self/fd').listSync().length;
  // Listing /dev/fd on macOS stats each entry and trips over fds that
  // close meanwhile. lsof is slow, and once per sample is fine.
  final lsof = Process.runSync('lsof', ['-p', '$pid']);
  return (lsof.stdout as String).split('\n').length - 2;
}

int _intArg(List<String> args, String name, int fallback) =>
    int.parse(_stringArg(args, name, '$fallback'));

String _stringArg(List<String> args, String name, String fallback) {
  for (final arg in args) {
    if (arg.startsWith('--$name=')) return arg.substring(name.length + 3);
  }
  return fallback;
}
