import 'package:relic/relic.dart';
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relic/src/method/request_method.dart';
import 'package:test/test.dart';
import 'package:relic/src/relic_server_serve.dart' as relic_server;

void main() {
  tearDown(() async {
    var server = _server;
    if (server != null) {
      try {
        await server.close().timeout(Duration(seconds: 5));
      } catch (e) {
        await server.close(force: true);
      } finally {
        _server = null;
      }
    }
  });

  group('Given a server', () {
    test(
        'when a handler throws an InvalidHeaderException '
        'then it returns a 400 Bad Request response with exception message '
        'included in the response body', () async {
      await _scheduleServer(
        (Request request) => throw InvalidHeaderException(
          'Value cannot be empty',
          headerType: 'test',
        ),
      );
      final response = await _get();
      expect(response.statusCode, 400);
      expect(response.body, 'Invalid \'test\' header: Value cannot be empty');
    });

    test(
        'when a handler throws an UnimplementedError '
        'then it returns a 500 Internal Server Error response', () async {
      await _scheduleServer(
        (Request request) => throw UnimplementedError(),
      );
      final response = await _get();
      expect(response.statusCode, 500);
      expect(response.body, 'Internal Server Error');
    });

    test(
        'when a handler throws an Exception '
        'then it returns a 500 Internal Server Error response', () async {
      await _scheduleServer((Request request) => throw Exception());
      final response = await _get();
      expect(response.statusCode, 500);
      expect(response.body, 'Internal Server Error');
    });

    test(
        'when a handler throws an Error '
        'then it returns a 500 Internal Server Error response', () async {
      await _scheduleServer((Request request) => throw Error());
      final response = await _get();
      expect(response.statusCode, 500);
      expect(response.body, 'Internal Server Error');
    });
  });
}

int get _serverPort => _server!.port;

HttpServer? _server;

Future<void> _scheduleServer(
  Handler handler, {
  SecurityContext? securityContext,
}) async {
  assert(_server == null);
  _server = await relic_server.serve(
    handler,
    InternetAddress.loopbackIPv4,
    0,
    securityContext: securityContext,
  );
}

Future<http.Response> _get({
  Map<String, String>? headers,
  String path = '',
}) async {
  var request = http.Request(
    RequestMethod.get.value,
    Uri.http('localhost:$_serverPort', path),
  );

  if (headers != null) request.headers.addAll(headers);

  var response = await request.send();
  return await http.Response.fromStream(response).timeout(Duration(seconds: 1));
}
