import 'package:relic/src/headers/codecs/common_types_codecs.dart';
import 'package:relic/src/headers/header_accessor.dart';
import 'package:relic/src/headers/headers.dart';
import 'package:test/test.dart';

import 'headers_test_utils.dart';

const _anInt = HeaderAccessor<int>(
  'anInt',
  HeaderCodec.single(parseInt, encodeInt),
);

const _someStrings = HeaderAccessor<List<String>>(
  'someStrings',
  HeaderCodec(parseStringList, encodeStringList),
);

class Custom {
  Custom();
  factory Custom.parse(String s) => Custom();
  static Iterable<String> encode(Custom c) => ['foo'];
}

const _customClass = HeaderAccessor<Custom>(
    'custom', HeaderCodec.single(Custom.parse, Custom.encode));

extension on Headers {
  int? get anInt => _anInt[this]();
  List<String>? get someStrings => _someStrings[this]();
}

extension on MutableHeaders {
  int? get anInt => _anInt[this]();
  set anInt(int? value) => _anInt[this].set(value);
}

void main() {
  test('Given a correct header then single values are parsed correctly', () {
    final headers = Headers.fromMap({
      'anInt': ['42']
    });
    expect(headers.anInt, isA<int>());
    expect(headers.anInt, 42);
  });

  test('Given a correct header then multi values are parsed correctly', () {
    final headers = Headers.fromMap({
      'someStrings': 'foo bar'.split(' '),
    });
    expect(headers.someStrings, isA<List<String>>());
    expect(headers.someStrings, ['foo', 'bar']);
  });

  group('Given an empty Headers collection', () {
    final headers = Headers.empty();
    final header = _anInt[headers];

    group('when accessing the header', () {
      test('it is not set', () {
        expect(_anInt.isSetIn(headers), isFalse);
        expect(header.isSet, isFalse);
      });
      test('it is invalid', () {
        expect(_anInt.isValidIn(headers), isFalse);
        expect(header.isValid, isFalse);
      });

      test('then access behaves as expected', () {
        expect(header.raw, isNull);
        expect(headers.anInt, isNull);
        expect(() => header.value, throwsMissingHeader);
        expect(header.valueOrNull, isNull);
        expect(header.valueOrNullIfInvalid, isNull);
      });
    });
  });

  group('Given a Headers collection with an invalid entry', () {
    late final headers = Headers.fromMap({
      'anInt': ['error']
    });
    late final header = _anInt[headers];

    group('when accessing the header', () {
      test('it is set', () {
        expect(_anInt.isSetIn(headers), isTrue);
        expect(header.isSet, isTrue);
      });
      test('it is invalid', () {
        expect(_anInt.isValidIn(headers), isFalse);
        expect(header.isValid, isFalse);
      });

      test('then access behaves as expected', () {
        expect(header.raw, ['error']);
        expect(() => headers.anInt, throwsInvalidHeader);
        expect(() => header.value, throwsInvalidHeader);
        expect(() => header.valueOrNull, throwsInvalidHeader);
        expect(header.valueOrNullIfInvalid, isNull);
      });
    });
  });

  test(
      'When setting a header on a mutable headers collection '
      'then it succeeds', () {
    final headers = Headers.build((mh) {
      expect(() => mh.anInt = 42, returnsNormally);
    });
    expect(headers.anInt, 42);
  });

  test(
      'Given a mutable headers collection '
      'When removing a header by setting to null '
      'then it succeeds', () {
    final headers = Headers.build((mh) {
      expect(() => mh.anInt = 42, returnsNormally);
    });
    expect(headers.anInt, 42);

    final headers2 = headers.transform((mh) => mh.anInt = null);

    expect(headers.anInt, 42); // still in original
    expect(headers2.anInt, isNull);
    expect(headers2, isNot(contains('anInt')));
  });

  test(
      'Given a mutable headers collection '
      'When removing a header using removeFrom '
      'then it succeeds', () {
    final headers = Headers.build((mh) {
      expect(() => mh.anInt = 42, returnsNormally);
    });
    expect(headers.anInt, 42);
    final headers2 = headers.transform((mh) => _anInt.removeFrom(mh));

    expect(headers.anInt, 42); // still in original
    expect(headers2.anInt, isNull);
    expect(headers2, isNot(contains('anInt')));
  });

  // TODO: Should we try to prevent this scenario compile time?
  test(
      'Given a immutable headers collection '
      'When trying to set a header '
      'then it fails', () {
    final headers = Headers.build((mh) {
      expect(() => mh.anInt = 42, returnsNormally);
    });
    final header = _anInt[headers];
    // This is compile error:
    //  headers.anInt = null;
    // but this uncommon approach will not fail until runtime:
    expect(() => header.set(null), throwsA(isA<TypeError>()));
  });

  test(
      'Given a header accessor '
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

  group('Given a header accessor ', () {
    late HeaderAccessor<int> accessor;
    int count = 0;

    setUp(() {
      count = 0;
      // This header accessor is not const constructed since we want
      // a non-const decoder that increment local the local variable count
      // whenever called. This is not good practice, but useful in the test!
      accessor = HeaderAccessor(
          'tmp',
          HeaderCodec.single((s) {
            ++count;
            return int.parse(s);
          }, encodeInt));
    });

    test(
        'when reading the value from a headers collection twice '
        'then decode is only called once', () {
      final headers = Headers.fromMap({
        accessor.key: ['1202']
      });

      expect(accessor[headers].value, 1202);
      expect(count, 1);

      expect(accessor[headers].value, 1202);
      expect(count, 1);
    });

    test(
        'when reading the value from a headers collection '
        'where the raw value is updated directly '
        'then decode is only called once per update', () {
      final headers = Headers.fromMap({
        accessor.key: ['1202']
      });
      final headers2 = headers.transform((mh) => mh[accessor.key] = ['42']);

      expect(accessor[headers].value, 1202);
      expect(count, 1);

      expect(accessor[headers2].value, 42);
      expect(count, 2);

      expect(accessor[headers].value, 1202);
      expect(accessor[headers2].value, 42);
      expect(count, 2);
    });

    test(
        'when reading the value from a headers collection '
        'where the encoded value is set via the accessor '
        'then decode is not needed at all', () {
      final headers = Headers.build((mh) => accessor[mh].set(51));
      expect(accessor[headers].value, 51);
      expect(count, 0);
    });
  });

  test(
      'Given a custom class '
      'then it is possible to setup header accessor for it with a custom encode',
      () {
    final c = Custom();
    final headers = Headers.build((mh) => _customClass[mh].set(c));
    expect(headers[_customClass.key], ['foo']);
    expect(_customClass[headers].raw, ['foo']);
    expect(_customClass[headers].value, same(c));
  });
}
