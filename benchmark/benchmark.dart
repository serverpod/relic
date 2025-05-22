import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math';

import 'package:benchmark_harness/perf_benchmark_harness.dart';
import 'package:cli_tools/cli_tools.dart';
import 'package:relic/relic.dart';
import 'package:routingkit/routingkit.dart' as routingkit;
import 'package:spanner/spanner.dart' as spanner;
import 'package:path/path.dart' as p;

late final List<int> indexes;
late final List<String> staticRoutesToLookup;
late final List<String> dynamicRoutesToLookup;

void setupBenchmarkData(int routeCount) {
  logger.info('Setting up benchmark data with $routeCount routes...');
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
  logger.info('Setup complete.');
}

int get routeCount => indexes.length;

class Emitter extends ScoreEmitterV2 {
  final IOSink _output;

  Emitter(final File output) : _output = output.openWrite();

  @override
  void emit(
    final String testName,
    final double value, {
    final String metric = 'RunTime',
    final String unit = 'us',
  }) {
    final csvLine = [testName, metric, value, unit].join(';');
    _output.writeln(csvLine);
    logger.debug(csvLine);
  }
}

abstract class RouterBenchmark extends PerfBenchmarkBase {
  RouterBenchmark(final Iterable<String> grouping, Emitter emitter)
      : super(grouping.join(';'), emitter: emitter);

  @override
  void exercise() => run();
}

// Benchmark for adding static routes
class StaticAddBenchmark extends RouterBenchmark {
  StaticAddBenchmark(Emitter emitter)
      : super(['Add', 'Static', 'x$routeCount', 'Router'], emitter);

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
  StaticLookupBenchmark(Emitter emitter)
      : super(['Lookup', 'Static', 'x$routeCount', 'Router'], emitter);

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
  DynamicAddBenchmark(Emitter emitter)
      : super(['Add', 'Dynamic', 'x$routeCount', 'Router'], emitter);

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
  DynamicLookupBenchmark(Emitter emitter)
      : super(['Lookup', 'Dynamic', 'x$routeCount', 'Router'], emitter);

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
  StaticAddRoutingkitBenchmark(Emitter emitter)
      : super(['Add', 'Static', 'x$routeCount', 'Routingkit'], emitter);

  @override
  void run() {
    final router = routingkit.createRouter<int>();
    for (final i in indexes) {
      router.add('GET', '/path$i', i);
    }
  }
}

class StaticLookupRoutingkitBenchmark extends RouterBenchmark {
  StaticLookupRoutingkitBenchmark(Emitter emitter)
      : super(['Lookup', 'Static', 'x$routeCount', 'Routingkit'], emitter);

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
  DynamicAddRoutingkitBenchmark(Emitter emitter)
      : super(['Add', 'Dynamic', 'x$routeCount', 'Routingkit'], emitter);

  @override
  void run() {
    final router = routingkit.createRouter<int>();
    for (final i in indexes) {
      router.add('GET', '/users/:id/items/:itemId/profile$i', i);
    }
  }
}

class DynamicLookupRoutingkitBenchmark extends RouterBenchmark {
  DynamicLookupRoutingkitBenchmark(Emitter emitter)
      : super(['Lookup', 'Dynamic', 'x$routeCount', 'Routingkit'], emitter);

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
  StaticAddSpannerBenchmark(Emitter emitter)
      : super(['Add', 'Static', 'x$routeCount', 'Spanner'], emitter);

  @override
  void run() {
    final router = spanner.Spanner();
    for (final i in indexes) {
      router.addRoute(spanner.HTTPMethod.GET, '/path$i', i);
    }
  }
}

class StaticLookupSpannerBenchmark extends RouterBenchmark {
  StaticLookupSpannerBenchmark(Emitter emitter)
      : super(['Lookup', 'Static', 'x$routeCount', 'Spanner'], emitter);

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
  DynamicAddSpannerBenchmark(Emitter emitter)
      : super(['Add', 'Dynamic', 'x$routeCount', 'Spanner'], emitter);

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
  DynamicLookupSpannerBenchmark(Emitter emitter)
      : super(['Lookup', 'Dynamic', 'x$routeCount', 'Spanner'], emitter);

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

  iterations(IntOption(
    argName: 'iterations',
    argAbbrev: 'i',
    helpText: 'Something to do with scale',
    defaultsTo: 1000,
  )),

  storeInNotes(FlagOption(
    argName: 'store-in-git-notes',
    argAbbrev: 's',
    helpText: 'Store benchmark result with git notes',
    defaultsTo: false,
  )),

  pause(FlagOption(
    argName: 'pause-on-startup',
    argAbbrev: 'p',
    helpText: 'Pause on startup to allow devtools to attach',
    defaultsTo: false,
    hideNegatedUsage: true,
  ));

  const Option(this.option);

  @override
  final ConfigOptionBase<V> option;
}

File _defaultFile() {
  final tmpDir = Directory.systemTemp.createTempSync();
  return File(p.join(tmpDir.path, 'benchmark_results.csv'));
}

class RunCommand extends BetterCommand<Option<dynamic>, void> {
  RunCommand({super.env}) : super(options: Option.values);

  @override
  final description = 'Run comparative router benchmarks';

  @override
  final name = 'run';

  @override
  FutureOr<void>? runWithConfig(
    final Configuration<Option<dynamic>> commandConfig,
  ) async {
    final file = commandConfig.value(Option.file);
    final pause = commandConfig.value(Option.pause);
    final iterations = commandConfig.value(Option.iterations);

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

    setupBenchmarkData(iterations);

    final emitter = Emitter(file);
    logger.info('Starting benchmarks');
    await driver(emitter);
    logger.info('Done');
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
    final Configuration<ExtractHistoricOptions<dynamic>> commandConfig,
  ) async {}
}

final logger = StdOutLogger(LogLevel.info);

void setLogLevel({
  required CommandRunnerLogLevel parsedLogLevel,
  String? commandName,
}) {
  logger.logLevel = switch (parsedLogLevel) {
    CommandRunnerLogLevel.quiet => LogLevel.error,
    CommandRunnerLogLevel.verbose => LogLevel.debug,
    CommandRunnerLogLevel.normal => LogLevel.info,
  };
}

Future<int> main(final List<String> args) async {
  // ignore: inference_failure_on_instance_creation
  final runner = BetterCommandRunner(
    'benchmark',
    'Relic Benchmark Tool',
    setLogLevel: setLogLevel,
  )..addCommands([
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

Future<bool> driver(Emitter emitter) async {
  for (final benchmark in [
    StaticAddRoutingkitBenchmark(emitter),
    StaticAddSpannerBenchmark(emitter),
    StaticAddBenchmark(emitter),
    StaticLookupRoutingkitBenchmark(emitter),
    StaticLookupSpannerBenchmark(emitter),
    StaticLookupBenchmark(emitter),
    DynamicAddRoutingkitBenchmark(emitter),
    DynamicAddSpannerBenchmark(emitter),
    DynamicAddBenchmark(emitter),
    DynamicLookupRoutingkitBenchmark(emitter),
    DynamicLookupSpannerBenchmark(emitter),
    DynamicLookupBenchmark(emitter),
  ]) {
    await _yield;
    benchmark.report();
    if (Platform.isLinux) await benchmark.reportPerf();
  }
  return true;
}

Future<void> get _yield => Future<void>.delayed(Duration.zero);
