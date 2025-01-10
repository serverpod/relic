import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relic/relic.dart';
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
        'when request is hijacked '
        'then an HijackException is thrown and the request times out because '
        'server does not write the response to the HTTP response', () async {
      await _scheduleServer(
        (Request request) {
          try {
            request.hijack((stream) => {});
          } catch (e) {
            expect(e, isA<HijackException>());
            rethrow;
          }
        },
      );
      expect(
        () async => await _get(),
        throwsA(isA<TimeoutException>()),
      );
    });

    test(
        'when request is hijacked but no HijackException is thrown '
        'then server throws a StateError when trying to write the response '
        'to the HTTP response', () async {
      final Completer<Object?> completer = Completer();
      unawaited(
        runZonedGuarded(() async {
          await _scheduleServer(
            (Request request) {
              try {
                request.hijack((stream) => {});
              } catch (_) {}
              return Response.ok();
            },
          );
          await _get();
          completer.complete();
        }, (error, stackTrace) {
          if (completer.isCompleted) return;
          completer.complete(error);
        }),
      );
      var error = await completer.future;
      expect(
        error,
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'The request has been hijacked by another handler (e.g., a WebSocket) '
              'but the HijackException was never thrown. If a request is hijacked '
              'then a HijackException is expected to be thrown.',
        ),
      );
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

  var response = await request.send().timeout(Duration(seconds: 1));
  return await http.Response.fromStream(response).timeout(Duration(seconds: 1));
}
