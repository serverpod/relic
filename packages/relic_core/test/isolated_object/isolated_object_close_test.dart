import 'dart:async';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  test('Given an IsolatedObject, '
      'when close is called multiple times, '
      'then it handles it gracefully', () async {
    final isolated = IsolatedObject<_Counter>(() => _Counter(0));

    await isolated.close();
    await isolated.close(); // Second close should not throw

    // Should not throw
    expect(true, isTrue);
  });

  test('Given an IsolatedObject with pending operations, '
      'when the channel is closed, '
      'then pending operations fail with channel closed error', () async {
    final isolated = IsolatedObject<_Counter>(() => _Counter(0));

    // Start a long-running operation
    final pendingOperation = isolated.evaluate((final counter) async {
      await Future<void>.delayed(const Duration(seconds: 10));
      return counter.value;
    });

    // Give the operation time to start and register as inflight
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Close the isolate while the operation is still pending
    await isolated.close();

    // The pending operation should fail with StateError
    await expectLater(
      pendingOperation,
      throwsA(
        isA<StateError>().having(
          (final e) => e.message,
          'message',
          contains('channel closed'),
        ),
      ),
    );
  });
}

// Test helper classes
class _Counter {
  int value;
  _Counter(this.value);

  void increment() => value++;
  void add(final int amount) => value += amount;
}
