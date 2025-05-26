// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math';

import 'package:benchmark_harness/perf_benchmark_harness.dart';
import 'package:cli_tools/cli_tools.dart';
import 'package:git/git.dart';
import 'package:path/path.dart' as p;
import 'package:relic/relic.dart';
import 'package:routingkit/routingkit.dart' as routingkit;
import 'package:spanner/spanner.dart' as spanner;

late final List<int> indexes;
late final List<String> staticRoutesToLookup;
late final List<String> dynamicRoutesToLookup;

void setupBenchmarkData(final int routeCount) {
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

  Future<void> close() async {
    await _output.close();
  }
}

abstract class RouterBenchmark extends PerfBenchmarkBase {
  RouterBenchmark(final Iterable<String> grouping, final Emitter emitter)
      : super(grouping.join(';'), emitter: emitter);

  @override
  void exercise() => run();
}

// Benchmark for adding static routes
class StaticAddBenchmark extends RouterBenchmark {
  StaticAddBenchmark(final Emitter emitter)
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
  StaticLookupBenchmark(final Emitter emitter)
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
  DynamicAddBenchmark(final Emitter emitter)
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
  DynamicLookupBenchmark(final Emitter emitter)
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
  StaticAddRoutingkitBenchmark(final Emitter emitter)
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
  StaticLookupRoutingkitBenchmark(final Emitter emitter)
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
  DynamicAddRoutingkitBenchmark(final Emitter emitter)
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
  DynamicLookupRoutingkitBenchmark(final Emitter emitter)
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
  StaticAddSpannerBenchmark(final Emitter emitter)
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
  StaticLookupSpannerBenchmark(final Emitter emitter)
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
  DynamicAddSpannerBenchmark(final Emitter emitter)
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
  DynamicLookupSpannerBenchmark(final Emitter emitter)
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

enum RunOption<V> implements OptionDefinition<V> {
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
    min: 1,
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

  const RunOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

File _defaultFile() {
  final tmpDir = Directory.systemTemp.createTempSync();
  return File(p.join(tmpDir.path, 'benchmark_results.csv'));
}

class RunCommand extends BetterCommand<RunOption<dynamic>, void> {
  RunCommand({super.env}) : super(options: RunOption.values);

  @override
  final description = 'Run comparative router benchmarks';

  @override
  final name = 'run';

  @override
  FutureOr<void>? runWithConfig(
    final Configuration<RunOption<dynamic>> commandConfig,
  ) async {
    final file = commandConfig.value(RunOption.file);
    final pause = commandConfig.value(RunOption.pause);
    final iterations = commandConfig.value(RunOption.iterations);
    final storeInNotes = commandConfig.value(RunOption.storeInNotes);

    final git = await GitDir.fromExisting(p.current, allowSubdirectory: true);
    if (storeInNotes && !await git.isWorkingTreeClean()) {
      throw StateError('Working copy not clean!');
    }

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
    await emitter.close();

    if (storeInNotes) {
      final head = await git.commitFromRevision('HEAD');
      logger.info('Appending benchmark results to: ${head.treeSha} (tree)');
      await git.runCommand(
        ['notes', '--ref=benchmarks', 'append', '-F', file.path, head.treeSha],
        echoOutput: logger.shouldLog(LogLevel.debug),
      );
    }
  }
}

enum ExtractOption<V> implements OptionDefinition<V> {
  from(StringOption(argName: 'from', argAbbrev: 'f', defaultsTo: 'HEAD^')),
  to(StringOption(argName: 'to', argAbbrev: 't', defaultsTo: 'HEAD'));

  const ExtractOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

class ExtractCommand extends BetterCommand<ExtractOption<dynamic>, void> {
  ExtractCommand({super.env}) : super(options: ExtractOption.values);

  @override
  final description = 'Extract benchmark data';

  @override
  final name = 'extract';

  @override
  FutureOr<void>? runWithConfig(
    final Configuration<ExtractOption<dynamic>> commandConfig,
  ) async {
    final from = commandConfig.value(ExtractOption.from);
    final to = commandConfig.value(ExtractOption.to);

    final git = await GitDir.fromExisting(p.current, allowSubdirectory: true);
    final result = await git.runCommand(
      ['log', '--format=%aI %H %T', '$from..$to'],
    );

    final sb = StringBuffer();
    for (final line in (result.stdout as String).split('\n')) {
      final hashes = line.split(' ');
      if (hashes.length < 2) continue;

      final authorTime = DateTime.parse(hashes[0]);
      final commitSha = hashes[1];
      final treeSha = hashes[2];
      logger.debug('$commitSha $treeSha $authorTime');

      final result = await git.runCommand(
        ['notes', '--ref=benchmarks', 'show', treeSha],
        throwOnError: false,
      );
      if (result.exitCode == 0) sb.writeln(result.stdout);
    }
    logger.info(sb.toString());
  }
}

final logger = StdOutLogger(LogLevel.info);

void setLogLevel({
  required final CommandRunnerLogLevel parsedLogLevel,
  final String? commandName,
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
      ExtractCommand(),
    ]);
  try {
    await runner.run(args);
  } on UsageException catch (ex) {
    print('${ex.message}\n\n${ex.usage}');
    return 1;
  }
  return 0;
}

Future<bool> driver(final Emitter emitter) async {
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
    benchmark.report();
    // TODO(kasper): This hangs on CI
    // if (Platform.isLinux) await benchmark.reportPerf();
  }
  return true;
}
