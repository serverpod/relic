import 'package:http/http.dart' as http;
import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../headers/headers_test_utils.dart';
import '../util/test_util.dart';

void main() {
  late RelicServer server;

  setUp(() async {
    server = await testServe(
      syncHandler,
    );
  });

  tearDown(() => server.close());

  group('Using the adaptor abstraction', () {
    test('it should handle basic requests', () async {
      // Create a URI using the port assigned by the OS
      final response = await http.get(server.url);

      expect(response.statusCode, equals(200));
      expect(response.body, equals('Hello from /'));
    });

    test('it should handle different request paths', () async {
      final url = server.url.replace(path: '/different/path');
      final response = await http.get(url);

      // We should still get a 200 response
      expect(response.statusCode, equals(200));
      // The handler should reflect the different path
      expect(response.body, equals('Hello from /different/path'));
    });
  });
}
