import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import 'native_test_helpers.dart';

void main() {
  test('Given bodies on both sides of the connection write buffer size, '
      'when each is served on one keep-alive connection, '
      'then every body arrives byte for byte', () async {
    // A response that fits the 16 KiB write buffer with its head is
    // encoded into it, a larger one is copied. The sizes straddle that.
    const sizes = [0, 1, 15000, 16000, 16200, 16383, 16384, 16385, 40000];
    Uint8List pattern(int size) =>
        Uint8List.fromList(List.generate(size, (i) => (i * 31) & 0xff));
    final server = await serveNative((req) {
      final size = int.parse(req.url.queryParameters['size']!);
      return Response.ok(body: Body.fromData(pattern(size)));
    });
    addTearDown(() => server.close(force: true));
    final client = http.Client();
    addTearDown(client.close);

    for (final size in sizes) {
      final response = await client.get(
        Uri.parse('http://127.0.0.1:${server.port}/?size=$size'),
      );

      expect(response.statusCode, 200, reason: 'size $size');
      expect(response.bodyBytes, pattern(size), reason: 'size $size');
    }
  });
}
