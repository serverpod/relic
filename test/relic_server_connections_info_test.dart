import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';
import 'package:test/test.dart';

import 'util/test_util.dart';

Handler _createDelayedHandler() {
  return (final req) async {
    final delay = Platform.environment['CI'] != null ? 1000 : 100;
    // Block for a fixed duration.
    await Future<void>.delayed(Duration(milliseconds: delay));
    return Response.ok();
  };
}

void main() {
  const maxIsolates = 5;
  const maxRequests = 5;
  parameterizedGroup(
    variants: List.generate(maxIsolates, (final i) => i + 1),
    (final i) => 'Given a RelicServer with $i isolates',
    (final i) {
      late RelicServer server;

      setUp(() async {
        server = RelicServer(
          () => IOAdapter.bind(InternetAddress.loopbackIPv4, port: 0),
          noOfIsolates: i,
        );

        await server.mountAndStart(_createDelayedHandler());
      });

      tearDown(() => server.close());

      parameterizedTest(
        variants: List.generate(maxRequests, (final j) => j + 1),
        (final j) =>
            'when $j requests are in-flight across isolates, '
            'then connectionsInfo returns aggregated active and idle count of $j',
        (final j) async {
          // Fire off j concurrent requests without awaiting
          final requests = <Future<http.Response>>[];
          for (var i = 0; i < j; i++) {
            requests.add(http.get(Uri.http('localhost:${server.port}')));
          }

          // Give requests time to reach the server and start processing
          await Future<void>.delayed(const Duration(milliseconds: 100));

          await expectLater(
            server.connectionsInfo(),
            completion(
              isA<ConnectionsInfo>().having(
                (final ci) => ci.active + ci.idle,
                'active + idle',
                j,
              ),
            ),
          );

          await requests.wait;
        },
      );
    },
  );
}
