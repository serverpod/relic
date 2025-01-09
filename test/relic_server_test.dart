@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relic/src/address/relic_address.dart';
import 'package:relic/src/relic_server.dart';
import 'package:test/test.dart';

import 'util/test_util.dart';

void main() {
  late RelicServer server;

  setUp(() async {
    try {
      server = await RelicServer.createServer(
        RelicAddress.fromInternetAddress(InternetAddress.loopbackIPv6),
        0,
      );
    } on SocketException catch (_) {
      server = await RelicServer.createServer(
        RelicAddress.fromInternetAddress(InternetAddress.loopbackIPv4),
        0,
      );
    }
  });

  tearDown(() => server.close());

  group('Given a server', () {
    test(
        'when a valid HTTP request is made '
        'then it serves the request using the mounted handler', () async {
      server.mountAndStart(syncHandler);
      final response = await http.read(server.url);
      expect(response, equals('Hello from /'));
    });

    test(
        'when a malformed HTTP request is made '
        'then it returns a 400 Bad Request response', () async {
      server.mountAndStart(syncHandler);
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
      server.mountAndStart(asyncHandler);
      expect(delayedResponse, completion(equals('Hello from /')));
    });

    test(
        'when a handler is already mounted '
        'then mounting another handler throws a StateError', () async {
      server.mountAndStart((_) => throw UnimplementedError());
      expect(
        () => server.mountAndStart((_) => throw UnimplementedError()),
        throwsStateError,
      );
      expect(
        () => server.mountAndStart((_) => throw UnimplementedError()),
        throwsStateError,
      );
    });
  });
}
