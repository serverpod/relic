import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  test('Given a body from a string, when its bytes are read, '
      'then they are the encoded string and the body is still unread.', () {
    final body = Body.fromString('héllo');

    expect(body.bytes, utf8.encode('héllo'));
    expect(body.contentLength, body.bytes!.length);
    expect(body.read, returnsNormally);
  });

  test('Given a body from data, when its bytes are read, '
      'then they are the same object.', () {
    final data = Uint8List.fromList([1, 2, 3]);
    final body = Body.fromData(data);

    expect(body.bytes, same(data));
  });

  test(
    'Given a streamed body, when its bytes are read, then they are null.',
    () {
      final body = Body.fromDataStream(Stream.value(Uint8List(3)));

      expect(body.bytes, isNull);
    },
  );

  test('Given a body from data, when readAll is called, '
      'then it returns the bytes without a Future and reads the body.', () {
    final body = Body.fromData(Uint8List.fromList([1, 2, 3]));

    final all = body.readAll();

    expect(all, isA<Uint8List>());
    expect(all, [1, 2, 3]);
    expect(body.read, throwsStateError);
  });

  test('Given a streamed body, when readAll is called, '
      'then it collects the chunks.', () async {
    final body = Body.fromDataStream(
      Stream.fromIterable([
        Uint8List.fromList([1, 2]),
        Uint8List.fromList([3]),
      ]),
    );

    final all = body.readAll();

    expect(all, isA<Future<Uint8List>>());
    expect(await all, [1, 2, 3]);
  });

  test('Given a body from data over the limit, when readAll is called, '
      'then it throws MaxBodySizeExceeded.', () {
    final body = Body.fromData(Uint8List(10));

    expect(
      () => body.readAll(maxLength: 5),
      throwsA(isA<MaxBodySizeExceeded>()),
    );
  });

  test('Given a streamed body over the limit, when readAll is called, '
      'then it fails with MaxBodySizeExceeded.', () async {
    final body = Body.fromDataStream(Stream.value(Uint8List(10)));

    await expectLater(
      Future.sync(() => body.readAll(maxLength: 5)),
      throwsA(isA<MaxBodySizeExceeded>()),
    );
  });

  test('Given an unread body, when it is consumed, '
      'then it counts as read and a read fails.', () {
    final body = Body.fromData(Uint8List.fromList([1, 2, 3]));

    body.consume();

    expect(body.isRead, isTrue);
    expect(body.read, throwsStateError);
  });

  test('Given a body that was read, when it is consumed, '
      'then it fails with a StateError.', () {
    final body = Body.fromData(Uint8List.fromList([1, 2, 3]));
    body.read();

    expect(body.consume, throwsStateError);
  });
}
