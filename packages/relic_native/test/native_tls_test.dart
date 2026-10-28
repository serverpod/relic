import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:relic_native/relic_native.dart';
import 'package:test/test.dart';

import 'package:test_utils/adapter_conformance.dart';
import 'package:web_socket/web_socket.dart' show TextDataReceived;

import 'native_test_helpers.dart';

/// The certificates test/certs/generate.sh writes.
NativeTls _tls(String leaf) => NativeTls.fromFiles(
  certificateChain: 'test/certs/${leaf}_cert.pem',
  privateKey: 'test/certs/${leaf}_key.pem',
);

/// A context that trusts the test CA and nothing else.
SecurityContext _trustTestCa() =>
    SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates('test/certs/ca_cert.pem');

/// A client that trusts the test CA and nothing else.
HttpClient _client() => HttpClient(context: _trustTestCa());

/// A raw TLS connection to [port] that trusts the test CA.
Future<SecureSocket> _secureConnect(int port) =>
    SecureSocket.connect('localhost', port, context: _trustTestCa());

/// Answers with the URL the request was addressed to.
Response _echoUrl(Request request) =>
    Response.ok(body: Body.fromString(request.url.toString()));

Future<String> _readString(HttpClientResponse response) =>
    response.cast<List<int>>().transform(utf8.decoder).join();

/// Writes [request] through `openssl s_client`, trusting the test CA, and
/// returns everything the server answers until it closes the connection.
Future<String> _opensslExchange(int port, String request) async {
  final client = await Process.start('openssl', [
    's_client',
    '-connect',
    'localhost:$port',
    '-CAfile',
    'test/certs/ca_cert.pem',
    '-verify_return_error',
    '-quiet',
    '-ign_eof',
  ]);
  client.stdin.write(request);
  await client.stdin.flush();
  final reply = await utf8
      .decodeStream(client.stdout)
      .timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          client.kill();
          return '';
        },
      );
  await client.exitCode;
  return reply;
}

void main() {
  RelicServer? server;
  late HttpClient client;

  setUp(() => client = _client());

  tearDown(() async {
    client.close(force: true);
    await server?.close(force: true);
    server = null;
  });

  Future<HttpClientResponse> get(String path) async {
    final request = await client.getUrl(
      Uri.https('localhost:${server!.port}', path),
    );
    return request.close();
  }

  test('Given an HTTPS server with an EC key, '
      'when a client sends two requests, '
      'then both answers arrive over one connection', () async {
    server = await serveNative(
      (_) => Response.ok(body: Body.fromString('hello')),
      tls: _tls('localhost'),
    );

    final first = await get('/a');
    expect(await _readString(first), 'hello');
    final second = await get('/b');
    expect(await _readString(second), 'hello');

    expect(second.connectionInfo!.localPort, first.connectionInfo!.localPort);
  });

  test('Given an HTTPS server whose handler watches cancelled, '
      'when a client sends a second request on the same connection, '
      'then the second answer arrives', () async {
    server = await serveNative((request) {
      unawaited(request.cancelled);
      return Response.ok(body: Body.fromString('hello'));
    }, tls: _tls('localhost'));

    final first = await get('/a');
    expect(await _readString(first), 'hello');
    final second = await get('/b');
    expect(await _readString(second), 'hello');

    expect(second.connectionInfo!.localPort, first.connectionInfo!.localPort);
  });

  test('Given an HTTPS server with an RSA key, '
      'when a client sends a request, '
      'then the answer arrives', () async {
    server = await serveNative(
      (_) => Response.ok(body: Body.fromString('hello')),
      tls: _tls('localhost_rsa'),
    );

    final response = await get('/');

    expect(response.statusCode, 200);
    expect(await _readString(response), 'hello');
  });

  test('Given an HTTPS server with an EC key in SEC 1 form, '
      'when a client sends a request, '
      'then the answer arrives.', () async {
    server = await serveNative(
      (_) => Response.ok(body: Body.fromString('hello')),
      tls: NativeTls.fromFiles(
        certificateChain: 'test/certs/localhost_cert.pem',
        privateKey: 'test/certs/localhost_sec1_key.pem',
      ),
    );

    final response = await get('/');

    expect(response.statusCode, 200);
    expect(await _readString(response), 'hello');
  });

  test('Given an HTTPS server whose chain runs through an intermediate, '
      'when a client that trusts only the root sends a request, '
      'then the answer arrives.', () async {
    server = await serveNative(
      (_) => Response.ok(body: Body.fromString('hello')),
      tls: NativeTls.fromFiles(
        certificateChain: 'test/certs/localhost_chain_cert.pem',
        privateKey: 'test/certs/localhost_key.pem',
      ),
    );

    final response = await get('/');

    expect(response.statusCode, 200);
    expect(await _readString(response), 'hello');
  });

  test('Given an HTTPS server with an Ed25519 key, '
      'when openssl sends a request, '
      'then the answer arrives.', () async {
    // Dart's client offers no ed25519 signature scheme, so openssl is the
    // client here.
    if ((await Process.run('openssl', ['version'])).exitCode != 0) {
      markTestSkipped('no openssl on the path');
      return;
    }
    server = await serveNative(
      (_) => Response.ok(body: Body.fromString('hello')),
      tls: _tls('localhost_ed25519'),
    );

    final reply = await _opensslExchange(
      server!.port,
      'GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
    );

    expect(reply, startsWith('HTTP/1.1 200 OK\r\n'));
    expect(reply, endsWith('\r\n\r\nhello'));
  });

  test('Given an encrypted private key file, '
      'when a server binds with it, '
      'then the bind throws a TlsException.', () async {
    final tls = NativeTls.fromFiles(
      certificateChain: 'test/certs/localhost_cert.pem',
      privateKey: 'test/certs/localhost_encrypted_key.pem',
    );

    await expectLater(
      NativeAdapter.bind(InternetAddress.loopbackIPv4, tls: tls),
      throwsA(
        isA<TlsException>().having(
          (e) => e.message,
          'message',
          contains('private key'),
        ),
      ),
    );
  });

  test('Given an HTTPS server, '
      'when a request arrives, '
      'then the handler sees an https URL', () async {
    server = await serveNative(_echoUrl, tls: _tls('localhost'));

    final response = await get('/p');

    expect(await _readString(response), 'https://localhost:${server!.port}/p');
  });

  test('Given an HTTPS server that pipes the request body into the response, '
      'when a client posts a body far over the inline limit, '
      'then the same bytes come back', () async {
    server = await serveNative(
      (req) => Response.ok(body: Body.fromDataStream(req.body.read())),
      options: const NativeOptions(maxInlineBody: 1024),
      tls: _tls('localhost'),
    );
    final sent = Uint8List.fromList(
      List.generate(1 << 20, (i) => (i * 7) & 0xff),
    );

    final request = await client.postUrl(
      Uri.https('localhost:${server!.port}', '/echo'),
    );
    request.contentLength = sent.length;
    request.add(sent);
    final response = await request.close();
    final received = await response.fold<BytesBuilder>(
      BytesBuilder(copy: false),
      (b, chunk) => b..add(chunk),
    );

    expect(received.takeBytes(), sent);
  });

  test('Given an HTTPS server with a WebSocket endpoint, '
      'when a client sends text over wss, '
      'then the echo comes back', () async {
    server = await serveNative(
      (_) => WebSocketUpgrade((ws) {
        ws.events.listen((event) {
          if (event is TextDataReceived) ws.sendText('echo ${event.text}');
        });
      }),
      tls: _tls('localhost'),
    );

    final ws = await WebSocket.connect(
      'wss://localhost:${server!.port}/ws',
      customClient: client,
    );
    ws.add('hi');

    expect(await ws.first, 'echo hi');
    await ws.close();
  });

  test('Given an HTTPS server whose handler hijacks and echoes, '
      'when the client sends bytes behind the request head, '
      'then they come back over TLS', () async {
    server = await serveNative(
      (_) => Hijack((channel) {
        channel.stream.listen(channel.sink.add, onDone: channel.sink.close);
      }),
      tls: _tls('localhost'),
    );
    final socket = await _secureConnect(server!.port);

    socket.write('GET / HTTP/1.1\r\nHost: localhost\r\n\r\nping');
    await socket.flush();
    final echoed = utf8.decode(
      await socket.first.timeout(const Duration(seconds: 5)),
    );
    socket.destroy();

    expect(echoed, 'ping');
  });

  test('Given an HTTPS server with a handler waiting on cancelled, '
      'when the peer hangs up, '
      'then cancelled completes while the handler still runs', () async {
    final sawCancel = Completer<void>();
    final release = Completer<void>();
    server = await serveNative((req) async {
      unawaited(req.cancelled.then((_) => sawCancel.complete()));
      await release.future;
      return Response.ok();
    }, tls: _tls('localhost'));
    final socket = await _secureConnect(server!.port);

    socket.write('GET / HTTP/1.1\r\nHost: localhost\r\n\r\n');
    await socket.flush();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    socket.destroy();

    await expectLater(
      sawCancel.future.timeout(const Duration(seconds: 3)),
      completes,
    );
    release.complete();
  });

  test('Given an HTTPS server, '
      'when a client speaks plain HTTP to it, '
      'then the server answers 400 in plain text and closes', () async {
    server = await serveNative(_echoUrl, tls: _tls('localhost'));

    final reply = await rawExchange(
      server!.port,
      'GET / HTTP/1.1\r\nHost: localhost\r\n\r\n',
    );

    expect(reply, startsWith('HTTP/1.1 400 Bad Request\r\n'));
  });

  test('Given an HTTPS server with an idle timeout, '
      'when a client connects and never sends a byte, '
      'then the server closes the connection', () async {
    server = await serveNative(
      _echoUrl,
      options: const NativeOptions(idleTimeout: Duration(milliseconds: 200)),
      tls: _tls('localhost'),
    );
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      server!.port,
    );

    final reply = await socket
        .fold<List<int>>([], (all, chunk) => all..addAll(chunk))
        .timeout(const Duration(seconds: 5));

    expect(reply, isEmpty);
    socket.destroy();
  });

  test('Given an HTTPS server with a header timeout, '
      'when a client sends one byte and stalls the handshake, '
      'then the server closes the connection', () async {
    server = await serveNative(
      _echoUrl,
      options: const NativeOptions(headerTimeout: Duration(milliseconds: 200)),
      tls: _tls('localhost'),
    );
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      server!.port,
    );

    // The content type of a handshake record, and nothing after it.
    socket.add(const [0x16]);
    await socket.flush();
    final reply = await socket
        .fold<List<int>>([], (all, chunk) => all..addAll(chunk))
        .timeout(const Duration(seconds: 5));

    expect(reply, isEmpty);
    socket.destroy();
  });

  test('Given an HTTPS server in a group, '
      'when a bind joins the group without tls, '
      'then the bind throws a StateError', () async {
    final group = 'relic_native/$pid/tls_mismatch';
    final secure = await NativeAdapter.bind(
      InternetAddress.loopbackIPv4,
      group: group,
      tls: _tls('localhost'),
    );
    addTearDown(secure.close);

    await expectLater(
      NativeAdapter.bind(InternetAddress.loopbackIPv4, group: group),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('with TLS'),
        ),
      ),
    );
  });

  test('Given a private key file that holds a certificate, '
      'when a server binds with it, '
      'then the bind throws a TlsException', () async {
    final tls = NativeTls.fromFiles(
      certificateChain: 'test/certs/localhost_cert.pem',
      privateKey: 'test/certs/localhost_cert.pem',
    );

    await expectLater(
      NativeAdapter.bind(InternetAddress.loopbackIPv4, tls: tls),
      throwsA(
        isA<TlsException>().having(
          (e) => e.message,
          'message',
          contains('private key'),
        ),
      ),
    );
  });

  test('Given a certificate chain whose certificate has expired, '
      'when a server binds with it, '
      'then the bind throws a TlsException.', () async {
    final tls = NativeTls.fromFiles(
      certificateChain: 'test/certs/localhost_expired_cert.pem',
      privateKey: 'test/certs/localhost_key.pem',
    );

    await expectLater(
      NativeAdapter.bind(InternetAddress.loopbackIPv4, tls: tls),
      throwsA(
        isA<TlsException>().having(
          (e) => e.message,
          'message',
          contains('certificate chain'),
        ),
      ),
    );
  });

  test('Given a certificate chain file that holds no certificate, '
      'when a server binds with it, '
      'then the bind throws a TlsException', () async {
    final tls = NativeTls.fromFiles(
      certificateChain: 'test/certs/localhost_key.pem',
      privateKey: 'test/certs/localhost_key.pem',
    );

    await expectLater(
      NativeAdapter.bind(InternetAddress.loopbackIPv4, tls: tls),
      throwsA(
        isA<TlsException>().having(
          (e) => e.message,
          'message',
          contains('certificate chain'),
        ),
      ),
    );
  });
}
