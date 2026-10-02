// HTTP load through a RelicApp on each adapter, driven by oha from its own
// process. For every target and workload, a closed-loop run finds the
// saturation rate, then open-loop runs at fractions of it report the
// latency percentiles. Needs `oha` on the PATH.
//
//   dart run bin/http_load.dart --targets=io,native,native4,shelf \
//       --workloads=plaintext,json,headers,alloc,mixed \
//       --connections=64 --seconds=5 --loads=0.5,0.75,1.0 --out=load.md
//
// A `shelf` target is a shelf server on dart:io with the same routes.
// A target that is a URL is a server started elsewhere (Bun, for one)
// that serves the same paths: --targets=io,http://127.0.0.1:3000

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:benchmark/src/load_app.dart';
import 'package:benchmark/src/shelf_server.dart';
import 'package:relic/relic.dart';
import 'package:relic_native/relic_native.dart';

/// What a browser sends, Cookie included, for the headers workload.
const _browserHeaders = [
  'Host: localhost',
  'Connection: keep-alive',
  'Cache-Control: max-age=0',
  'sec-ch-ua: "Chromium";v="130", "Google Chrome";v="130"',
  'sec-ch-ua-mobile: ?0',
  'sec-ch-ua-platform: "macOS"',
  'Upgrade-Insecure-Requests: 1',
  'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
  'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,'
      'image/avif,image/webp,image/apng,*/*;q=0.8',
  'Sec-Fetch-Site: same-origin',
  'Sec-Fetch-Mode: navigate',
  'Sec-Fetch-User: ?1',
  'Sec-Fetch-Dest: document',
  'Referer: http://localhost/',
  'Accept-Encoding: gzip, deflate, br, zstd',
  'Accept-Language: en-US,en;q=0.9,da;q=0.8',
  'Cookie: session=0123456789abcdef0123456789abcdef0123456789abcdef; '
      '_ga=GA1.1.1234567890.1700000000; _gid=GA1.1.0987654321.1700000000; '
      'theme=dark; consent=analytics,marketing; '
      'tracker=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
];

final class Workload {
  final String name;
  final String path;
  final List<String> headers;
  const Workload(this.name, this.path, [this.headers = const []]);
}

const _workloads = [
  Workload('plaintext', '/plaintext'),
  Workload('json', '/json'),
  Workload('headers', '/headers', _browserHeaders),
  Workload('alloc', '/alloc'),
  Workload('mixed', '/mixed'),
];

final class Measurement {
  final String target;
  final String workload;
  final double load;
  final int offeredRps;
  final double rps;
  final double p50;
  final double p99;
  final double p999;
  final int errors;
  final int nonOk;

  Measurement({
    required this.target,
    required this.workload,
    required this.load,
    required this.offeredRps,
    required this.rps,
    required this.p50,
    required this.p99,
    required this.p999,
    required this.errors,
    required this.nonOk,
  });

  Map<String, Object> toJson() => {
    'target': target,
    'workload': workload,
    'load': load,
    'offeredRps': offeredRps,
    'rps': rps,
    'p50Ms': p50,
    'p99Ms': p99,
    'p999Ms': p999,
    'errors': errors,
    'nonOk': nonOk,
  };
}

Future<void> main(List<String> args) async {
  final targets = _arg(args, 'targets', 'io,native,native4').split(',');
  final workloadNames = _arg(
    args,
    'workloads',
    'plaintext,json,headers,alloc,mixed',
  ).split(',');
  final connections = int.parse(_arg(args, 'connections', '64'));
  final seconds = int.parse(_arg(args, 'seconds', '5'));
  final loads = _arg(
    args,
    'loads',
    '0.5,0.75,1.0',
  ).split(',').map(double.parse);
  final out = _arg(args, 'out', '');

  final workloads = [
    for (final name in workloadNames)
      _workloads.firstWhere((w) => w.name == name),
  ];
  final results = <Measurement>[];
  for (final target in targets) {
    final server = target.startsWith('http') ? null : await _start(target);
    final base = server == null ? target : 'http://127.0.0.1:${server.port}';
    stderr.writeln('$target at $base');
    try {
      // One warm-up so JIT and caches are settled before the first number.
      await _oha(base, workloads.first, connections, 2, null);
      for (final workload in workloads) {
        final saturation = await _oha(
          base,
          workload,
          connections,
          seconds,
          null,
        );
        final sat = saturation.rps.round();
        stderr.writeln('  ${workload.name}: saturates at $sat rps');
        for (final load in loads) {
          final offered = (sat * load).round();
          final run = await _oha(base, workload, connections, seconds, offered);
          results.add(
            Measurement(
              target: target,
              workload: workload.name,
              load: load,
              offeredRps: offered,
              rps: run.rps,
              p50: run.p50,
              p99: run.p99,
              p999: run.p999,
              errors: run.errors,
              nonOk: run.nonOk,
            ),
          );
          stderr.writeln(
            '    ${(load * 100).round()}%: offered $offered, got '
            '${run.rps.round()} rps, p50 ${run.p50.toStringAsFixed(2)} ms, '
            'p99 ${run.p99.toStringAsFixed(2)} ms, '
            'p99.9 ${run.p999.toStringAsFixed(2)} ms'
            '${run.errors > 0 ? ', ${run.errors} errors' : ''}',
          );
        }
      }
    } finally {
      await server?.close();
    }
  }

  final table = _markdown(results, connections, seconds);
  stdout.write(table);
  if (out.isNotEmpty) {
    File(out).writeAsStringSync(table);
    File('${out.replaceAll(RegExp(r'\.md$'), '')}.json').writeAsStringSync(
      const JsonEncoder.withIndent(
        '  ',
      ).convert(results.map((m) => m.toJson()).toList()),
    );
  }
}

/// A started server: where it listens and how to stop it.
typedef _Server = ({int port, Future<void> Function() close});

/// A server for [target]: `io`, `native` or `shelf`, or one of them
/// followed by an isolate count.
Future<_Server> _start(String target) async {
  final match = RegExp(r'^(io|native|shelf)(\d*)$').firstMatch(target);
  if (match == null) throw ArgumentError.value(target, 'target');
  final isolates = int.tryParse(match.group(2)!) ?? 1;
  // Port 0 with several dart:io isolates gives each its own port and
  // the server reports the first one, so the dart:io targets take a fixed
  // port.
  if (match.group(1) == 'shelf') {
    final server = await ShelfServer.start(
      shelfLoad,
      port: 18080,
      isolates: isolates,
    );
    return (port: server.port, close: () => server.close(force: true));
  }
  final app = loadApp();
  final server = match.group(1) == 'io'
      ? await app.serve(port: 18080, noOfIsolates: isolates)
      : await app.serveNative(port: 0, noOfIsolates: isolates);
  return (port: server.port, close: () => server.close(force: true));
}

final class _OhaResult {
  final double rps;
  final double p50;
  final double p99;
  final double p999;
  final int errors;
  final int nonOk;
  _OhaResult(this.rps, this.p50, this.p99, this.p999, this.errors, this.nonOk);
}

/// One oha run. [rate] null is closed loop at [connections] in flight,
/// otherwise open loop at that many requests per second.
///
/// No `--latency-correction`. oha 1.16.0 charges pauses of about 300 ms in
/// its own scheduler to every request due during them, on any server and
/// at any rate, and a probe client beside it sees none of it. A server
/// that falls behind the offered rate shows in `rps` against `offeredRps`.
Future<_OhaResult> _oha(
  String base,
  Workload workload,
  int connections,
  int seconds,
  int? rate,
) async {
  final result = await Process.run('oha', [
    '--no-tui',
    '--output-format',
    'json',
    '-c',
    '$connections',
    '-z',
    '${seconds}s',
    if (rate != null) ...['-q', '$rate'],
    for (final header in workload.headers) ...['-H', header],
    '$base${workload.path}',
  ]);
  if (result.exitCode != 0) {
    throw ProcessException('oha', const [], result.stderr as String);
  }
  final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  final summary = json['summary'] as Map<String, dynamic>;
  final percentiles = json['latencyPercentiles'] as Map<String, dynamic>;
  final statuses = json['statusCodeDistribution'] as Map<String, dynamic>;
  final errors = json['errorDistribution'] as Map<String, dynamic>;
  double ms(String key) => (percentiles[key] as num) * 1000;
  var nonOk = 0;
  for (final MapEntry(:key, :value) in statuses.entries) {
    if (key != '200') nonOk += value as int;
  }
  var failed = 0;
  for (final MapEntry(:key, :value) in errors.entries) {
    // The deadline cuts off whatever is in flight. That is not a failure.
    if (!key.contains('deadline')) failed += value as int;
  }
  return _OhaResult(
    (summary['requestsPerSec'] as num).toDouble(),
    ms('p50'),
    ms('p99'),
    ms('p99.9'),
    failed,
    nonOk,
  );
}

String _markdown(List<Measurement> results, int connections, int seconds) {
  final buffer = StringBuffer()
    ..writeln('$connections connections, ${seconds}s per run, latency in ms.')
    ..writeln()
    ..writeln(
      '| target | workload | load | offered rps | rps | p50 | p99 | p99.9 '
      '| errors |',
    )
    ..writeln('|---|---|---|---|---|---|---|---|---|');
  for (final m in results) {
    final errors = m.errors > 0 || m.nonOk > 0
        ? '${m.errors} failed, ${m.nonOk} non-200'
        : '-';
    buffer.writeln(
      '| ${m.target} | ${m.workload} | ${(m.load * 100).round()}% | '
      '${m.offeredRps} | ${m.rps.round()} | ${m.p50.toStringAsFixed(2)} | '
      '${m.p99.toStringAsFixed(2)} | ${m.p999.toStringAsFixed(2)} | '
      '$errors |',
    );
  }
  return buffer.toString();
}

String _arg(List<String> args, String name, String fallback) {
  for (final arg in args) {
    if (arg.startsWith('--$name=')) return arg.substring(name.length + 3);
  }
  return fallback;
}
