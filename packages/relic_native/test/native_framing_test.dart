import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';
import 'package:test_utils/adapter_conformance.dart';

import 'native_test_helpers.dart';

Response _ok(Request _) => Response.ok(body: Body.fromString('ok'));

void main() {
  late RelicServer server;

  setUp(() async => server = await serveNative(_ok));
  tearDown(() => server.close(force: true));

  Future<String> send(String head) => rawExchange(server.port, head);

  test('Given a head with bare LF line endings, when it is sent, '
      'then the server answers 400 and closes', () async {
    final reply = await send('GET / HTTP/1.1\nHost: x\n\n');

    expect(reply, startsWith('HTTP/1.1 400'));
  });

  test('Given a head whose last line ends in a bare LF, when it is sent, '
      'then the server answers 400 and closes', () async {
    final reply = await send('GET / HTTP/1.1\r\nHost: x\r\n\n');

    expect(reply, startsWith('HTTP/1.1 400'));
  });

  test('Given a method relic has no Method for, when it is sent, '
      'then the server answers 400 and closes', () async {
    final reply = await send('QUERY / HTTP/1.1\r\nHost: x\r\n\r\n');

    expect(reply, startsWith('HTTP/1.1 400'));
  });

  test('Given a header line with no colon, when it is sent, '
      'then the server answers 400 and closes', () async {
    final reply = await send('GET / HTTP/1.1\r\nHost: x\r\nD\r\n\r\n');

    expect(reply, startsWith('HTTP/1.1 400'));
  });

  test('Given a folded header line, when it is sent, '
      'then the server answers 400 and closes', () async {
    final reply = await send('GET / HTTP/1.1\r\nHost: x\r\n y\r\n\r\n');

    expect(reply, startsWith('HTTP/1.1 400'));
  });

  test('Given a request target with a space, when it is sent, '
      'then the server answers 400 and closes', () async {
    final reply = await send('GET /a b HTTP/1.1\r\nHost: x\r\n\r\n');

    expect(reply, startsWith('HTTP/1.1 400'));
  });

  test('Given a request target with raw UTF-8, when it is sent, '
      'then the server answers 400 and closes', () async {
    final reply = await send('GET /café HTTP/1.1\r\nHost: x\r\n\r\n');

    expect(reply, startsWith('HTTP/1.1 400'));
  });

  test('Given an empty request target, when it is sent, '
      'then the server answers 400 and closes', () async {
    final reply = await send('GET  HTTP/1.1\r\nHost: x\r\n\r\n');

    expect(reply, startsWith('HTTP/1.1 400'));
  });

  test('Given a percent-encoded request target, when it is sent, '
      'then the request is served', () async {
    final reply = await send(
      'GET /caf%C3%A9?q=a%20b HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n',
    );

    expect(reply, startsWith('HTTP/1.1 200'));
  });

  test('Given a Content-Length with a sign, when it is sent, '
      'then the server answers 400 and closes', () async {
    final reply = await send(
      'POST / HTTP/1.1\r\nHost: x\r\nContent-Length: +2\r\n\r\nhi',
    );

    expect(reply, startsWith('HTTP/1.1 400'));
  });

  test('Given a Content-Length with a digit separator, when it is sent, '
      'then the server answers 400 and closes', () async {
    final reply = await send(
      'POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 1_0\r\n\r\n0123456789',
    );

    expect(reply, startsWith('HTTP/1.1 400'));
  });

  test('Given a Content-Length of digits, when it is sent, '
      'then the request is served', () async {
    final reply = await send(
      'POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 2\r\n'
      'Connection: close\r\n\r\nhi',
    );

    expect(reply, startsWith('HTTP/1.1 200'));
  });

  test('Given a CRLF framed head, when it is sent, '
      'then the request is served', () async {
    final reply = await send(
      'GET / HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n',
    );

    expect(reply, startsWith('HTTP/1.1 200'));
    expect(reply, endsWith('ok'));
  });
}
