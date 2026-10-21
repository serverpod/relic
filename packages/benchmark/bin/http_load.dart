// HTTP load through a RelicApp on each adapter, driven by oha from its own
// process. For every target and workload, a closed-loop run finds the
// saturation rate, then open-loop runs at fractions of it report the
// latency percentiles. Needs `oha` on the PATH.
//
//   dart run bin/http_load.dart --targets=io,native,native4,shelf \
//       --workloads=plaintext,json,headers,browser,alloc,mixed \
//       --connections=64 --seconds=5 --loads=0.5,0.75,1.0 --out=load.md
//
// A `shelf` target is a shelf server on dart:io with the same routes.
// A target that is a URL is a server started elsewhere (Bun, for one)
// that serves the same paths, and `name=URL` labels it in the table:
//   --targets=io,bun=http://127.0.0.1:3000
// `baselines/` has the same routes on bare hyper and on bare Deno.serve.

import 'dart:convert';
import 'dart:io';

import 'package:benchmark/src/load_app.dart';
import 'package:benchmark/src/oha.dart';
import 'package:benchmark/src/options.dart';
import 'package:benchmark/src/serve.dart';
import 'package:benchmark/src/shelf_server.dart';
import 'package:config/config.dart';

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
  Workload('browser', '/browser', [
    ..._browserHeaders,
    'If-None-Match: "33a64df551425fcc55e4d42a148795d9f25f89d4"',
  ]),
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

enum LoadOption<V> implements OptionDefinition<V> {
  targets(
    MultiStringOption(
      argName: 'targets',
      helpText:
          'io, native or shelf, each with an optional isolate count, or '
          'name=URL for a server started elsewhere',
      defaultsTo: ['io', 'native', 'native4'],
    ),
  ),

  workloads(
    MultiStringOption(
      argName: 'workloads',
      helpText: 'The workloads to run, in order',
      defaultsTo: ['plaintext', 'json', 'headers', 'browser', 'alloc', 'mixed'],
      customValidator: _knownWorkloads,
    ),
  ),

  connections(
    IntOption(
      argName: 'connections',
      helpText: 'Connections oha keeps open',
      defaultsTo: 64,
      min: 1,
    ),
  ),

  seconds(
    IntOption(
      argName: 'seconds',
      helpText: 'Seconds per run',
      defaultsTo: 5,
      min: 1,
    ),
  ),

  loads(
    MultiOption<double>(
      multiParser: MultiParser(_DoubleParser()),
      argName: 'loads',
      helpText: 'Fractions of the saturation rate to offer',
      defaultsTo: [0.5, 0.75, 1.0],
    ),
  ),

  out(
    StringOption(
      argName: 'out',
      helpText:
          'The file to write the table to. The measurements go beside it '
          'as JSON.',
    ),
  );

  const LoadOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

void _knownWorkloads(List<String> names) {
  for (final name in names) {
    if (!_workloads.any((w) => w.name == name)) {
      throw FormatException('Unknown workload: $name');
    }
  }
}

final class _DoubleParser extends ValueParser<double> {
  const _DoubleParser();

  @override
  double parse(String value) => double.parse(value);
}

Future<void> main(List<String> args) async {
  final config = resolveOptions(
    LoadOption.values,
    args,
    synopsis: 'usage: dart run bin/http_load.dart [options]',
  );
  final targets = config.value(LoadOption.targets);
  final connections = config.value(LoadOption.connections);
  final seconds = config.value(LoadOption.seconds);
  final loads = config.value(LoadOption.loads);
  final out = config.optionalValue(LoadOption.out);

  final workloads = [
    for (final name in config.value(LoadOption.workloads))
      _workloads.firstWhere((w) => w.name == name),
  ];
  final results = <Measurement>[];
  for (final spec in targets) {
    final (target, url) = _split(spec);
    final server = url == null ? await _start(target) : null;
    final base = url ?? 'http://127.0.0.1:${server!.port}';
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
              errors: run.failed,
              nonOk: run.nonOk,
            ),
          );
          stderr.writeln(
            '    ${(load * 100).round()}%: offered $offered, got '
            '${run.rps.round()} rps, p50 ${run.p50.toStringAsFixed(2)} ms, '
            'p99 ${run.p99.toStringAsFixed(2)} ms, '
            'p99.9 ${run.p999.toStringAsFixed(2)} ms'
            '${run.failed > 0 ? ', ${run.failed} errors' : ''}',
          );
        }
      }
    } finally {
      await server?.close();
    }
  }

  final table = _markdown(results, connections, seconds);
  stdout.write(table);
  if (out != null) {
    File(out).writeAsStringSync(table);
    File('${out.replaceAll(RegExp(r'\.md$'), '')}.json').writeAsStringSync(
      const JsonEncoder.withIndent(
        '  ',
      ).convert(results.map((m) => m.toJson()).toList()),
    );
  }
}

/// The target name and URL in [spec].
///
/// `io`, `native4` or `shelf` starts a server here. `http://host:port` is
/// a server started elsewhere, and `name=http://host:port` labels it.
(String, String?) _split(String spec) {
  final at = spec.indexOf('=');
  if (at > 0) return (spec.substring(0, at), spec.substring(at + 1));
  if (spec.startsWith('http')) return (spec, spec);
  return (spec, null);
}

/// A server for [target]: `io`, `native` or `shelf`, or one of them
/// followed by an isolate count.
Future<Server> _start(String target) {
  final match = RegExp(r'^(io|native|shelf)(\d*)$').firstMatch(target);
  if (match == null) throw ArgumentError.value(target, 'target');
  final kind = match.group(1)!;
  final isolates = int.tryParse(match.group(2)!) ?? 1;
  // Port 0 with several dart:io isolates gives each its own port and
  // the server reports the first one, so the dart:io targets take a fixed
  // port.
  return startServer(
    kind,
    Served.app(loadApp(), shelfLoad),
    port: kind == 'native' ? 0 : 18080,
    isolates: isolates,
  );
}

/// One oha run of [workload] against [base].
///
/// A null [rate] is a closed loop at [connections] in flight, otherwise an
/// open loop at that many requests per second.
Future<OhaResult> _oha(
  String base,
  Workload workload,
  int connections,
  int seconds,
  int? rate,
) => runOha(
  '$base${workload.path}',
  connections: connections,
  seconds: seconds,
  rate: rate,
  headers: workload.headers,
);

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
