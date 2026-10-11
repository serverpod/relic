import 'package:relic_headers/relic_headers.dart';
import 'package:test/test.dart';

final _custom = HeaderName.lookup('x-custom');

void main() {
  group('Given a MapHeaderStore with three fields', () {
    late MapHeaderStore store;

    setUp(() {
      store = MapHeaderStore()
        ..set(HeaderName.host, ['example.com'])
        ..set(HeaderName.setCookie, ['a=1', 'b=2'])
        ..set(_custom, ['x']);
    });

    test('when names are read, then they come in insertion order', () {
      expect(store.names, [HeaderName.host, HeaderName.setCookie, _custom]);
    });

    test('when fieldCount is read, then every value counts', () {
      expect(store.fieldCount, 4);
    });

    test('when value is read, then the first value is returned', () {
      expect(store.value(HeaderName.setCookie), 'a=1');
      expect(store.value(HeaderName.accept), isNull);
    });

    test('when values is read, then every value is returned', () {
      expect(store.values(HeaderName.setCookie), ['a=1', 'b=2']);
      expect(store.values(HeaderName.accept), isEmpty);
    });

    test('when values is read twice, then the same object comes back', () {
      expect(
        store.values(HeaderName.setCookie),
        same(store.values(HeaderName.setCookie)),
      );
    });

    test('when contains is asked, then presence is reported', () {
      expect(store.contains(HeaderName.host), isTrue);
      expect(store.contains(HeaderName.accept), isFalse);
    });

    test('when forEach visits, then every pair is visited in order', () {
      final seen = <String>[];
      store.forEach((name, value) => seen.add('$name=$value'));
      expect(seen, [
        'host=example.com',
        'set-cookie=a=1',
        'set-cookie=b=2',
        'x-custom=x',
      ]);
    });

    test('when a value is added, then it is appended', () {
      store.add(HeaderName.setCookie, 'c=3');
      expect(store.values(HeaderName.setCookie), ['a=1', 'b=2', 'c=3']);
    });

    test(
      'when a value is added to a new name, then the field appears last',
      () {
        store.add(HeaderName.accept, '*/*');
        expect(store.names.last, HeaderName.accept);
        expect(store.values(HeaderName.accept), ['*/*']);
      },
    );

    test('when a field is set to no values, then it is removed', () {
      store.set(HeaderName.host, const []);
      expect(store.contains(HeaderName.host), isFalse);
    });

    test('when a field is removed, then it is gone', () {
      store.remove(HeaderName.setCookie);
      expect(store.names, [HeaderName.host, _custom]);
    });

    test('when cleared, then nothing is left', () {
      store.clear();
      expect(store.names, isEmpty);
      expect(store.fieldCount, 0);
    });

    test('when toMutable is called, '
        'then the copy has the fields and is independent', () {
      final copy = store.toMutable();
      copy.remove(HeaderName.host);
      expect(copy.contains(HeaderName.host), isFalse);
      expect(store.contains(HeaderName.host), isTrue);
    });

    test('when the values list is modified, then it throws', () {
      expect(
        () => (store.values(HeaderName.host) as List<String>).add('x'),
        throwsUnsupportedError,
      );
    });
  });

  test('Given a map of fields with mixed-case keys, '
      'when a store is built from it, '
      'then names are looked up and merged case-insensitively', () {
    final store = MapHeaderStore.from({
      'Content-Type': ['text/plain'],
      'X-Custom': ['1'],
    });
    expect(store.value(HeaderName.contentType), 'text/plain');
    expect(store.value(HeaderName.lookup('x-custom')), '1');
  });

  for (final injected in [
    'a\r\nX-Injected: 1',
    'a\nX-Injected: 1',
    'a\rx',
    'a\x00x',
  ]) {
    final shown = injected
        .replaceAll('\r', r'\r')
        .replaceAll('\n', r'\n')
        .replaceAll('\x00', r'\0');
    test('Given a value with "$shown", when it is set, '
        'then a FormatException is thrown', () {
      expect(
        () => MapHeaderStore().set(_custom, [injected]),
        throwsFormatException,
      );
      expect(
        () => MapHeaderStore().add(_custom, injected),
        throwsFormatException,
      );
    });
  }

  test('Given a value with a tab and Latin-1 text, when it is set, '
      'then it is accepted', () {
    final store = MapHeaderStore()..set(_custom, ['a\tb é']);
    expect(store.value(_custom), 'a\tb é');
  });

  test('Given a map store with a known header, '
      'when it is read by a custom name that spells it, '
      'then the value is found', () {
    final store = MapHeaderStore()..set(HeaderName.host, ['example.com']);

    expect(store.value(const HeaderName.custom('host')), 'example.com');
    expect(store.contains(const HeaderName.custom('host')), isTrue);
  });
}
