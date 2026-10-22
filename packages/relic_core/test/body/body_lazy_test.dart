import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  test('Given a lazy body, when it is consumed, '
      'then its stream is never made.', () {
    var opened = 0;
    final body = Body.lazy(() {
      opened++;
      return Stream.value(Uint8List(1));
    });

    body.consume();

    expect(opened, 0);
  });

  test('Given a lazy body, when it is read, '
      'then it yields the stream it makes once.', () async {
    var opened = 0;
    final body = Body.lazy(() {
      opened++;
      return Stream.value(Uint8List.fromList([1, 2, 3]));
    });

    final bytes = await body.read().expand((chunk) => chunk).toList();

    expect(bytes, [1, 2, 3]);
    expect(opened, 1);
  });

  test(
    'Given a lazy body that was read, when it is read again, '
    'then it throws a StateError and its stream is not made again.',
    () async {
      var opened = 0;
      final body = Body.lazy(() {
        opened++;
        return Stream.value(Uint8List(1));
      });
      await body.read().drain<void>();

      expect(body.read, throwsStateError);

      expect(opened, 1);
    },
  );

  test(
    'Given a lazy body that was read, when it is consumed, '
    'then it throws a StateError and its stream is not made again.',
    () async {
      var opened = 0;
      final body = Body.lazy(() {
        opened++;
        return Stream.value(Uint8List(1));
      });
      await body.read().drain<void>();

      expect(body.consume, throwsStateError);

      expect(opened, 1);
    },
  );

  test('Given a lazy body that was consumed, when it is read, '
      'then it throws a StateError and its stream is never made.', () {
    var opened = 0;
    final body = Body.lazy(() {
      opened++;
      return Stream.value(Uint8List(1));
    });
    body.consume();

    expect(body.read, throwsStateError);

    expect(opened, 0);
  });
}
