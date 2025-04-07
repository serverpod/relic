import 'package:http/http.dart' as http;
import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../util/test_util.dart';

void main() {
  late RelicServer server;

  setUp(() async {
    server = await serve(
      syncHandler,
      Address.loopback(),
      0, // Use port 0 for automatic port assignment
      strictHeaders: false,
    );
  });

  tearDown(() => server.close());

  group('Using the server adaptor abstraction', () {
    test('it should handle basic requests', () async {
      // Create a URI using the port assigned by the OS
      final uri = Uri.parse('http://localhost:${server.adaptor.port}/');
      final response = await http.get(uri);

      expect(response.statusCode, equals(200));
      expect(response.body, equals('Hello from /'));
    });

    test('it should handle different request paths', () async {
      final uri =
          Uri.parse('http://localhost:${server.adaptor.port}/different/path');
      final response = await http.get(uri);

      // We should still get a 200 response
      expect(response.statusCode, equals(200));
      // The handler should reflect the different path
      expect(response.body, equals('Hello from /different/path'));
    });

    test('it should provide correct server information', () {
      // Test that our abstraction correctly exposes server information
      expect(server.adaptor.port, greaterThan(0));
      expect(server.adaptor.address, isNotNull);
    });
  });
}
