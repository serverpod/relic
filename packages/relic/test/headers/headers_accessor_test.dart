import 'package:relic/relic.dart';
import 'package:test/test.dart';

import 'headers_test_utils.dart';

const _anInt = HeaderAccessor<int>(
  HeaderName.custom('anint'),
  HeaderCodec.single(parseInt, encodeInt),
);

const _someStrings = HeaderAccessor<List<String>>(
  HeaderName.custom('somestrings'),
  HeaderCodec(parseStringList, encodeStringList),
);

class Custom {
  Custom();
  factory Custom.parse(String s) => Custom();
  static Iterable<String> encode(Custom c) => ['foo'];
}

const _customClass = HeaderAccessor<Custom>(
  HeaderName.custom('custom'),
  HeaderCodec.single(Custom.parse, Custom.encode),
);

extension on HeaderValues {
  int? get anInt => this(_anInt);
  List<String>? get someStrings => this(_someStrings);
}

extension on MutableHeaders {
  // Dart picks an extension by member name, so a setter-only extension on
  // MutableHeaders would hide the getter above. Declare both.
  int? get anInt => this(_anInt);
  set anInt(int? value) => assign(_anInt, value);
}

void main() {
  test('Given a correct header then single values are parsed correctly', () {
    final headers = Headers.fromMap({
      'anInt': ['42'],
    });
    expect(headers.anInt, isA<int>());
    expect(headers.anInt, 42);
  });

  test('Given a correct header then multi values are parsed correctly', () {
    final headers = Headers.fromMap({'someStrings': 'foo bar'.split(' ')});
    expect(headers.someStrings, isA<List<String>>());
    expect(headers.someStrings, ['foo', 'bar']);
  });

  group('Given an empty Headers collection', () {
    final headers = Headers.empty();

    test('when the header is looked up, then it is absent', () {
      expect(headers.contains(_anInt.key), isFalse);
      expect(headers[_anInt], isNull);
      expect(headers.anInt, isNull);
    });

    test('when the header is read, '
        'then call and tryGet are null and get throws', () {
      expect(headers(_anInt), isNull);
      expect(headers.tryGet(_anInt), isNull);
      expect(() => headers.get(_anInt), throwsMissingHeader);
    });
  });

  group('Given a Headers collection with an invalid entry', () {
    final headers = Headers.fromMap({
      'anInt': ['error'],
    });

    test('when the header is looked up, then it is present', () {
      expect(headers.contains(_anInt.key), isTrue);
      expect(headers[_anInt], ['error']);
    });

    test('when the header is read, '
        'then call and get throw and tryGet is null', () {
      expect(() => headers.anInt, throwsInvalidHeader);
      expect(() => headers(_anInt), throwsInvalidHeader);
      expect(() => headers.get(_anInt), throwsInvalidHeader);
      expect(headers.tryGet(_anInt), isNull);
    });
  });

  test('When setting a header on a mutable headers collection '
      'then it succeeds', () {
    final headers = Headers.build((mh) {
      expect(() => mh.anInt = 42, returnsNormally);
    });
    expect(headers.anInt, 42);
  });

  test('Given a mutable headers collection '
      'When removing a header by setting to null '
      'then it succeeds', () {
    final headers = Headers.build((mh) {
      expect(() => mh.anInt = 42, returnsNormally);
    });
    expect(headers.anInt, 42);

    final headers2 = headers.transform((mh) => mh.anInt = null);

    expect(headers.anInt, 42); // still in original
    expect(headers2.anInt, isNull);
    expect(headers2.contains(_anInt.key), isFalse);
  });

  test('Given a mutable headers collection '
      'When removing a header through the accessor '
      'then it succeeds', () {
    final headers = Headers.build((mh) {
      expect(() => mh.anInt = 42, returnsNormally);
    });
    expect(headers.anInt, 42);
    final headers2 = headers.transform((mh) => mh.remove(_anInt));

    expect(headers.anInt, 42); // still in original
    expect(headers2.anInt, isNull);
    expect(headers2.contains(_anInt.key), isFalse);
  });

  test('Given a header accessor '
      'when updating a value on a mutable headers collection '
      'then you can read the value immediately', () {
    Headers.build((mh) {
      mh.anInt = 42;
      expect(mh.anInt, 42);
      mh.anInt = 1202;
      expect(mh.anInt, 1202);
      mh['anInt'] = ['51']; // also for raw value updates
      expect(mh.anInt, 51);
    });
  });

  group('Given a header accessor that counts decodes', () {
    late HeaderAccessor<int> accessor;
    int count = 0;

    setUp(() {
      count = 0;
      // Not const, so the decoder can count into a local.
      accessor = HeaderAccessor(
        const HeaderName.custom('tmp'),
        HeaderCodec.single((s) {
          ++count;
          return int.parse(s);
        }, encodeInt),
      );
    });

    test('when reading the value from a headers collection twice '
        'then decode is only called once', () {
      final headers = Headers.fromMap({
        accessor.key.lower: ['1202'],
      });

      expect(headers.get(accessor), 1202);
      expect(count, 1);

      expect(headers.get(accessor), 1202);
      expect(count, 1);
    });

    test(
      'when reading the value from a headers collection where the raw value is updated directly '
      'then decode is only called once per update',
      () {
        final headers = Headers.fromMap({
          accessor.key.lower: ['1202'],
        });
        final headers2 = headers.transform((mh) => mh[accessor.key] = ['42']);

        expect(headers.get(accessor), 1202);
        expect(count, 1);

        expect(headers2.get(accessor), 42);
        expect(count, 2);

        expect(headers.get(accessor), 1202);
        expect(headers2.get(accessor), 42);
        expect(count, 2);
      },
    );

    test(
      'when reading the value from a headers collection where the encoded value is set via the accessor '
      'then decode is not needed at all',
      () {
        final headers = Headers.build((mh) => mh.assign(accessor, 51));
        expect(headers.get(accessor), 51);
        expect(count, 0);
      },
    );
  });

  test(
    'Given a custom class '
    'then it is possible to setup header accessor for it with a custom encode',
    () {
      final c = Custom();
      final headers = Headers.build((mh) => mh.assign(_customClass, c));
      expect(headers[_customClass.key], ['foo']);
      expect(headers[_customClass], ['foo']);
      expect(headers.get(_customClass), same(c));
    },
  );
}
