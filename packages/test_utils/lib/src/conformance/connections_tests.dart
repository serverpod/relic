import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import '../test_utils_base.dart';
import 'conformance.dart';

Handler _delayedHandler() {
  return (req) async {
    final delay = Platform.environment['CI'] != null ? 1000 : 100;
    await Future<void>.delayed(Duration(milliseconds: delay));
    return Response.ok();
  };
}

void connectionsTests(AdapterConformance conformance) {
  const maxIsolates = 5;
  const maxRequests = 5;
  parameterizedGroup(
    variants: List.generate(maxIsolates, (i) => i + 1),
    (i) => 'Given a server with $i isolates',
    (i) {
      late RelicServer server;

      setUp(() async {
        server = conformance.create(noOfIsolates: i);
        await server.mountAndStart(_delayedHandler());
      });

      tearDown(() => server.close());

      parameterizedTest(
        variants: List.generate(maxRequests, (j) => j + 1),
        (j) =>
            'when $j requests are in-flight across isolates, '
            'then connectionsInfo returns aggregated active and idle count of $j',
        (j) async {
          final requests = <Future<http.Response>>[];
          for (var i = 0; i < j; i++) {
            requests.add(http.get(Uri.http('localhost:${server.port}')));
          }

          // Give requests time to reach the server and start processing.
          await Future<void>.delayed(const Duration(milliseconds: 100));

          await expectLater(
            server.connectionsInfo(),
            completion(
              isA<ConnectionsInfo>().having(
                (ci) => ci.active + ci.idle,
                'active + idle',
                j,
              ),
            ),
          );

          await Future.wait(requests);
        },
      );
    },
  );
}
