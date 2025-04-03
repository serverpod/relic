import 'package:relic/src/headers/header_accessor.dart';
import 'package:relic/src/headers/headers.dart';
import 'package:relic/src/headers/parser/common_types_parser.dart';
import 'package:test/test.dart';

import 'headers_test_utils.dart';

const _anInt = HeaderAccessor<int>(
  'anInt',
  HeaderDecoderSingle(intParseAndCount),
);

const _someStrings = HeaderAccessor<List<String>>(
  'someStrings',
  HeaderDecoderMulti(parseStringList),
);

var _count = 0;
int intParseAndCount(String s) {
  ++_count;
  return int.parse(s);
}

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
      'when updating a value '
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

  test(
      'Given a header accessor '
      'when reading the value '
      'then decode is only called if raw value changed', () {
    final headers = Headers.fromMap({
      'anInt': ['102']
    });

    final offset = _count;
    int decodeCount() => _count - offset; // compensate for previous calls

    expect(headers.anInt, 102); // read first time
    expect(decodeCount(), 1); // one call to parse

    expect(headers.anInt, 102); // read again
    expect(decodeCount(), 1); // still only one call to parse, due to cache

    // update raw value directly
    final headers2 = headers.transform((mh) => mh['anInt'] = ['1202']);

    expect(headers.anInt, 102); // read first again
    expect(decodeCount(), 1); // still only one call to parse, due to cache

    expect(headers2.anInt, 1202); // read second first time
    expect(decodeCount(), 2); // parse called once more

    // update through header accessor
    final headers3 = headers.transform((mh) => mh.anInt = 51);

    expect(headers.anInt, 102); // read first again
    expect(decodeCount(), 2); // still only two call to parse, due to cache

    expect(headers2.anInt, 1202); // read second again
    expect(decodeCount(), 2); // still only two call to parse, due to cache

    // read third first time - count will not be affected, since update done
    // through accessor that updated the cache immediately
    expect(headers3.anInt, 51);
    expect(decodeCount(), 2); // still only two call to parse, due to cache
  });
}
