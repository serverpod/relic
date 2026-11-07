import 'package:http/http.dart' as http;
import 'package:relic_core/relic_core.dart';
import 'package:relic_native/relic_native.dart';
import 'package:test/test.dart';

import 'native_test_helpers.dart';

void main() {
  late RelicServer server;

  tearDown(() => server.close(force: true));

  test('Given a server that streams every request body, '
      'when eight clients post a body at once, '
      'then every client gets the length of its body back', () async {
    server = await serveNative(
      (req) async => Response.ok(
        body: Body.fromString('${(await req.readAsString()).length}'),
      ),
      options: const NativeOptions(maxInlineBody: 0),
    );

    Future<String> post(int size) async => (await http.post(
      Uri.http('127.0.0.1:${server.port}'),
      body: 'a' * size,
    )).body;

    final sizes = [for (var i = 1; i <= 8; i++) i * 1000];
    final answers = await Future.wait([
      for (final size in sizes) post(size),
    ]).timeout(const Duration(seconds: 5));

    expect(answers, [for (final size in sizes) '$size']);
  });
}
