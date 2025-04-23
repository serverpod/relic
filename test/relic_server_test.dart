@Timeout.none
library;

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:relic/relic.dart';
import 'package:test/test.dart';

import 'headers/headers_test_utils.dart';
import 'util/test_util.dart';

void main() {
  // Use concrete type to ensure extensions are applied
  late RelicServer server;

  setUp(() async {
    server = await createServer(strictHeaders: false);
  });

  tearDown(() => server.close());

  group('Given a server', () {
    test(
        'when a valid HTTP request is made '
        'then it serves the request using the mounted handler', () async {
      await server.mountAndStart(respondWith(syncHandler));
      // Use toUri to ensure we have a valid Uri object
      final response = await http.read(server.url);
      expect(response, equals('Hello from /'));
    });

    test(
        'when a malformed HTTP request is made '
        'then it returns a 400 Bad Request response', () async {
      await server.mountAndStart(respondWith(syncHandler));
      final rs = await http
          .get(Uri.parse('${server.url}/%D0%C2%BD%A8%CE%C4%BC%FE%BC%D0.zip'));
      expect(rs.statusCode, 400);
      expect(rs.body, 'Bad Request');
    });

    test(
        'when no handler is mounted initially '
        'then it delays requests until a handler is mounted', () async {
      final delayedResponse = http.read(server.url);
      await Future<void>.delayed(Duration.zero);
      await server.mountAndStart(respondWith(asyncHandler));
      expect(delayedResponse, completion(equals('Hello from /')));
    });

    test(
        'when a handler is already mounted '
        'then mounting another handler throws a StateError', () async {
      await server.mountAndStart((final _) => throw UnimplementedError());
      expect(
        () => server.mountAndStart((final _) => throw UnimplementedError()),
        throwsStateError,
      );
      expect(
        () => server.mountAndStart((final _) => throw UnimplementedError()),
        throwsStateError,
      );
    });
  });
}
