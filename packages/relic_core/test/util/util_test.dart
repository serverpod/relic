import 'dart:async';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  test('Given a Sink created with mapFrom, '
      'when adding events, '
      'then the mapped event is added to target sink', () {
    final controller = StreamController<int>();
    final sink = controller.mapFrom(int.parse);

    expectLater(
      controller.stream,
      emitsInOrder([
        42,
        emitsError(isA<FormatException>()),
        emitsError(isA<ArgumentError>()),
        1202,
        emitsDone,
      ]),
    );

    sink.add('42');
    sink.add('not a number');
    sink.addError(ArgumentError());
    sink.add('1202');
    sink.close();
  });
}
