// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math';

import 'package:benchmark_harness/perf_benchmark_harness.dart';
import 'package:cli_tools/cli_tools.dart';
import 'package:relic/relic.dart';
import 'package:routingkit/routingkit.dart' as routingkit;
import 'package:spanner/spanner.dart' as spanner;

const int routeCount = 10000;

late final List<int> indexes;
late final List<String> staticRoutesToLookup;
late final List<String> dynamicRoutesToLookup;

void setupBenchmarkData() {
  print('Setting up benchmark data with $routeCount routes...');
  indexes = List.generate(routeCount, (final i) => i);
  final permutedIndexes = indexes.toList()
    ..shuffle(Random(123)); // Use fixed seed for reproducibility

  // Pre-generate lookup paths
  staticRoutesToLookup = permutedIndexes.map((final i) => '/path$i').toList();
  dynamicRoutesToLookup = permutedIndexes
      .map(
        (final i) =>
            // Fixed seed for reproducibility
            '/users/user_${Random(i).nextInt(1000)}'
            '/items/item_${Random(i + 1).nextInt(5000)}'
            '/profile$i',
      )
      .toList();
  print('Setup complete.');
}

class Emitter extends ScoreEmitterV2 {
  final IOSink _output;
  final bool _tee;

  Emitter(final File output, this._tee) : _output = output.openWrite();

  @override
  void emit(
    final String testName,
    final double value, {
    final String metric = 'RunTime',
    final String unit = 'us',
  }) {
    final csvLine = [testName, metric, value, unit].join(';');
    for (final s in [_output, if (_tee) stdout]) {
      s.writeln(csvLine);
    }
  }
}

late final ScoreEmitterV2 _emitter;

abstract class RouterBenchmark extends PerfBenchmarkBase {
  RouterBenchmark(final Iterable<String> grouping)
      : super(grouping.join(';'), emitter: _emitter);

  @override
  void exercise() => run();
}

// Benchmark for adding static routes
class StaticAddBenchmark extends RouterBenchmark {
  StaticAddBenchmark() : super(['Add', 'Static', 'x$routeCount', 'Router']);

  @override
  void run() {
    final router = Router<int>();
    for (final i in indexes) {
      router.get('/path$i', i);
    }
  }
}

// Benchmark for looking up static routes
class StaticLookupBenchmark extends RouterBenchmark {
  StaticLookupBenchmark()
      : super(['Lookup', 'Static', 'x$routeCount', 'Router']);

  late final Router<int> router;

  @override
  void setup() {
    router = Router<int>();
    for (final i in indexes) {
      router.get('/path$i', i);
    }
  }

  @override
  void run() {
    for (final route in staticRoutesToLookup) {
      // Access value to ensure lookup isn't optimized away
      router.lookup(Method.get, route)?.value;
    }
  }
}

// Benchmark for adding dynamic routes
class DynamicAddBenchmark extends RouterBenchmark {
  DynamicAddBenchmark() : super(['Add', 'Dynamic', 'x$routeCount', 'Router']);

  @override
  void run() {
    final router = Router<int>();
    for (final i in indexes) {
      router.get('/users/:id/items/:itemId/profile$i', i);
    }
  }
}

// Benchmark for looking up dynamic routes
class DynamicLookupBenchmark extends RouterBenchmark {
  DynamicLookupBenchmark()
      : super(['Lookup', 'Dynamic', 'x$routeCount', 'Router']);

  late final Router<int> router;

  @override
  void setup() {
    // Create and populate routers specifically for lookup benchmarks
    router = Router<int>();
    for (final i in indexes) {
      router.get('/users/:id/items/:itemId/profile$i', i);
    }
  }

  @override
  void run() {
    for (final route in dynamicRoutesToLookup) {
      // Access value to ensure lookup isn't optimized away
      router.lookup(Method.get, route)?.value;
    }
  }
}

class StaticAddRoutingkitBenchmark extends RouterBenchmark {
  StaticAddRoutingkitBenchmark()
      : super(['Add', 'Static', 'x$routeCount', 'Routingkit']);

  @override
  void run() {
    final router = routingkit.createRouter<int>();
    for (final i in indexes) {
      router.add('GET', '/path$i', i);
    }
  }
}

class StaticLookupRoutingkitBenchmark extends RouterBenchmark {
  StaticLookupRoutingkitBenchmark()
      : super(['Lookup', 'Static', 'x$routeCount', 'Routingkit']);

  late final routingkit.Router<int> router;

  @override
  void setup() {
    router = routingkit.createRouter<int>();
    for (final i in indexes) {
      router.add('GET', '/path$i', i);
    }
  }

  @override
  void run() {
    for (final route in staticRoutesToLookup) {
      // Access value to ensure lookup isn't optimized away
      router.find('GET', route)?.data;
    }
  }
}

class DynamicAddRoutingkitBenchmark extends RouterBenchmark {
  DynamicAddRoutingkitBenchmark()
      : super(['Add', 'Dynamic', 'x$routeCount', 'Routingkit']);

  @override
  void run() {
    final router = routingkit.createRouter<int>();
    for (final i in indexes) {
      router.add('GET', '/users/:id/items/:itemId/profile$i', i);
    }
  }
}

class DynamicLookupRoutingkitBenchmark extends RouterBenchmark {
  DynamicLookupRoutingkitBenchmark()
      : super(['Lookup', 'Dynamic', 'x$routeCount', 'Routingkit']);

  late final routingkit.Router<int> router;

  @override
  void setup() {
    // Create and populate routers specifically for lookup benchmarks
    router = routingkit.createRouter<int>();
    for (final i in indexes) {
      router.add('GET', '/users/:id/items/:itemId/profile$i', i);
    }
  }

  @override
  void run() {
    for (final route in dynamicRoutesToLookup) {
      // Access value to ensure lookup isn't optimized away
      router.find('GET', route)?.data;
    }
  }
}

class StaticAddSpannerBenchmark extends RouterBenchmark {
  StaticAddSpannerBenchmark()
      : super(['Add', 'Static', 'x$routeCount', 'Spanner']);

  @override
  void run() {
    final router = spanner.Spanner();
    for (final i in indexes) {
      router.addRoute(spanner.HTTPMethod.GET, '/path$i', i);
    }
  }
}

class StaticLookupSpannerBenchmark extends RouterBenchmark {
  StaticLookupSpannerBenchmark()
      : super(['Lookup', 'Static', 'x$routeCount', 'Spanner']);

  late final spanner.Spanner router;

  @override
  void setup() {
    router = spanner.Spanner();
    for (final i in indexes) {
      router.addRoute(spanner.HTTPMethod.GET, '/path$i', i);
    }
  }

  @override
  void run() {
    for (final route in staticRoutesToLookup) {
      // Access value to ensure lookup isn't optimized away
      router.lookup(spanner.HTTPMethod.GET, route)?.values;
    }
  }
}

class DynamicAddSpannerBenchmark extends RouterBenchmark {
  DynamicAddSpannerBenchmark()
      : super(['Add', 'Dynamic', 'x$routeCount', 'Spanner']);

  @override
  void run() {
    final router = spanner.Spanner();
    for (final i in indexes) {
      router.addRoute(
          spanner.HTTPMethod.GET, '/users/<id>/items/<itemId>/profile$i', i);
    }
  }
}

class DynamicLookupSpannerBenchmark extends RouterBenchmark {
  DynamicLookupSpannerBenchmark()
      : super(['Lookup', 'Dynamic', 'x$routeCount', 'Spanner']);

  late final spanner.Spanner router;

  @override
  void setup() {
    // Create and populate routers specifically for lookup benchmarks
    router = spanner.Spanner();
    for (final i in indexes) {
      router.addRoute(
          spanner.HTTPMethod.GET, '/users/<id>/items/<itemId>/profile$i', i);
    }
  }

  @override
  void run() {
    for (final route in dynamicRoutesToLookup) {
      // Access value to ensure lookup isn't optimized away
      router.lookup(spanner.HTTPMethod.GET, route)?.values;
    }
  }
}

enum Option<V> implements OptionDefinition<V> {
  file(FileOption(
    argName: 'output',
    argAbbrev: 'o',
    helpText: 'The file to write benchmark results to',
    fromDefault: _defaultFile,
    mode: PathExistMode.mustNotExist,
  )),

  pause(FlagOption(
    argName: 'pause-on-startup',
    argAbbrev: 'p',
    helpText: 'Pause on startup to allow devtools to attach',
    defaultsTo: false,
    hideNegatedUsage: true,
  )),

  tee(FlagOption(
    argName: 'tee',
    helpText: 'Mirror output to stdout',
    defaultsTo: true,
  ));

  const Option(this.option);

  @override
  final ConfigOptionBase<V> option;
}

File _defaultFile() => File('benchmark_results.csv');

class RunCommand extends BetterCommand<Option<dynamic>, void> {
  RunCommand({super.env}) : super(options: Option.values);

  @override
  final description = 'Run comparative router benchmarks';

  @override
  final name = 'run';

  @override
  FutureOr<void>? runWithConfig(
      final Configuration<Option<dynamic>> commandConfig) async {
    final file = commandConfig.value(Option.file);
    final pause = commandConfig.value(Option.pause);
    final tee = commandConfig.value(Option.tee);

    _emitter = Emitter(file, tee);

    if (pause) {
      final info = await Service.getInfo();
      if (info.serverUri != null) {
        print(info.serverUri);
      }
      print('Press <enter> when ready..');
      if (stdin.hasTerminal) {
        await stdin.first;
      }
    }
    await driver();
  }
}

enum ExtractHistoricOptions<V> implements OptionDefinition<V> {
  from(StringOption(argName: 'from', argAbbrev: 'f')),
  to(StringOption(argName: 'to', argAbbrev: 't'));

  const ExtractHistoricOptions(this.option);

  @override
  final ConfigOptionBase<V> option;
}

class ExtractHistoricDataCommand
    extends BetterCommand<ExtractHistoricOptions<dynamic>, void> {
  @override
  final description = 'Extract historic benchmark data';

  @override
  final name = 'extract';

  @override
  FutureOr<void>? runWithConfig(
      final Configuration<ExtractHistoricOptions<dynamic>> commandConfig) {
    throw UnimplementedError();
  }
}

Future<int> main(final List<String> args) async {
  // ignore: inference_failure_on_instance_creation
  final runner = BetterCommandRunner('benchmark', 'Relic Benchmark Tool')
    ..addCommands([
      RunCommand(),
      ExtractHistoricDataCommand(),
    ]);
  try {
    await runner.run(args);
  } on UsageException catch (_) {
    print(runner.usage);
    return 1;
  }
  return 0;
}

Future<void> driver() async {
  setupBenchmarkData();

  print('Starting benchmarks');

  for (final benchmark in [
    StaticAddRoutingkitBenchmark(),
    StaticAddSpannerBenchmark(),
    StaticAddBenchmark(),
    StaticLookupRoutingkitBenchmark(),
    StaticLookupSpannerBenchmark(),
    StaticLookupBenchmark(),
    DynamicAddRoutingkitBenchmark(),
    DynamicAddSpannerBenchmark(),
    DynamicAddBenchmark(),
    DynamicLookupRoutingkitBenchmark(),
    DynamicLookupSpannerBenchmark(),
    DynamicLookupBenchmark(),
  ]) {
    benchmark.report();
    if (Platform.isLinux) await benchmark.reportPerf();
  }

  print('Done');
}
