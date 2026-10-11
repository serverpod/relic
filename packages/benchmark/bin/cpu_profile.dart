// Pulls CPU samples from a running Dart VM and prints where the isolate's
// time goes: by VM tag, by function exclusive, and by function inclusive.
// Start the server with a service port, put load on it, then run this
// against the service. The tool turns the profiler on through the service
// at --period microseconds, since `dart run` does not forward --profiler.
//
//   dart run --enable-vm-service=8181 --disable-service-auth-codes \
//       bin/load_serve.dart native 1
//   dart run bin/cpu_profile.dart ws://127.0.0.1:8181/ws --wait=8 --window=6
//
// The tool clears the samples at the start, waits --wait seconds, then
// reads the last --window seconds of samples.
import 'dart:io';

import 'package:benchmark/src/options.dart';
import 'package:config/config.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

enum ProfileOption<V> implements OptionDefinition<V> {
  service(
    StringOption(
      argPos: 0,
      helpText: 'The VM service WebSocket URI, ws://host:port/ws',
      mandatory: true,
    ),
  ),

  wait(
    IntOption(
      argName: 'wait',
      helpText: 'Seconds to wait before the samples are read',
      defaultsTo: 8,
      min: 0,
    ),
  ),

  window(
    IntOption(
      argName: 'window',
      helpText: 'The last seconds of samples to report',
      defaultsTo: 6,
      min: 1,
    ),
  ),

  top(
    IntOption(
      argName: 'top',
      helpText: 'Rows per table',
      defaultsTo: 40,
      min: 1,
    ),
  ),

  period(
    IntOption(
      argName: 'period',
      helpText: 'The profiler sample period in microseconds',
      defaultsTo: 200,
      min: 1,
    ),
  );

  const ProfileOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

Future<void> main(final List<String> args) async {
  final config = resolveOptions(
    ProfileOption.values,
    args,
    synopsis: 'usage: dart run bin/cpu_profile.dart <ws-uri> [options]',
  );
  final wait = config.value(ProfileOption.wait);
  final window = config.value(ProfileOption.window);
  final top = config.value(ProfileOption.top);
  final period = config.value(ProfileOption.period);

  final service = await vmServiceConnectUri(
    config.value(ProfileOption.service),
  );
  try {
    // The server may run in a spawned isolate while main sits idle, so
    // the tool samples every isolate and reports the busiest one.
    await service.setFlag('profile_period', '$period');
    await service.setFlag('profiler', 'true');
    final vm = await service.getVM();
    final isolates = vm.isolates!
        .where((final i) => !i.name!.contains('vm-service'))
        .toList();
    for (final isolate in isolates) {
      await service.clearCpuSamples(isolate.id!);
    }
    await Future<void>.delayed(Duration(seconds: wait));
    CpuSamples? busiest;
    var busiestCount = -1;
    for (final isolate in isolates) {
      final samples = await service.getCpuSamples(isolate.id!, 0, 1 << 62);
      final count = samples.samples!.length;
      stdout.writeln('isolate ${isolate.name}: $count samples');
      if (count > busiestCount) {
        busiest = samples;
        busiestCount = count;
      }
    }
    _report(busiest!, window, top);
  } finally {
    await service.dispose();
  }
}

void _report(final CpuSamples samples, final int window, final int top) {
  final all = samples.samples!;
  if (all.isEmpty) {
    stdout.writeln('no samples');
    return;
  }
  final last = all.last.timestamp!;
  final kept = all.where((final s) => s.timestamp! > last - window * 1000000);
  final functions = samples.functions!;
  final exclusive = <int, int>{};
  final inclusive = <int, int>{};
  final tags = <String, int>{};
  var count = 0;
  for (final sample in kept) {
    count++;
    tags.update(sample.vmTag ?? '?', (final n) => n + 1, ifAbsent: () => 1);
    final stack = sample.stack!;
    if (stack.isEmpty) continue;
    exclusive.update(stack[0], (final n) => n + 1, ifAbsent: () => 1);
    for (final f in stack.toSet()) {
      inclusive.update(f, (final n) => n + 1, ifAbsent: () => 1);
    }
  }
  String name(final int i) {
    final f = functions[i];
    final fn = f.function;
    final owner = fn is FuncRef && fn.owner is ClassRef
        ? '${(fn.owner as ClassRef).name}.'
        : '';
    final url = (f.resolvedUrl ?? '')
        .replaceFirst(RegExp(r'^.*/lib/'), '')
        .replaceFirst(RegExp(r'^package:'), '');
    return '$owner${fn is FuncRef ? fn.name : fn.toString()} [$url]';
  }

  String pct(final int n) =>
      '${(n * 100 / count).toStringAsFixed(1).padLeft(5)}%';
  stdout.writeln(
    'samples in window: $count over ${window}s '
    '(period ${samples.samplePeriod} us)',
  );
  stdout.writeln('\nby vm tag:');
  for (final e in _sorted(tags).take(top)) {
    stdout.writeln('  ${pct(e.value)}  ${e.key}');
  }
  stdout.writeln('\ntop exclusive:');
  for (final e in _sorted(exclusive).take(top)) {
    stdout.writeln('  ${pct(e.value)}  ${name(e.key)}');
  }
  stdout.writeln('\ntop inclusive:');
  for (final e in _sorted(inclusive).take(top)) {
    stdout.writeln('  ${pct(e.value)}  ${name(e.key)}');
  }
}

List<MapEntry<K, int>> _sorted<K>(final Map<K, int> counts) =>
    counts.entries.toList()..sort((final a, final b) => b.value - a.value);
