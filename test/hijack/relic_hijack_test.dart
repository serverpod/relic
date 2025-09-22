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
    test(
      'when request context is hijacked '
      'then an HijackContext is returned and the request times out because '
      'server does not write the response to the HTTP response',
      () async {
        await _scheduleServer(
          (final ctx) {
            final newCtx = ctx.hijack((final _) {});
            expect(newCtx, isA<HijackContext>());
            return newCtx;
          },
        );
        expect(
          _get(),
          throwsA(isA<TimeoutException>()),
        );
      },
    );
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

  final response = await request.send().timeout(const Duration(seconds: 1));
  return await http.Response.fromStream(response)
      .timeout(const Duration(seconds: 1));
}
