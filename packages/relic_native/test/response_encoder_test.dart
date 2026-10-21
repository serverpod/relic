import 'dart:convert';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:relic_native/src/response_encoder.dart';
import 'package:test/test.dart';

/// The head as bytes of its own.
Uint8List _encodeResponseHead(Response response, {bool keepAlive = true}) {
  final framing = ResponseFraming.of(
    response,
    head: false,
    protocol: HttpProtocol.http11,
    keepAlive: keepAlive,
  );
  final head = ResponseHead(response, framing);
  final out = Uint8List(head.bound);
  return Uint8List.sublistView(out, 0, head.writeTo(out));
}

String _encode(Response response) =>
    latin1.decode(_encodeResponseHead(response));

void main() {
  test(
    'Given a plain text response, '
    'when the head is encoded, '
    'then it carries the status line, the content type, a date and the length',
    () {
      final head = _encode(Response.ok(body: Body.fromString('Hello')));
      expect(head, startsWith('HTTP/1.1 200 OK\r\n'));
      expect(head, contains('\r\ncontent-type: text/plain; charset=utf-8\r\n'));
      expect(head, matches(RegExp(r'\r\ndate: [A-Z][a-z]{2}, \d\d ')));
      expect(head, endsWith('\r\ncontent-length: 5\r\n\r\n'));
    },
  );

  test('Given a connection that closes after the response, '
      'when the head is encoded, then it carries Connection: close', () {
    final head = latin1.decode(
      _encodeResponseHead(
        Response.ok(body: Body.fromString('Hello')),
        keepAlive: false,
      ),
    );

    expect(head, contains('\r\nconnection: close\r\n'));
  });

  test('Given a connection that stays open after the response, '
      'when the head is encoded, then it carries no Connection header', () {
    final head = _encode(Response.ok(body: Body.fromString('Hello')));

    expect(head.toLowerCase(), isNot(contains('connection:')));
  });

  test('Given a response that sets Connection: close itself, '
      'when the head is encoded for a connection that closes, '
      'then the header goes out once', () {
    final head = latin1.decode(
      _encodeResponseHead(
        Response.ok(
          body: Body.fromString('Hello'),
          headers: Headers.build((mh) => mh['connection'] = ['close']),
        ),
        keepAlive: false,
      ),
    );

    expect('connection:'.allMatches(head.toLowerCase()), hasLength(1));
  });

  test('Given a response without a length, when the head is encoded, '
      'then it announces chunked transfer coding', () {
    final head = _encode(
      Response.ok(body: Body.fromDataStream(const Stream.empty())),
    );
    expect(head, endsWith('\r\ntransfer-encoding: chunked\r\n\r\n'));
  });

  test('Given a 204, when the head is encoded, '
      'then it has neither a length nor a transfer coding', () {
    final head = _encode(Response(204));
    expect(head, isNot(contains('content-length')));
    expect(head, isNot(contains('transfer-encoding')));
    expect(head, endsWith('\r\n\r\n'));
  });

  test('Given a response with its own Date header, '
      'when the head is encoded, '
      'then that date is the only one', () {
    final head = _encode(
      Response.ok(
        headers: Headers.build(
          (h) => h.date = DateTime.utc(2026, 10, 1, 12, 0, 0),
        ),
      ),
    );
    expect('date:'.allMatches(head).length, 1);
    expect(head, contains('date: Thu, 01 Oct 2026 12:00:00 GMT'));
  });

  test('Given a header value beyond Latin-1, when the head is encoded, '
      'then it is rejected', () {
    final response = Response.ok(
      headers: Headers.build(
        (h) => h[const HeaderName.custom('x-note')] = ['smørrebrød ☃'],
      ),
    );
    expect(() => _encode(response), throwsA(isA<ArgumentError>()));
  });

  test('Given a response with many headers, when the head is sized, '
      'then the bound covers what is written', () {
    final response = Response.ok(
      headers: Headers.build((h) {
        for (var i = 0; i < 20; i++) {
          h[HeaderName.custom('x-h$i')] = ['value $i', 'and $i again'];
        }
      }),
      body: Body.fromString('body'),
    );
    final head = ResponseHead(
      response,
      ResponseFraming.of(
        response,
        head: false,
        protocol: HttpProtocol.http11,
        keepAlive: true,
      ),
    );
    final out = Uint8List(head.bound);
    expect(head.writeTo(out), lessThanOrEqualTo(head.bound));
  });

  test('Given a large content length, when the head is encoded, '
      'then every digit is written', () {
    final head = _encode(
      Response.ok(
        body: Body.fromDataStream(
          const Stream.empty(),
          contentLength: 1234567890123,
        ),
      ),
    );
    expect(head, contains('content-length: 1234567890123\r\n'));
  });
}
