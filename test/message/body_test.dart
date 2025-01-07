import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:relic/relic.dart';
import 'package:relic/src/method/request_method.dart';
import 'package:relic/src/relic_server_serve.dart' as relic_server;
import 'package:test/test.dart';

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

  group('Given a response', () {
    test(
        'with an empty body and "chunked" transfer encoding '
        'when applying headers to the response then the "chunked" transfer '
        'encoding is removed', () async {
      await _scheduleServer(
        (_) => Response.ok(
          body: Body.empty(),
          headers: Headers.response(
            transferEncoding: TransferEncodingHeader(
              encodings: [TransferEncoding.chunked],
            ),
          ),
        ),
      );

      var response = await _get();
      expect(response.body, isEmpty);
      expect(response.headers['transfer-encoding'], isNull);
    });

    test(
        'with unknown content length when applying headers '
        'to the response then "chunked" transfer encoding is added', () async {
      await _scheduleServer(
        (_) => Response.ok(
          body: Body.fromDataStream(
            Stream.fromIterable([
              Uint8List.fromList([1, 2, 3, 4])
            ]),
          ),
        ),
      );

      var response = await _get();
      expect(
        response.headers['transfer-encoding'],
        contains(TransferEncoding.chunked.name),
      );
      expect(response.bodyBytes, equals([1, 2, 3, 4]));
    });

    test(
        'with a known content length when applying headers '
        'to the response then "chunked" transfer encoding is not added',
        () async {
      await _scheduleServer(
        (_) => Response.ok(
          body: Body.fromData(
            Uint8List.fromList([1, 2, 3, 4]),
          ),
        ),
      );

      var response = await _get();
      expect(response.headers['transfer-encoding'], isNull);
      expect(response.headers['content-length'], equals('4'));
      expect(response.bodyBytes, equals([1, 2, 3, 4]));
    });

    test(
        'with "identity" transfer encoding and unknown "content-length" when '
        'applying headers to the response then the response times out because '
        'server does not send a "content-length" or end of stream', () async {
      await _scheduleServer(
        (_) => Response.ok(
          body: Body.fromDataStream(
            Stream.fromIterable([
              Uint8List.fromList([1, 2, 3, 4])
            ]),
          ),
          headers: Headers.response(
            transferEncoding: TransferEncodingHeader(
              encodings: [TransferEncoding.identity],
            ),
          ),
        ),
      );

      expect(
        () async => await _get(),
        throwsA(isA<TimeoutException>()),
      );
    });

    test(
        'with "chunked" transfer encoding already applied when applying headers '
        'to the response then "chunked" is retained', () async {
      await _scheduleServer(
        (_) => Response.ok(
          body: Body.fromDataStream(
            Stream.fromIterable([
              Uint8List.fromList('5\r\nRelic\r\n0\r\n\r\n'.codeUnits),
            ]),
          ),
          headers: Headers.response(
            transferEncoding: TransferEncodingHeader(
              encodings: [TransferEncoding.chunked],
            ),
          ),
        ),
      );

      var response = await _get();
      expect(
        response.headers['transfer-encoding'],
        contains(TransferEncoding.chunked.name),
      );
      expect(response.body, equals('5\r\nRelic\r\n0\r\n\r\n'));
    });

    test(
        'with a valid content length when applying headers '
        'to the response then Content-Length is used instead of chunked encoding',
        () async {
      await _scheduleServer(
        (_) => Response.ok(
          body: Body.fromDataStream(
            Stream.fromIterable([
              Uint8List.fromList([1, 2, 3, 4])
            ]),
            contentLength: 4,
          ),
          headers: Headers.response(),
        ),
      );

      var response = await _get();
      expect(response.headers['content-length'], equals('4'));
      expect(response.headers['transfer-encoding'], isNull);
      expect(response.bodyBytes, equals([1, 2, 3, 4]));
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
    RelicAddress.fromHostname('localhost'),
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
