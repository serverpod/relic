import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relic/relic.dart';
import 'package:test/test.dart';

import 'headers/headers_test_utils.dart';
import 'util/test_util.dart';

void main() {
  // Use concrete type to ensure extensions are applied
  late RelicServer server;

  setUp(() async {
    server = await createServer();
  });

  tearDown(() => server.close());

  group('Given a server', () {
    test('when a valid HTTP request is made '
        'then it serves the request using the mounted handler', () async {
      await server.mountAndStart(syncHandler);
      // Use toUri to ensure we have a valid Uri object
      final response = await http.read(server.url);
      expect(response, equals('Hello from /'));
    });

    test('when a malformed HTTP request is made '
        'then it returns a 400 Bad Request response', () async {
      await server.mountAndStart(syncHandler);
      final rs = await http.get(
        Uri.parse('${server.url}/%D0%C2%BD%A8%CE%C4%BC%FE%BC%D0.zip'),
      );
      expect(rs.statusCode, 400);
      expect(rs.body, 'Bad Request');
    });

    test('when no handler is mounted initially '
        'then it delays requests until a handler is mounted', () async {
      final adapter = await IOAdapter.bind(InternetAddress.loopbackIPv4);
      final port = adapter.port;
      final delayedResponse = http.read(Uri.http('localhost:$port'));
      final server = RelicServer(() => adapter);
      await server.mountAndStart(asyncHandler);
      await expectLater(delayedResponse, completion(equals('Hello from /')));
      await server.close();
    });
  });
}
