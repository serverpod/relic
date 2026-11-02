import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import '../util/test_util.dart';

void main() {
  late RelicServer server;

  tearDown(() => server.close(force: true));

  test('Given a handler that reads the body with a limit, '
      'when a POST declares a length over the limit, '
      'then the client receives the answer of the handler.', () async {
    server = await testServe((req) async {
      try {
        await req.read(maxLength: 1024).drain<void>();
        return Response.ok();
      } on MaxBodySizeExceeded {
        return Response.contentTooLarge(body: Body.fromString('too large'));
      }
    });
    final client = HttpClient();
    addTearDown(client.close);

    final request = await client.postUrl(
      Uri.http('${InternetAddress.loopbackIPv4.address}:${server.port}'),
    );
    // Big enough that the client is still sending when the handler answers,
    // on Linux as well as macOS.
    final body = Uint8List(16 << 20);
    request.contentLength = body.length;
    request.add(body);
    final response = await request.close();

    expect(response.statusCode, 413);
    expect(await utf8.decodeStream(response), 'too large');
  });
}
