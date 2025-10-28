import 'dart:async';

import 'package:relic/src/isolated_object.dart';
import 'package:test/test.dart';

void main() {
  test('Given a synchronous factory, '
      'when IsolatedObject is created, '
      'then it successfully initializes', () async {
    final isolated = IsolatedObject<_Counter>(() => _Counter(0));

    // Verify it's usable by evaluating a simple operation
    final result = await isolated.evaluate((final counter) => counter.value);
    expect(result, 0);

    await isolated.close();
  });

  test('Given an async factory, '
      'when IsolatedObject is created, '
      'then it successfully initializes', () async {
    final isolated = IsolatedObject<_Counter>(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return _Counter(42);
    });

    final result = await isolated.evaluate((final counter) => counter.value);
    expect(result, 42);

    await isolated.close();
  });

  test('Given a factory that throws, '
      'when IsolatedObject is created, '
      'then subsequent operations fail gracefully', () async {
    final isolated = IsolatedObject<_Counter>(() {
      throw Exception('Factory failed');
    });

    expect(
      () => isolated.evaluate((final counter) => counter.value),
      throwsA(anything),
    );
  });
}

class _Counter {
  int value;
  _Counter(this.value);

  void add(final int amount) => value += amount;
  void increment() => value++;
}
