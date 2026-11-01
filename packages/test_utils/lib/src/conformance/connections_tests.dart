import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import '../test_utils_base.dart';
import 'conformance.dart';

/// Holds every request until the test sends to the port it gets on
/// [arrived], so none has been answered and closed while it counts
/// connections.
Handler _heldHandler(SendPort arrived) {
  return (req) async {
    final release = ReceivePort();
    arrived.send(release.sendPort);
    await release.first;
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
      late ReceivePort arrived;

      setUp(() async {
        arrived = ReceivePort();
        server = conformance.create(noOfIsolates: i);
        await server.mountAndStart(_heldHandler(arrived.sendPort));
      });

      tearDown(() async {
        await server.close();
        arrived.close();
      });

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

          final held = await arrived.take(j).cast<SendPort>().toList();

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

          for (final request in held) {
            request.send(null);
          }
          await Future.wait(requests);
        },
      );
    },
  );
}
