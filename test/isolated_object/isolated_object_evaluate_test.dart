import 'dart:async';
import 'dart:isolate';

import 'package:relic/src/isolated_object.dart';
import 'package:test/test.dart';

void main() {
  group('evaluate', () {
    late IsolatedObject<_Counter> isolated;

    setUp(() {
      isolated = IsolatedObject<_Counter>(() => _Counter(0));
    });

    tearDown(() async {
      await isolated.close();
    });

    test(
        'Given an IsolatedObject, '
        'when evaluate is called with a getter, '
        'then it returns the correct value', () async {
      final result = await isolated.evaluate((final counter) => counter.value);
      expect(result, 0);
    });

    test(
        'Given an IsolatedObject, '
        'when evaluate is called with a mutation, '
        'then the state persists across evaluations', () async {
      await isolated.evaluate((final counter) {
        counter.increment();
        return null;
      });

      final result = await isolated.evaluate((final counter) => counter.value);
      expect(result, 1);
    });

    test(
        'Given an IsolatedObject, '
        'when evaluate is called multiple times sequentially, '
        'then all operations execute correctly', () async {
      await isolated.evaluate((final counter) => counter.increment());
      await isolated.evaluate((final counter) => counter.increment());
      await isolated.evaluate((final counter) => counter.increment());

      final result = await isolated.evaluate((final counter) => counter.value);
      expect(result, 3);
    });

    test(
        'Given an IsolatedObject, '
        'when evaluate is called with multiple concurrent operations, '
        'then all operations complete successfully', () async {
      final futures = List.generate(
        10,
        (final i) => isolated.evaluate((final counter) => counter.increment()),
      );

      await Future.wait(futures);

      final result = await isolated.evaluate((final counter) => counter.value);
      expect(result, 10);
    });

    test(
        'Given an IsolatedObject, '
        'when evaluate is called with different return types, '
        'then it returns the correct types', () async {
      final intResult =
          await isolated.evaluate<int>((final counter) => counter.value);
      expect(intResult, isA<int>());
      expect(intResult, 0);

      final stringResult = await isolated
          .evaluate<String>((final counter) => 'Value: ${counter.value}');
      expect(stringResult, isA<String>());
      expect(stringResult, 'Value: 0');

      final boolResult =
          await isolated.evaluate<bool>((final counter) => counter.value > 0);
      expect(boolResult, isA<bool>());
      expect(boolResult, false);
    });

    test(
        'Given an IsolatedObject, '
        'when evaluate is called with async function, '
        'then it awaits the result correctly', () async {
      await isolated.evaluate((final counter) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        counter.increment();
      });

      final result = await isolated.evaluate((final counter) => counter.value);
      expect(result, 1);
    });

    test(
        'Given an IsolatedObject, '
        'when evaluate is called with a function returning complex objects, '
        'then it returns the correct data', () async {
      final result = await isolated.evaluate((final counter) {
        return {
          'value': counter.value,
          'doubled': counter.value * 2,
          'info': 'Counter state',
        };
      });

      expect(result, isA<Map<String, dynamic>>());
      expect(result['value'], 0);
      expect(result['doubled'], 0);
      expect(result['info'], 'Counter state');
    });

    test(
        'Given an IsolatedObject, '
        'when evaluate is called with a void function, '
        'then it executes the function without returning a value', () async {
      await isolated.evaluate((final counter) => counter.increment());

      final result = await isolated.evaluate((final counter) => counter.value);
      expect(result, 1);
    });

    test(
        'Given an IsolatedObject, '
        'when evaluate is called with a void function that throws, '
        'then it propagates the error', () async {
      expect(
        () => isolated.evaluate((final counter) {
          throw Exception('Test error');
        }),
        throwsA(isA<RemoteError>()),
      );
    });
  });

  group('close', () {
    test(
        'Given an IsolatedObject, '
        'when close is called, '
        'then it shuts down the isolate', () async {
      final isolated = IsolatedObject<_Counter>(() => _Counter(0));

      // Verify it works before closing
      final result = await isolated.evaluate((final counter) => counter.value);
      expect(result, 0);

      await isolated.close();

      // After closing, new operations should fail or timeout
      expect(
        () => isolated
            .evaluate((final counter) => counter.value)
            .timeout(const Duration(milliseconds: 500)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test(
        'Given an IsolatedObject, '
        'when close is called multiple times, '
        'then it handles it gracefully', () async {
      final isolated = IsolatedObject<_Counter>(() => _Counter(0));

      await isolated.close();
      await isolated.close(); // Second close should not throw

      // Should not throw
      expect(true, isTrue);
    });
  });

  group('error handling', () {
    test(
        'Given an IsolatedObject, '
        'when a function throws in the isolate, '
        'then RemoteError contains error information', () async {
      final isolated = IsolatedObject<_Counter>(() => _Counter(0));

      try {
        await isolated.evaluate((final counter) {
          throw StateError('Custom error message');
        });
      } catch (e) {
        expect(e, isA<RemoteError>());
        final remoteError = e as RemoteError;
        expect(remoteError.toString(), contains('Custom error message'));
      } finally {
        await isolated.close();
      }
    });

    test(
        'Given an IsolatedObject, '
        'when an error occurs, '
        'then subsequent operations still work', () async {
      final isolated = IsolatedObject<_Counter>(() => _Counter(5));

      // First operation throws
      try {
        await isolated.evaluate((final counter) {
          throw Exception('First error');
        });
      } catch (_) {
        // Expected
      }

      // Second operation should still work
      final result = await isolated.evaluate((final counter) => counter.value);
      expect(result, 5);

      await isolated.close();
    });
  });

  group('concurrent operations', () {
    test(
        'Given an IsolatedObject, '
        'when many operations are queued concurrently, '
        'then all complete with unique IDs', () async {
      final isolated = IsolatedObject<_Counter>(() => _Counter(0));

      // Queue many operations concurrently
      final futures = <Future<int>>[];
      for (var i = 0; i < 100; i++) {
        futures.add(isolated.evaluate((final counter) {
          counter.increment();
          return counter.value;
        }));
      }

      final results = await Future.wait(futures);

      // All operations should complete
      expect(results.length, 100);

      // Final value should be 100
      final finalValue =
          await isolated.evaluate((final counter) => counter.value);
      expect(finalValue, 100);

      await isolated.close();
    });

    test(
        'Given an IsolatedObject, '
        'when concurrent operations include some that throw, '
        'then successful operations still complete', () async {
      final isolated = IsolatedObject<_Counter>(() => _Counter(0));

      // Mix of successful and failing operations
      const ops = 10;
      try {
        await [
          for (var i = 0; i < ops; i++)
            i % 2 == 0 // even succeeds, odd fails
                ? isolated.evaluate((final counter) => counter.increment())
                : isolated.evaluate((final _) => throw Exception('Error $i'))
        ].wait;
      } on ParallelWaitError<List, List<AsyncError?>> catch (e) {
        expect(e.errors.nonNulls.length, ops / 2); // half fails
        expect(e.values.nonNulls.length, ops / 2); // half succeeds
      }

      final result = await isolated.evaluate((final counter) => counter.value);
      expect(result, ops / 2); // only half succeeded

      await isolated.close();
    });
  });

  group('complex objects', () {
    test(
        'Given an IsolatedObject with a complex state object, '
        'when operations modify nested state, '
        'then changes persist correctly', () async {
      final isolated = IsolatedObject<_ComplexObject>(() => _ComplexObject());

      await isolated.evaluate((final obj) {
        obj.data['key1'] = 'value1';
        obj.data['key2'] = 'value2';
      });

      final result = await isolated.evaluate((final obj) => obj.data);
      expect(result, {'key1': 'value1', 'key2': 'value2'});

      await isolated.close();
    });

    test(
        'Given an IsolatedObject with state, '
        'when evaluating functions that return lists, '
        'then lists are correctly transferred', () async {
      final isolated = IsolatedObject<_ComplexObject>(() => _ComplexObject());

      await isolated.evaluate((final obj) {
        obj.items.addAll([1, 2, 3, 4, 5]);
      });

      final result = await isolated.evaluate((final obj) => obj.items);
      expect(result, [1, 2, 3, 4, 5]);

      await isolated.close();
    });
  });
}

// Test helper classes
class _Counter {
  int value;
  _Counter(this.value);

  void increment() => value++;
  void add(final int amount) => value += amount;
}

class _ComplexObject {
  final Map<String, dynamic> data = {};
  final List<int> items = [];

  _ComplexObject();
}
