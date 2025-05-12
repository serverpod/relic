// ignore_for_file: avoid_print
import 'dart:developer';
import 'dart:io';
import 'dart:math';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:relic/src/router/router.dart';
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

abstract class RouterBenchmark extends BenchmarkBase {
  RouterBenchmark(super.name);

  @override
  void exercise() => run();
}

// Benchmark for adding static routes
class StaticAddBenchmark extends RouterBenchmark {
  StaticAddBenchmark() : super('Router Add Static x$routeCount');

  @override
  void run() {
    final router = Router<int>();
    for (final i in indexes) {
      router.add('/path$i', i);
    }
  }
}

// Benchmark for looking up static routes
class StaticLookupBenchmark extends RouterBenchmark {
  StaticLookupBenchmark() : super('Router Lookup Static x$routeCount');

  late final Router<int> staticRouterForLookup;

  @override
  void setup() {
    staticRouterForLookup = Router<int>();
    for (final i in indexes) {
      staticRouterForLookup.add('/path$i', i);
    }
  }

  @override
  void run() {
    for (final route in staticRoutesToLookup) {
      // Access value to ensure lookup isn't optimized away
      staticRouterForLookup.lookup(route)?.value;
    }
  }
}

// Benchmark for adding dynamic routes
class DynamicAddBenchmark extends RouterBenchmark {
  DynamicAddBenchmark() : super('Router Add Dynamic x$routeCount');

  @override
  void run() {
    final router = Router<int>();
    for (final i in indexes) {
      router.add('/users/:id/items/:itemId/profile$i', i);
    }
  }
}

// Benchmark for looking up dynamic routes
class DynamicLookupBenchmark extends RouterBenchmark {
  DynamicLookupBenchmark() : super('Router Lookup Dynamic x$routeCount');

  late final Router<int> dynamicRouterForLookup;

  @override
  void setup() {
    // Create and populate routers specifically for lookup benchmarks
    dynamicRouterForLookup = Router<int>();
    for (final i in indexes) {
      dynamicRouterForLookup.add('/users/:id/items/:itemId/profile$i', i);
    }
  }

  @override
  void run() {
    for (final route in dynamicRoutesToLookup) {
      // Access value to ensure lookup isn't optimized away
      dynamicRouterForLookup.lookup(route)?.value;
    }
  }
}

class StaticAddRoutingkitBenchmark extends RouterBenchmark {
  StaticAddRoutingkitBenchmark() : super('Routingkit Add Static x$routeCount');

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
      : super('Routingkit Lookup Static x$routeCount');

  late final routingkit.Router<int> staticRouterForLookup;

  @override
  void setup() {
    staticRouterForLookup = routingkit.createRouter<int>();
    for (final i in indexes) {
      staticRouterForLookup.add('GET', '/path$i', i);
    }
  }

  @override
  void run() {
    for (final route in staticRoutesToLookup) {
      // Access value to ensure lookup isn't optimized away
      staticRouterForLookup.find('GET', route)?.data;
    }
  }
}

class DynamicAddRoutingkitBenchmark extends RouterBenchmark {
  DynamicAddRoutingkitBenchmark()
      : super('Routingkit Add Dynamic x$routeCount');

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
      : super('Routingkit Lookup Dynamic x$routeCount');

  late final routingkit.Router<int> dynamicRouterForLookup;

  @override
  void setup() {
    // Create and populate routers specifically for lookup benchmarks
    dynamicRouterForLookup = routingkit.createRouter<int>();
    for (final i in indexes) {
      dynamicRouterForLookup.add(
          'GET', '/users/:id/items/:itemId/profile$i', i);
    }
  }

  @override
  void run() {
    for (final route in dynamicRoutesToLookup) {
      // Access value to ensure lookup isn't optimized away
      dynamicRouterForLookup.find('GET', route)?.data;
    }
  }
}

class StaticAddSpannerBenchmark extends RouterBenchmark {
  StaticAddSpannerBenchmark() : super('Spanner Add Static x$routeCount');

  @override
  void run() {
    final router = spanner.Spanner();
    for (final i in indexes) {
      router.addRoute(spanner.HTTPMethod.GET, '/path$i', i);
    }
  }
}

class StaticLookupSpannerBenchmark extends RouterBenchmark {
  StaticLookupSpannerBenchmark() : super('Spanner Lookup Static x$routeCount');

  late final spanner.Spanner staticRouterForLookup;

  @override
  void setup() {
    staticRouterForLookup = spanner.Spanner();
    for (final i in indexes) {
      staticRouterForLookup.addRoute(spanner.HTTPMethod.GET, '/path$i', i);
    }
  }

  @override
  void run() {
    for (final route in staticRoutesToLookup) {
      // Access value to ensure lookup isn't optimized away
      staticRouterForLookup.lookup(spanner.HTTPMethod.GET, route)?.values;
    }
  }
}

class DynamicAddSpannerBenchmark extends RouterBenchmark {
  DynamicAddSpannerBenchmark() : super('Spanner Add Dynamic x$routeCount');

  @override
  void run() {
    final router = spanner.Spanner();
    for (final i in indexes) {
      router.addRoute(
          spanner.HTTPMethod.GET, '/users/:id/items/:itemId/profile$i', i);
    }
  }
}

class DynamicLookupSpanneBenchmark extends RouterBenchmark {
  DynamicLookupSpanneBenchmark() : super('Spanner Lookup Dynamic x$routeCount');

  late final spanner.Spanner dynamicRouterForLookup;

  @override
  void setup() {
    // Create and populate routers specifically for lookup benchmarks
    dynamicRouterForLookup = spanner.Spanner();
    for (final i in indexes) {
      dynamicRouterForLookup.addRoute(
          spanner.HTTPMethod.GET, '/users/<id>/items/<itemId>/profile$i', i);
    }
  }

  @override
  void run() {
    for (final route in dynamicRoutesToLookup) {
      // Access value to ensure lookup isn't optimized away
      dynamicRouterForLookup.lookup(spanner.HTTPMethod.GET, route)?.values;
    }
  }
}

void main() async {
  final info = await Service.getInfo();
  if (info.serverUri != null) {
    print('Press <enter> when ready..');
    if (stdin.hasTerminal) {
      await stdin.first;
    }
  }
  await driver();
}

Future<void> driver() async {
  setupBenchmarkData();

  print('Starting benchmarks');

  print('---');
  print('Static Add');
  StaticAddBenchmark().report();
  StaticAddRoutingkitBenchmark().report();
  StaticAddSpannerBenchmark().report();

  print('---');
  print('Static Lookup');
  StaticLookupBenchmark().report();
  StaticLookupRoutingkitBenchmark().report();
  StaticLookupSpannerBenchmark().report();

  print('---');
  print('Dynamic Add');
  DynamicAddBenchmark().report();
  DynamicAddRoutingkitBenchmark().report();
  DynamicAddSpannerBenchmark().report();

  print('---');
  print('Dynamic Lookup');
  DynamicLookupBenchmark().report();
  DynamicLookupRoutingkitBenchmark().report();
  DynamicLookupSpanneBenchmark().report();

  print('Done');
}
