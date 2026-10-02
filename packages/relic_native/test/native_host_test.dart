import 'dart:io';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';
import 'package:test_utils/adapter_conformance.dart';

import 'native_test_helpers.dart';

/// Answers with the URL the request was addressed to.
Response _echoUrl(Request request) =>
    Response.ok(body: Body.fromString(request.url.toString()));

void main() {
  late RelicServer server;

  Future<void> serve(InternetAddress address) async {
    server = await serveNative(_echoUrl, address: address);
  }

  tearDown(() => server.close(force: true));

  Future<String> send(InternetAddress address, String head) =>
      rawExchange(server.port, head, address: address);

  test('Given a server on the IPv6 loopback, when a request has no Host, '
      'then the URL names the bracketed listener', () async {
    await serve(InternetAddress.loopbackIPv6);

    final reply = await send(
      InternetAddress.loopbackIPv6,
      'GET /p HTTP/1.0\r\n\r\n',
    );

    expect(reply, contains(' 200 '));
    expect(reply, endsWith('http://[::1]:${server.port}/p'));
  });

  test('Given an HTTP/1.1 request without a Host, when it is sent, '
      'then the server answers 400', () async {
    await serve(InternetAddress.loopbackIPv4);

    final reply = await send(
      InternetAddress.loopbackIPv4,
      'GET /p HTTP/1.1\r\nConnection: close\r\n\r\n',
    );

    expect(reply, startsWith('HTTP/1.1 400'));
  });

  test('Given a request with two Host fields, when it is sent, '
      'then the server answers 400', () async {
    await serve(InternetAddress.loopbackIPv4);

    final reply = await send(
      InternetAddress.loopbackIPv4,
      'GET /p HTTP/1.1\r\nHost: a.example\r\nHost: b.example\r\n'
      'Connection: close\r\n\r\n',
    );

    expect(reply, startsWith('HTTP/1.1 400'));
  });

  test('Given a Host with an unterminated bracket, when it is sent, '
      'then the server answers 400', () async {
    await serve(InternetAddress.loopbackIPv4);

    final reply = await send(
      InternetAddress.loopbackIPv4,
      'GET / HTTP/1.1\r\nHost: [::1\r\nConnection: close\r\n\r\n',
    );

    expect(reply, startsWith('HTTP/1.1 400'));
  });

  test('Given an unbracketed IPv6 Host with a port, when it is sent, '
      'then the server answers 400', () async {
    await serve(InternetAddress.loopbackIPv4);

    final reply = await send(
      InternetAddress.loopbackIPv4,
      'GET / HTTP/1.1\r\nHost: ::1:8080\r\nConnection: close\r\n\r\n',
    );

    expect(reply, startsWith('HTTP/1.1 400'));
  });

  test('Given a Host whose port is not a number, when it is sent, '
      'then the server answers 400', () async {
    await serve(InternetAddress.loopbackIPv4);

    final reply = await send(
      InternetAddress.loopbackIPv4,
      'GET / HTTP/1.1\r\nHost: a:b\r\nConnection: close\r\n\r\n',
    );

    expect(reply, startsWith('HTTP/1.1 400'));
  });

  test('Given a bracketed IPv6 Host with a port, when it is sent, '
      'then the URL carries it', () async {
    await serve(InternetAddress.loopbackIPv4);

    final reply = await send(
      InternetAddress.loopbackIPv4,
      'GET /p HTTP/1.1\r\nHost: [::1]:8080\r\nConnection: close\r\n\r\n',
    );

    expect(reply, endsWith('http://[::1]:8080/p'));
  });

  test('Given a Host with an empty value, when it is sent, '
      'then the server answers 400', () async {
    await serve(InternetAddress.loopbackIPv4);

    final reply = await send(
      InternetAddress.loopbackIPv4,
      'GET /p HTTP/1.1\r\nHost:\r\nConnection: close\r\n\r\n',
    );

    expect(reply, startsWith('HTTP/1.1 400'));
  });
}
