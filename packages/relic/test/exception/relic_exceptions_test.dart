import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../headers/headers_test_utils.dart';
import '../util/test_util.dart';

void main() {
  tearDown(() async {
    final server = _server;
    if (server != null) {
      try {
        await server.close().timeout(const Duration(seconds: 5));
      } catch (e) {
        await server.close();
      } finally {
        _server = null;
      }
    }
  });

  group('Given a server', () {
    test('when a handler throws an InvalidHeaderException '
        'then it returns a 400 Bad Request response with exception message '
        'included in the response body', () async {
      await _scheduleServer(
        (_) =>
            throw const InvalidHeaderException(
              'Value cannot be empty',
              headerType: 'test',
            ),
      );
      final response = await _get();
      expect(response.statusCode, 400);
      expect(response.body, "Invalid 'test' header: Value cannot be empty");
    });

    test('when a handler throws an UnimplementedError '
        'then it returns a 500 Internal Server Error response', () async {
      await _scheduleServer((_) => throw UnimplementedError());
      final response = await _get();
      expect(response.statusCode, 500);
      expect(response.body, 'Internal Server Error');
    });

    test('when a handler throws an Exception '
        'then it returns a 500 Internal Server Error response', () async {
      await _scheduleServer((_) => throw Exception());
      final response = await _get();
      expect(response.statusCode, 500);
      expect(response.body, 'Internal Server Error');
    });

    test('when a handler throws an Error '
        'then it returns a 500 Internal Server Error response', () async {
      await _scheduleServer((_) => throw Error());
      final response = await _get();
      expect(response.statusCode, 500);
      expect(response.body, 'Internal Server Error');
    });
  });
}

RelicServer? _server;

Future<void> _scheduleServer(final Handler handler) async {
  assert(_server == null);
  _server = await testServe(handler);
}

Future<http.Response> _get({
  final Map<String, String>? headers,
  final String path = '',
}) async {
  final request = http.Request(
    Method.get.value,
    _server!.url.replace(path: path),
  );

  if (headers != null) request.headers.addAll(headers);

  final response = await request.send();
  return await http.Response.fromStream(
    response,
  ).timeout(const Duration(seconds: 1));
}
