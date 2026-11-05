import 'dart:io';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import 'conformance.dart';

Response _ok(Request request) => Response.ok(body: Body.fromString('ok'));

void addressTests(AdapterConformance conformance) {
  RelicServer? server;

  tearDown(() async {
    await server?.close(force: true);
    server = null;
  });

  test('Given a server on any IPv6 address, '
      'when a request arrives over the IPv4 loopback, '
      'then the server answers', () async {
    server = await conformance.serve(_ok, address: InternetAddress.anyIPv6);

    final reply = await rawExchange(
      server!.port,
      'GET / HTTP/1.0\r\nHost: localhost\r\n\r\n',
      address: InternetAddress.loopbackIPv4,
    );

    expect(reply, contains(' 200 '));
  });

  test('Given a listening server, '
      'when a second server binds its port, '
      'then the bind throws SocketException', () async {
    server = await conformance.serve(_ok);
    final second = conformance.create(port: server!.port);

    await expectLater(
      second.mountAndStart(_ok),
      throwsA(isA<SocketException>()),
    );
  });

  test('Given a server on any IPv6 address with v6Only, '
      'when a client connects over the IPv4 loopback, '
      'then the connection is refused', () async {
    server = await conformance.serve(
      _ok,
      address: InternetAddress.anyIPv6,
      v6Only: true,
    );

    await expectLater(
      Socket.connect(InternetAddress.loopbackIPv4, server!.port),
      throwsA(isA<SocketException>()),
    );
  });
}
