import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  test('Given a body with open, when it is consumed, '
      'then its stream is never made.', () {
    var opened = 0;
    final body = Body(
      open: () {
        opened++;
        return Stream.value(Uint8List(1));
      },
    );

    body.consume();

    expect(opened, 0);
  });

  test('Given a body with open, when it is read, '
      'then it yields the stream it makes once.', () async {
    var opened = 0;
    final body = Body(
      open: () {
        opened++;
        return Stream.value(Uint8List.fromList([1, 2, 3]));
      },
    );

    final bytes = await body.read().expand((chunk) => chunk).toList();

    expect(bytes, [1, 2, 3]);
    expect(opened, 1);
  });

  test(
    'Given a body with open that was read, when it is read again, '
    'then it throws a StateError and its stream is not made again.',
    () async {
      var opened = 0;
      final body = Body(
        open: () {
          opened++;
          return Stream.value(Uint8List(1));
        },
      );
      await body.read().drain<void>();

      expect(body.read, throwsStateError);

      expect(opened, 1);
    },
  );

  test(
    'Given a body with open that was read, when it is consumed, '
    'then it throws a StateError and its stream is not made again.',
    () async {
      var opened = 0;
      final body = Body(
        open: () {
          opened++;
          return Stream.value(Uint8List(1));
        },
      );
      await body.read().drain<void>();

      expect(body.consume, throwsStateError);

      expect(opened, 1);
    },
  );

  test('Given a body with open that was consumed, when it is read, '
      'then it throws a StateError and its stream is never made.', () {
    var opened = 0;
    final body = Body(
      open: () {
        opened++;
        return Stream.value(Uint8List(1));
      },
    );
    body.consume();

    expect(body.read, throwsStateError);

    expect(opened, 0);
  });

  test('Given a body with open longer than maxLength, when it is read, '
      'then it throws MaxBodySizeExceeded and its stream is never made.', () {
    var opened = 0;
    final body = Body(
      open: () {
        opened++;
        return Stream.value(Uint8List(10));
      },
      contentLength: 10,
    );

    expect(() => body.read(maxLength: 5), throwsA(isA<MaxBodySizeExceeded>()));
    expect(opened, 0);
  });

  test('Given bytes and a stream, when a Body is built from both, '
      'then it throws ArgumentError', () {
    expect(
      () => Body(bytes: Uint8List(1), stream: const Stream.empty()),
      throwsArgumentError,
    );
  });
}
