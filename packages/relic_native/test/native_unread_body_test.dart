import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import 'native_test_helpers.dart';

/// Big enough that the client is still sending when the handler answers,
/// and over the 4 MiB the adapter drains for the next request.
const _bodySize = 16 << 20;

void main() {
  late RelicServer server;
  late HttpClient client;

  setUp(() => client = HttpClient());
  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
  });

  Future<HttpClientRequest> post() => client.postUrl(
    Uri.http('${InternetAddress.loopbackIPv4.address}:${server.port}'),
  );

  test('Given a handler that reads the body with a limit, '
      'when a POST declares a length over the limit, '
      'then the client receives the answer of the handler.', () async {
    server = await serveNative((req) async {
      try {
        await req.read(maxLength: 1024).drain<void>();
        return Response.ok();
      } on MaxBodySizeExceeded {
        return Response.contentTooLarge(body: Body.fromString('too large'));
      }
    });

    final request = await post();
    request.contentLength = _bodySize;
    request.add(Uint8List(_bodySize));
    final response = await request.close();

    expect(response.statusCode, 413);
    expect(await utf8.decodeStream(response), 'too large');
  });

  group('Given a handler that answers without reading the body,', () {
    setUp(() async {
      server = await serveNative(
        (_) => Response.ok(body: Body.fromString('unread')),
      );
    });

    test('when a POST declares a length over the drain limit, '
        'then the client receives the answer of the handler.', () async {
      final request = await post();
      request.contentLength = _bodySize;
      request.add(Uint8List(_bodySize));
      final response = await request.close();

      expect(response.statusCode, 200);
      expect(await utf8.decodeStream(response), 'unread');
    });

    test('when a POST sends a chunked body, '
        'then the client receives the answer of the handler.', () async {
      final request = await post();
      // No content length, so dart:io sends the body chunked.
      request.add(Uint8List(_bodySize));
      final response = await request.close();

      expect(response.statusCode, 200);
      expect(await utf8.decodeStream(response), 'unread');
    });
  });
}
