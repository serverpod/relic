import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';
import 'package:test_utils/adapter_conformance.dart';

import 'native_test_helpers.dart';

/// The names a request can carry with a dummy value and still be framed
/// as an empty GET that closes after the answer.
final _names = [
  for (final name in HeaderName.known)
    if (name != HeaderName.host &&
        name != HeaderName.connection &&
        name != HeaderName.contentLength &&
        name != HeaderName.contentEncoding &&
        name != HeaderName.transferEncoding &&
        name != HeaderName.expect)
      name,
];

/// Answers with the request's names, and `!` after a known one whose
/// object is not the constant of its id.
Response _echoNames(Request request) => Response.ok(
  body: Body.fromString(
    [
      for (final name in request.headers.names)
        name.id < 0 || identical(name, HeaderName.known[name.id])
            ? name.lower
            : '${name.lower}!',
    ].join(','),
  ),
);

void main() {
  late RelicServer server;

  setUp(() async {
    server = await serveNative(_echoNames);
  });

  tearDown(() => server.close(force: true));

  test('Given a request with every known name, when the names are read, '
      'then each is the constant of its id, in wire order', () async {
    final head = StringBuffer(
      'GET / HTTP/1.1\r\nHost: a\r\nConnection: close\r\n',
    );
    for (final name in _names) {
      head.write('${name.lower.toUpperCase()}: v\r\n');
    }
    head.write('\r\n');

    final reply = await rawExchange(server.port, head.toString());

    expect(reply, contains(' 200 '));
    expect(
      splitHead(reply).body,
      ['host', 'connection', for (final name in _names) name.lower].join(','),
    );
  });

  test('Given a request with a name outside the table, when read, '
      'then it is found by its text among the known ones', () async {
    final reply = await rawExchange(
      server.port,
      'GET / HTTP/1.1\r\nHost: a\r\nX-Custom: 1\r\nCookie: a=1\r\n'
      'Connection: close\r\n\r\n',
    );

    expect(splitHead(reply).body, 'host,x-custom,cookie,connection');
  });
}
