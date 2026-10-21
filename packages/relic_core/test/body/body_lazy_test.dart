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
}
