import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:relic_core/src/context/result.dart' show requestFactory;
import 'package:test/fake.dart';
import 'package:test/test.dart';

final class _FakeExchange extends Fake implements AdapterExchange {
  @override
  HttpProtocol get protocol => HttpProtocol.http11;
}

Request _request({required String contentType, required Body body}) =>
    requestFactory(
      Method.post,
      _FakeExchange(),
      url: Uri.parse('http://localhost/'),
      headers: Headers.fromMap({
        'content-type': [contentType],
      }),
      body: body,
    );

Body _content() => Body(bytes: Uint8List.fromList([104, 105]));

void main() {
  test('Given an untyped body with content and a Content-Type, '
      'when the factory builds the request, '
      'then the body has the type of the header.', () {
    final request = _request(
      contentType: 'text/plain; charset=utf-8; foo=bar',
      body: _content(),
    );

    final type = request.body.bodyType!;
    expect(type.mimeType, MimeType.plainText);
    expect(type.encoding?.name, 'utf-8');
    expect(type.parameters, {'foo': 'bar'});
  });

  test('Given an untyped body with content, '
      'when the factory builds the request, '
      'then the request carries the body it was given.', () {
    final body = _content();

    final request = _request(contentType: 'text/plain', body: body);

    expect(request.body, same(body));
  });

  test('Given a streamed body of unknown length and a Content-Type, '
      'when the factory builds the request, '
      'then the body has the type of the header.', () {
    final request = _request(
      contentType: 'application/json',
      body: Body(stream: const Stream.empty()),
    );

    expect(request.body.bodyType?.mimeType, MimeType.json);
  });

  test('Given an empty body and a Content-Type, '
      'when the factory builds the request, '
      'then the body has no type.', () {
    final request = _request(contentType: 'text/plain', body: Body.empty());

    expect(request.body.bodyType, isNull);
  });

  test('Given a body the adapter typed and another Content-Type, '
      'when the factory builds the request, '
      'then the body keeps the type of the adapter.', () {
    final request = _request(
      contentType: 'text/plain',
      body: Body(
        bytes: Uint8List.fromList([123, 125]),
        bodyType: BodyType(mimeType: MimeType.json),
      ),
    );

    expect(request.body.bodyType?.mimeType, MimeType.json);
  });

  test('Given a body with content and a Content-Type that does not parse, '
      'when the factory builds the request, '
      'then it throws InvalidHeaderException.', () {
    expect(
      () => _request(contentType: ';;;', body: _content()),
      throwsA(isA<InvalidHeaderException>()),
    );
  });

  test('Given an empty body and a Content-Type that does not parse, '
      'when the factory builds the request, '
      'then the request is built with no body type.', () {
    final request = _request(contentType: ';;;', body: Body.empty());

    expect(request.body.bodyType, isNull);
  });
}
