import 'dart:math';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

const _knownNames = [
  'content-type',
  'content-length',
  'host',
  'cookie',
  'user-agent',
  'accept',
  'set-cookie',
];
const _customNames = ['x-custom', 'x-request-trace', 'x-b3-spanid'];

/// The same fields as an adapter would index them and as a map store
/// holds them.
(ByteHeaderStore, MapHeaderStore) _both(List<(String, String)> fields) {
  final map = MapHeaderStore();
  for (final (name, value) in fields) {
    map.add(HeaderName.lookup(name), value);
  }
  return (ByteHeaderStore.encode(fields), map);
}

String _randomCase(Random random, String s) => [
  for (final c in s.split('')) random.nextBool() ? c.toUpperCase() : c,
].join();

void main() {
  test('Given random header sets with repeats and case variants, '
      'when read through both stores, then they agree', () {
    final random = Random(42);
    for (var round = 0; round < 200; round++) {
      final fields = <(String, String)>[];
      final count = random.nextInt(12);
      for (var i = 0; i < count; i++) {
        final names = random.nextBool() ? _knownNames : _customNames;
        final name = _randomCase(random, names[random.nextInt(names.length)]);
        fields.add((name, 'v${random.nextInt(1000)}'));
      }
      final (bytes, map) = _both(fields);

      expect(bytes.fieldCount, map.fieldCount, reason: '$fields');
      expect(bytes.names, map.names, reason: '$fields');
      for (final name in [..._knownNames, ..._customNames]) {
        final key = HeaderName.lookup(name);
        expect(bytes.value(key), map.value(key), reason: '$name in $fields');
        expect(bytes.values(key), map.values(key), reason: '$name in $fields');
        expect(bytes.contains(key), map.contains(key));
      }
      final seenBytes = <String>[];
      final seenMap = <String>[];
      bytes.forEach((n, v) => seenBytes.add('$n: $v'));
      map.forEach((n, v) => seenMap.add('$n: $v'));
      expect(seenBytes, seenMap);
    }
  });

  group('Given a byte store with a known, a custom and a repeated field', () {
    late ByteHeaderStore store;

    setUp(() {
      store = ByteHeaderStore.encode(const [
        ('Content-Type', 'text/plain'),
        ('X-Custom', 'one'),
        ('Set-Cookie', 'a=1'),
        ('set-cookie', 'b=2'),
      ]);
    });

    test('when names are read, then they are interned and distinct', () {
      expect(store.names, [
        HeaderName.contentType,
        HeaderName.lookup('x-custom'),
        HeaderName.setCookie,
      ]);
      expect(store.names.first, same(HeaderName.contentType));
    });

    test('when rawValue is read, then it is a view of the value bytes', () {
      final raw = store.rawValue(HeaderName.contentType)!;
      expect(String.fromCharCodes(raw), 'text/plain');
      // A view, not a copy. A write through the head shows in it.
      store.bytes[raw.offsetInBytes] = 'T'.codeUnitAt(0);
      expect(String.fromCharCodes(raw), 'Text/plain');
    });

    test('when rawValue is read for an absent name, then it is null', () {
      expect(store.rawValue(HeaderName.accept), isNull);
    });

    test('when values is read twice, then the same list comes back', () {
      expect(
        store.values(HeaderName.setCookie),
        same(store.values(HeaderName.setCookie)),
      );
    });

    test('when a value is read twice, then the same string comes back', () {
      expect(
        store.value(HeaderName.contentType),
        same(store.value(HeaderName.contentType)),
      );
    });

    test('when toMutable is called, then the copy holds every field', () {
      final copy = store.toMutable();
      expect(copy.values(HeaderName.setCookie), ['a=1', 'b=2']);
      expect(copy.value(HeaderName.lookup('x-custom')), 'one');
    });
  });

  test('Given a value with bytes at or above 0x80, when read, '
      'then it decodes as Latin-1', () {
    final store = ByteHeaderStore.encode(const [('X-Name', 'café ÿ')]);
    expect(store.value(HeaderName.lookup('x-name')), 'café ÿ');
  });

  test('Given encoded fields, when the slots are read, '
      'then a known name carries its id and an unknown one -1', () {
    final store = ByteHeaderStore.encode(const [
      ('Content-Type', 'text/plain'),
      ('X-Custom', 'one'),
    ]);
    expect(store.slots[1], HeaderName.contentType.id);
    expect(store.slots[5], -1);
  });

  test('Given a slot table from an adapter, when a known name is read, '
      'then the name comes from the id and not from the bytes', () {
    // The bytes spell x-custom where the slot says content-type, as a
    // parser that has already matched the name would leave them.
    final encoded = ByteHeaderStore.encode(const [('x-custom', 'one')]);
    final slots = Int32List.fromList(encoded.slots)
      ..[1] = HeaderName.contentType.id;
    final store = ByteHeaderStore(encoded.bytes, slots);
    expect(store.names, [HeaderName.contentType]);
    expect(store.value(HeaderName.contentType), 'one');
    expect(store.value(HeaderName.lookup('x-custom')), isNull);
  });

  test('Given an empty head, when read, then there is nothing', () {
    final store = ByteHeaderStore.encode(const []);
    expect(store.fieldCount, 0);
    expect(store.names, isEmpty);
    expect(store.value(HeaderName.host), isNull);
    expect(store.values(HeaderName.host), isEmpty);
  });

  test('Given a byte store with a known header, '
      'when it is read by a custom name that spells it, '
      'then the value is found', () {
    final store = ByteHeaderStore.encode([('Host', 'example.com')]);

    expect(store.value(const HeaderName.custom('host')), 'example.com');
    expect(store.contains(const HeaderName.custom('host')), isTrue);
  });
}
