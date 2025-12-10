import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('Given a mutable headers collection', () {
    late MutableHeaders mutable;
    setUp(() {
      mutable = MutableHeaders();
      mutable['1'] = ['a'];
      mutable['2'] = ['b'];
      mutable['3'] = ['c'];
    });
    test('when assigning null to a key '
        'then the value disappear', () {
      expect(mutable['1'], isNotNull);
      expect(mutable..remove('1'), {
        '2': ['b'],
        '3': ['c'],
      });
    });
    test('when removing a key '
        'then the value is removed', () {
      expect(() => mutable['2'] = null, returnsNormally);
      expect(mutable, {
        '1': ['a'],
        '3': ['c'],
      });
    });
    test('when accessing keys '
        'then all keys are returned', () {
      expect(mutable.keys, ['1', '2', '3']);
    });
    test('when clearing '
        'then all values is removed', () {
      expect(() => mutable.clear(), returnsNormally);
      expect(mutable, MutableHeaders());
    });
  });

  test('When assigning a value during Headers.build '
      'then its present in the returned headers collection', () {
    final headers = Headers.build((final mh) {
      mh['foo'] = ['bar'];
    });
    expect(headers['foo'], ['bar']);
  });
}
