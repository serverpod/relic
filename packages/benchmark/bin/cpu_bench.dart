// Starts a server command, drives it with oha, and reports the server's
// CPU time per request as user and system time, read from the kernel's
// per-process counters over the load window. Needs `oha` on the PATH.
//
//   dart run bin/cpu_bench.dart -- dart run bin/load_serve.dart native 1
//   dart run bin/cpu_bench.dart --connections=64 --seconds=10 -- ./hello 4
//
// The command must listen on --url, http://127.0.0.1:18098/plaintext by
// default. The tool measures its process and the children it forks
// together, which covers a Node cluster or a Go server as well as a Relic
// one.
import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:benchmark/src/oha.dart';
import 'package:benchmark/src/options.dart';
import 'package:config/config.dart';
import 'package:ffi/ffi.dart';

enum CpuBenchOption<V> implements OptionDefinition<V> {
  connections(
    IntOption(
      argName: 'connections',
      helpText: 'Connections oha keeps open',
      defaultsTo: 128,
      min: 1,
    ),
  ),

  seconds(
    IntOption(
      argName: 'seconds',
      helpText: 'Seconds of load the CPU time is read over',
      defaultsTo: 6,
      min: 1,
    ),
  ),

  url(
    StringOption(
      argName: 'url',
      helpText: 'Where the server command listens',
      defaultsTo: 'http://127.0.0.1:18098/plaintext',
    ),
  ),

  label(
    StringOption(
      argName: 'label',
      helpText: 'The first column of the row, the command by default',
    ),
  );

  const CpuBenchOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

const _synopsis =
    'usage: dart run bin/cpu_bench.dart [options] -- <server command>';

Future<void> main(final List<String> args) async {
  final split = args.indexOf('--');
  if (split < 0 || split == args.length - 1) {
    usageError(
      'The server command after -- is missing.',
      CpuBenchOption.values,
      synopsis: _synopsis,
    );
  }
  final config = resolveOptions(
    CpuBenchOption.values,
    args.sublist(0, split),
    synopsis: _synopsis,
  );
  final command = args.sublist(split + 1);
  final connections = config.value(CpuBenchOption.connections);
  final seconds = config.value(CpuBenchOption.seconds);
  final url = config.value(CpuBenchOption.url);
  final label = config.optionalValue(CpuBenchOption.label) ?? command.join(' ');

  if (await _answers(url)) {
    stderr.writeln('Something already serves $url. Stop it first.');
    exitCode = 1;
    return;
  }
  final server = await Process.start(command.first, command.sublist(1));
  unawaited(server.stdout.drain<void>());
  unawaited(server.stderr.drain<void>());
  var pids = [server.pid];
  try {
    await _waitForServer(url);
    await Future<void>.delayed(const Duration(seconds: 1));
    pids = await _processTree(server.pid);
    await runOha(url, connections: connections, seconds: 2);
    final before = await _cpuTime(pids);
    final result = await runOha(
      url,
      connections: connections,
      seconds: seconds,
    );
    final after = await _cpuTime(pids);
    final user = (after.user - before.user) / 1e9;
    final system = (after.system - before.system) / 1e9;
    final count = result.responses;
    stdout.writeln(
      '| $label | ${result.rps.round()} | ${result.p50.toStringAsFixed(2)} | '
      '${result.p99.toStringAsFixed(2)} | '
      '${((user + system) / seconds * 100).round()}% | '
      '${(user / count * 1e6).toStringAsFixed(1)} | '
      '${(system / count * 1e6).toStringAsFixed(1)} | '
      '${((user + system) / count * 1e6).toStringAsFixed(1)} |',
    );
  } finally {
    // A shim that exits after spawning the server leaves the server holding
    // the port and this process's pipes, so the whole tree goes.
    for (final pid in pids) {
      Process.killPid(pid);
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    for (final pid in pids) {
      Process.killPid(pid, ProcessSignal.sigkill);
    }
  }
}

/// The server's pid and every descendant.
///
/// A `dart` shim or a cluster primary has the process that serves one or
/// more forks below it.
Future<List<int>> _processTree(final int pid) async {
  final tree = [pid];
  for (var i = 0; i < tree.length; i++) {
    final children = await Process.run('pgrep', ['-P', '${tree[i]}']);
    for (final line in (children.stdout as String).split('\n')) {
      if (line.trim().isNotEmpty) tree.add(int.parse(line.trim()));
    }
  }
  return tree;
}

Future<void> _waitForServer(final String url) async {
  final waited = Stopwatch()..start();
  while (waited.elapsed < const Duration(seconds: 60)) {
    if (await _answers(url)) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('The server did not answer at $url');
}

/// Whether a GET of [url] gets a response.
///
/// Refused, or closed while a server is still starting, is a no. So is no
/// answer within two seconds, which is what a plain server gives an https
/// URL. A server's certificate goes unchecked, as oha leaves it.
Future<bool> _answers(final String url) async {
  final client = HttpClient()..badCertificateCallback = (_, _, _) => true;
  try {
    final response = await client
        .getUrl(Uri.parse(url))
        .then((final r) => r.close())
        .timeout(const Duration(seconds: 2));
    await response.drain<void>();
    return true;
  } on IOException {
    return false;
  } on TimeoutException {
    return false;
  } finally {
    client.close(force: true);
  }
}

/// User and system CPU time in nanoseconds, summed over [pids].
Future<({int user, int system})> _cpuTime(final List<int> pids) async {
  var user = 0;
  var system = 0;
  for (final pid in pids) {
    final t = Platform.isMacOS ? _rusageMacOS(pid) : await _statLinux(pid);
    user += t.user;
    system += t.system;
  }
  return (user: user, system: system);
}

typedef _ProcPidRusageC = Int32 Function(Int32, Int32, Pointer<Uint8>);
typedef _ProcPidRusage = int Function(int, int, Pointer<Uint8>);

/// The user and system times of [pid] from `proc_pid_rusage` with
/// `RUSAGE_INFO_V0`.
///
/// The struct is a 16 byte uuid, then the user and system times in Mach
/// absolute time units, nanoseconds on Intel and scaled on Apple silicon.
({int user, int system}) _rusageMacOS(final int pid) {
  final rusage = DynamicLibrary.process()
      .lookupFunction<_ProcPidRusageC, _ProcPidRusage>('proc_pid_rusage');
  final buffer = calloc<Uint8>(256);
  try {
    if (rusage(pid, 0, buffer) != 0) {
      // A shim in the tree that has exited since the tree was taken.
      stderr.writeln('proc_pid_rusage failed for pid $pid, counted as 0');
      return (user: 0, system: 0);
    }
    final words = buffer.cast<Uint64>();
    final scale = _machTimebase();
    return (
      user: (words[2] * scale).round(),
      system: (words[3] * scale).round(),
    );
  } finally {
    calloc.free(buffer);
  }
}

typedef _TimebaseC = Int32 Function(Pointer<Uint32>);
typedef _Timebase = int Function(Pointer<Uint32>);

/// Nanoseconds per Mach absolute time unit.
double _machTimebase() {
  final info = DynamicLibrary.process().lookupFunction<_TimebaseC, _Timebase>(
    'mach_timebase_info',
  );
  final buffer = calloc<Uint32>(2);
  try {
    info(buffer);
    return buffer[0] / buffer[1];
  } finally {
    calloc.free(buffer);
  }
}

/// The user and system times of [pid], fields 14 and 15 of
/// `/proc/<pid>/stat`, converted from clock ticks to nanoseconds.
Future<({int user, int system})> _statLinux(final int pid) async {
  final stat = await File('/proc/$pid/stat').readAsString();
  // The command name is in parentheses and may hold spaces.
  final fields = stat.substring(stat.lastIndexOf(')') + 2).split(' ');
  final nsPerTick = 1e9 ~/ _clockTicks();
  return (
    user: int.parse(fields[11]) * nsPerTick,
    system: int.parse(fields[12]) * nsPerTick,
  );
}

typedef _SysconfC = Int64 Function(Int32);
typedef _Sysconf = int Function(int);

int _clockTicks() {
  const scClkTck = 2;
  return DynamicLibrary.process().lookupFunction<_SysconfC, _Sysconf>(
    'sysconf',
  )(scClkTck);
}
