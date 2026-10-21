import 'package:http/http.dart' as http;
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import '../test_utils_base.dart';
import 'conformance.dart';

void serverTests(AdapterConformance conformance) {
  group('Given a server with two isolates', () {
    late RelicServer server;

    setUp(() => server = conformance.create(noOfIsolates: 2));

    tearDown(() => server.close());

    test('when a valid HTTP request is made '
        'then it serves the request using the mounted handler', () async {
      await server.mountAndStart(syncHandler);
      final response = await http.read(server.url);
      expect(response, equals('Hello from /'));
    });

    test('when a request with a malformed target is made '
        'then it returns a 400 Bad Request response', () async {
      await server.mountAndStart(syncHandler);
      final rs = await http.get(
        Uri.parse('${server.url}/%D0%C2%BD%A8%CE%C4%BC%FE%BC%D0.zip'),
      );
      expect(rs.statusCode, 400);
      expect(rs.body, 'Bad Request');
    });
  });

  test('Given a bound adapter with no handler mounted, '
      'when a request arrives before the server is started, '
      'then it is answered once a handler is mounted', () async {
    final adapter = await conformance.bind(shared: false)();
    final port = adapter.listeners.single.port;
    final delayedResponse = http.read(Uri.http('localhost:$port'));
    final server = RelicServer(() => adapter);
    await server.mountAndStart(asyncHandler);
    await expectLater(delayedResponse, completion(equals('Hello from /')));
    await server.close();
  });
}
