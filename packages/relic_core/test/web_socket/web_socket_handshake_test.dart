import 'dart:convert';

import 'package:relic_core/relic_core.dart';
import 'package:relic_core/src/context/result.dart' show RequestInternal;
import 'package:test/test.dart';

/// The key and accept value from RFC 6455 1.3.
const _rfcKey = 'dGhlIHNhbXBsZSBub25jZQ==';
const _rfcAccept = 's3pPLMBiTxaQ9kYGzzhZRbK+xOo=';

Request _request({
  Method method = Method.get,
  Map<String, String> headers = const {},
}) => RequestInternal.create(
  method,
  Uri.parse('http://localhost/chat'),
  null,
  headers: Headers.fromMap({
    'upgrade': ['websocket'],
    'connection': ['Upgrade'],
    'sec-websocket-version': ['13'],
    'sec-websocket-key': [_rfcKey],
    for (final MapEntry(:key, :value) in headers.entries) key: [value],
  }),
);

void main() {
  group('Given a WebSocket opening handshake', () {
    test('when it is the RFC 6455 example, '
        'then the accept key is the one from the RFC', () {
      expect(webSocketAcceptKey(_request()), _rfcAccept);
    });

    test('when the Connection header lists keep-alive and Upgrade, '
        'then it is accepted', () {
      final request = _request(headers: {'connection': 'keep-alive, Upgrade'});

      expect(webSocketAcceptKey(request), _rfcAccept);
    });

    test('when the method is POST, then it is refused', () {
      expect(webSocketAcceptKey(_request(method: Method.post)), isNull);
    });

    test('when the version is not 13, then it is refused', () {
      final request = _request(headers: {'sec-websocket-version': '8'});

      expect(webSocketAcceptKey(request), isNull);
    });

    test('when the key is not 16 bytes, then it is refused', () {
      final request = _request(
        headers: {
          'sec-websocket-key': base64.encode([1, 2, 3]),
        },
      );

      expect(webSocketAcceptKey(request), isNull);
    });

    test('when the key is not base64, then it is refused', () {
      final request = _request(headers: {'sec-websocket-key': 'not base64!'});

      expect(webSocketAcceptKey(request), isNull);
    });

    test('when Upgrade names another protocol, then it is refused', () {
      final request = _request(headers: {'upgrade': 'h2c'});

      expect(webSocketAcceptKey(request), isNull);
    });

    test('when Connection does not say Upgrade, then it is refused', () {
      final request = _request(headers: {'connection': 'keep-alive'});

      expect(webSocketAcceptKey(request), isNull);
    });
  });

  test('Given an accept key, when the response is written, '
      'then it is a 101 with the three handshake headers', () {
    final response = utf8.decode(webSocketHandshakeResponse(_rfcAccept));

    expect(response, startsWith('HTTP/1.1 101 Switching Protocols\r\n'));
    expect(response, contains('Upgrade: websocket\r\n'));
    expect(response, contains('Connection: Upgrade\r\n'));
    expect(response, contains('Sec-WebSocket-Accept: $_rfcAccept\r\n'));
    expect(response, endsWith('\r\n\r\n'));
  });
}
