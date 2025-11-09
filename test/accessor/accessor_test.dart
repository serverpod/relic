import 'package:relic/relic.dart';
import 'package:test/test.dart';

void main() {
  group('Given an AccessorState with raw values,', () {
    late AccessorState<String, String> state;

    setUp(() {
      state = AccessorState({'name': 'john', 'age': '25'});
    });

    test('when accessing a present key with [], '
        'then it returns the raw string value', () {
      const accessor = _StringAccessor('name');
      expect(state[accessor], equals('john'));
    });

    test('when accessing a missing key with [], '
        'then it returns null', () {
      const accessor = _StringAccessor('missing');
      expect(state[accessor], isNull);
    });

    test('when calling with a present key, '
        'then it returns the decoded value', () {
      const accessor = _IntAccessor('age');
      expect(state(accessor), equals(25));
    });

    test('when calling with a missing key, '
        'then it throws a StateError', () {
      const accessor = _IntAccessor('missing');
      expect(() => state(accessor), throwsStateError);
    });

    test('when calling get with a present key, '
        'then it returns the decoded value', () {
      const accessor = _IntAccessor('age');
      expect(state.get(accessor), equals(25));
    });

    test('when calling get with a missing key, '
        'then it returns null', () {
      const accessor = _IntAccessor('missing');
      expect(state.get(accessor), isNull);
    });

    test('when calling tryGet with a valid key, '
        'then it returns the decoded value', () {
      const accessor = _IntAccessor('age');
      expect(state.tryGet(accessor), equals(25));
    });

    test('when calling tryGet with a missing key, '
        'then it returns null', () {
      const accessor = _IntAccessor('missing');
      expect(state.tryGet(accessor), isNull);
    });
  });

  group('Given an AccessorState with an invalid value,', () {
    late AccessorState<String, String> state;

    setUp(() {
      state = AccessorState({'invalid': 'notanumber'});
    });

    test('when calling with an invalid value, '
        'then it throws a FormatException', () {
      const accessor = _IntAccessor('invalid');
      expect(() => state(accessor), throwsFormatException);
    });

    test('when calling get with an invalid value, '
        'then it throws a FormatException', () {
      const accessor = _IntAccessor('invalid');
      expect(() => state.get(accessor), throwsFormatException);
    });

    test('when calling tryGet with an invalid value, '
        'then it returns null', () {
      const accessor = _IntAccessor('invalid');
      expect(state.tryGet(accessor), isNull);
    });
  });

  group('Given an AccessorState with a valid value,', () {
    test('when the same const accessor is used multiple times, '
        'then the cached value is returned', () {
      const accessor = _CountAccessor('count');
      _CountAccessor.count = 0;
      final state = AccessorState({'count': '42'});

      final result1 = state.get(accessor);
      final result2 = state.get(accessor);
      final result3 = state(accessor);

      expect(result1?.value, equals(42));
      expect(result2?.value, equals(42));
      expect(result3.value, equals(42));
      expect(identical(result1, result2), isTrue);
      expect(identical(result2, result3), isTrue);
      expect(_CountAccessor.count, equals(1));
    });
  });
}

class _MyAccessor<T extends Object>
    extends ReadOnlyAccessor<T, String, String> {
  const _MyAccessor(super.key, super.decode);
}

T _identity<T>(final T o) => o;

class _StringAccessor extends _MyAccessor<String> {
  const _StringAccessor(final String key) : super(key, _identity);
}

class _IntAccessor extends _MyAccessor<int> {
  const _IntAccessor(final String key) : super(key, int.parse);
}

class Wrapped<T> {
  final T value;
  const Wrapped(this.value);
}

class _CountAccessor extends _MyAccessor<Wrapped<int>> {
  const _CountAccessor(final String key) : super(key, _decode);
  static int count = 0;
  static Wrapped<int> _decode(final String s) {
    ++count;
    return Wrapped(int.parse(s));
  }
}
