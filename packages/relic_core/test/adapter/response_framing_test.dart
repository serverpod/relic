import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

ResponseFraming _frame(
  final Response response, {
  final bool head = false,
  final HttpProtocol protocol = HttpProtocol.http11,
  final bool keepAlive = true,
}) => ResponseFraming.of(
  response,
  head: head,
  protocol: protocol,
  keepAlive: keepAlive,
);

Body _stream({final int? contentLength}) => Body.fromDataStream(
  Stream.value(Uint8List.fromList([1, 2, 3])),
  contentLength: contentLength,
);

Headers _transferEncoding(final List<TransferEncoding> codings) =>
    Headers.build(
      (final mh) =>
          mh.transferEncoding = TransferEncodingHeader.encodings(codings),
    );

void main() {
  test('Given a body with a type, when framed, '
      "then the Content-Type is the body's", () {
    final framing = _frame(
      Response.ok(body: Body.fromString('Relic', mimeType: MimeType.plainText)),
    );

    expect(framing.contentType, 'text/plain; charset=utf-8');
  });

  test('Given a body of known length, when framed, '
      'then the length is announced and nothing is chunked', () {
    final framing = _frame(Response.ok(body: _stream(contentLength: 3)));

    expect(framing.contentLength, 3);
    expect(framing.chunked, isFalse);
    expect(framing.transferEncoding, isNull);
  });

  test('Given a body of unknown length, when framed, '
      'then it is chunked', () {
    final framing = _frame(Response.ok(body: _stream()));

    expect(framing.contentLength, isNull);
    expect(framing.chunked, isTrue);
    expect(framing.transferEncoding, ['chunked']);
  });

  test('Given a handler-set Content-Length, when framed, '
      "then the body's length wins", () {
    final framing = _frame(
      Response.ok(
        body: Body.fromString('ok'),
        headers: Headers.build((final mh) => mh.contentLength = 99),
      ),
    );

    expect(framing.contentLength, 2);
    expect(ResponseFraming.isFramingHeader(HeaderName.contentLength), isTrue);
  });

  test('Given identity transfer coding and an unknown length, when framed, '
      'then nothing is chunked and the connection closes after', () {
    final framing = _frame(
      Response.ok(
        body: _stream(),
        headers: _transferEncoding([TransferEncoding.identity]),
      ),
    );

    expect(framing.chunked, isFalse);
    expect(framing.transferEncoding, ['identity']);
    expect(framing.closeAfter, isTrue);
  });

  test('Given chunked already set by the handler, when framed, '
      'then chunked appears once', () {
    final framing = _frame(
      Response.ok(
        body: _stream(),
        headers: _transferEncoding([TransferEncoding.chunked]),
      ),
    );

    expect(framing.transferEncoding, ['chunked']);
    expect(framing.chunked, isTrue);
  });

  test('Given another transfer coding and an unknown length, when framed, '
      'then chunked comes last', () {
    final framing = _frame(
      Response.ok(
        body: _stream(),
        headers: _transferEncoding([TransferEncoding.parse('gzip')]),
      ),
    );

    expect(framing.transferEncoding, ['gzip', 'chunked']);
  });

  test('Given another transfer coding and a known length, when framed, '
      'then Content-Length and Transfer-Encoding are not both announced', () {
    final framing = _frame(
      Response.ok(
        body: _stream(contentLength: 3),
        headers: _transferEncoding([TransferEncoding.parse('gzip')]),
      ),
    );

    expect(
      framing.contentLength == null || framing.transferEncoding == null,
      isTrue,
      reason:
          'RFC 9112 6.1: a message with Transfer-Encoding has no '
          'Content-Length',
    );
  });

  test('Given an HTTP/1.0 request and an unknown length, when framed, '
      'then nothing is chunked and the connection closes after', () {
    final framing = _frame(
      Response.ok(body: _stream()),
      protocol: HttpProtocol.http10,
    );

    expect(framing.chunked, isFalse);
    expect(framing.transferEncoding, isNull);
    expect(framing.closeAfter, isTrue);
  });

  for (final status in [100, 101, 102, 103, 204, 304]) {
    test('Given a $status, when framed, '
        'then no body, length or coding goes out', () {
      final framing = _frame(Response(status, body: _stream()));

      expect(framing.sendBody, isFalse);
      expect(framing.contentLength, isNull);
      expect(framing.transferEncoding, isNull);
    });
  }

  test('Given a HEAD request, when framed, '
      'then the length is announced and no body goes out', () {
    final framing = _frame(
      Response.ok(body: Body.fromString('Hello')),
      head: true,
    );

    expect(framing.sendBody, isFalse);
    expect(framing.contentLength, 5);
  });

  test('Given a multipart/byteranges body of unknown length, when framed, '
      'then it is not chunked', () {
    final framing = _frame(
      Response.ok(
        body: Body.fromDataStream(
          Stream.value(Uint8List(1)),
          mimeType: MimeType.multipartByteranges,
        ),
      ),
    );

    expect(framing.chunked, isFalse);
    expect(framing.closeAfter, isTrue);
  });

  test('Given a response without a Date, when framed, '
      'then a date is added, and not when it has one', () {
    final without = _frame(Response.ok());
    final with_ = _frame(
      Response.ok(
        headers: Headers.build(
          (final mh) => mh.date = DateTime.utc(2026, 10, 1),
        ),
      ),
    );

    expect(without.date, matches(RegExp(r'^[A-Z][a-z]{2}, \d\d ')));
    expect(with_.date, isNull);
  });

  test('Given Connection: close or a request without keep-alive, '
      'when framed, then the connection closes after', () {
    final byHeader = _frame(
      Response.ok(
        headers: Headers.build((final mh) => mh['connection'] = ['close']),
      ),
    );
    final byRequest = _frame(Response.ok(), keepAlive: false);

    expect(byHeader.closeAfter, isTrue);
    expect(byRequest.closeAfter, isTrue);
    expect(_frame(Response.ok()).closeAfter, isFalse);
  });
}
