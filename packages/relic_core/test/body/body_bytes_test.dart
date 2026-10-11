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

  test('Given an ASCII string, when a body is made from it, '
      'then its bytes are the UTF-8 encoding.', () {
    final text = '{"host":"localhost","items":[1,2,3]}' * 40;
    final body = Body.fromString(text);

    expect(body.bytes, utf8.encode(text));
    expect(body.contentLength, text.length);
  });

  test(
    'Given a string that leaves ASCII after a kilobyte, '
    'when a body is made from it, then its bytes are the UTF-8 encoding.',
    () {
      final text = '${'a' * 1024}\u00e6\u{1F600}z';
      final body = Body.fromString(text);

      expect(body.bytes, utf8.encode(text));
      expect(body.contentLength, utf8.encode(text).length);
    },
  );

  test(
    'Given a string whose last character is non-ASCII, '
    'when a body is made from it, then its bytes are the UTF-8 encoding.',
    () {
      final text = '${'a' * 1024}\u00e6';
      final body = Body.fromString(text);

      expect(body.bytes, utf8.encode(text));
      expect(body.contentLength, 1026);
    },
  );

  test(
    'Given a string whose first character is non-ASCII, '
    'when a body is made from it, then its bytes are the UTF-8 encoding.',
    () {
      final text = '\u{1F600}${'a' * 100}';
      final body = Body.fromString(text);

      expect(body.bytes, utf8.encode(text));
      expect(body.contentLength, 104);
    },
  );

  test('Given a string with an unpaired surrogate after ASCII, '
      'when a body is made from it, '
      'then its bytes match utf8.encode including the replacement.', () {
    final text = '${'a' * 20}\uD83D';
    final body = Body.fromString(text);

    expect(body.bytes, utf8.encode(text));
    expect(body.bytes!.sublist(20), [0xEF, 0xBF, 0xBD]);
  });

  test('Given a Latin-1 encoding, when a body is made from a string, '
      'then its bytes are the Latin-1 encoding.', () {
    final body = Body.fromString('h\u00e9llo', encoding: latin1);

    expect(body.bytes, latin1.encode('h\u00e9llo'));
    expect(body.contentLength, 5);
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
