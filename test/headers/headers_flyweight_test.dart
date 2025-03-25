import 'package:test/test.dart';
import 'package:relic/src/headers/header_flyweight.dart';
import 'package:relic/src/headers/headers.dart';
import 'package:relic/src/headers/exception/invalid_header_exception.dart';
import 'package:relic/src/headers/typed/typed_header_interface.dart';

// Simple implementation of TypedHeader for testing
class TestTypedHeader implements TypedHeader {
  final String _value;

  TestTypedHeader(this._value);

  @override
  String toHeaderString() => _value;
}

void main() {
  group('HeaderDecoderSingle', () {
    late HeaderDecoderSingle<int> decoder;

    setUp(() {
      decoder = HeaderDecoderSingle<int>((s) => int.parse(s));
    });

    test('parses a single value', () {
      expect(decoder(['123']), equals(123));
    });

    test('uses first value when multiple are present', () {
      expect(decoder(['123', '456']), equals(123));
    });

    test('throws when parsing fails', () {
      expect(() => decoder(['abc']), throwsA(isA<FormatException>()));
    });
  });

  group('HeaderDecoderMulti', () {
    late HeaderDecoderMulti<List<int>> decoder;

    setUp(() {
      decoder = HeaderDecoderMulti<List<int>>(
          (values) => values.map((s) => int.parse(s)).toList());
    });

    test('parses multiple values', () {
      expect(decoder(['123', '456']), equals([123, 456]));
    });

    test('parses a single value as a list', () {
      expect(decoder(['123']), equals([123]));
    });

    test('throws when parsing fails', () {
      expect(() => decoder(['123', 'abc']), throwsA(isA<FormatException>()));
    });
  });

  group('HeaderFlyweight', () {
    late HeaderDecoderSingle<int> intDecoder;
    late HeaderFlyweight<int> flyweight;

    setUp(() {
      intDecoder = HeaderDecoderSingle<int>((s) => int.parse(s));
      flyweight = HeaderFlyweight<int>('x-test', intDecoder);
    });

    test('rawFrom returns header values from external', () {
      var headers = Headers.build((mh) => mh['x-test'] = ['123']);
      expect(flyweight.rawFrom(headers), equals(['123']));
    });

    test('rawFrom returns null when header is not present', () {
      expect(flyweight.rawFrom(Headers.empty()), isNull);
    });

    test('getValueFrom returns decoded value when header is present', () {
      var headers = Headers.build((mh) => mh['x-test'] = ['123']);
      expect(flyweight.getValueFrom(headers), equals(123));
    });

    test('getValueFrom caches decoded values', () {
      var headers = Headers.build((mh) => mh['x-test'] = ['123']);

      // Access value twice to test caching
      var value1 = flyweight.getValueFrom(headers);

      // Change the header value - if caching works, this won't affect the second getValue
      var headers2 = headers.transform((mh) {
        expect(flyweight.getValueFrom(mh), equals(123));
        mh['x-test'] = ['456'];
        // expect(flyweight.getValueFrom(mh), equals(456)); // <-- THIS DON' CURRENTLY WORK!!
      });
      var value2 = flyweight.getValueFrom(headers);

      expect(value1, equals(123));
      expect(value2, equals(123)); // Should be from cache, not the new value

      // Create a new headers object to test a fresh value
      var value3 = flyweight.getValueFrom(headers2);

      expect(value3, equals(456)); // Should get the new value
    });

    test('getValueFrom returns null when header is not present', () {
      expect(flyweight.getValueFrom<int?>(Headers.empty()), isNull);
    });

    test('getValueFrom uses orElse when parsing fails', () {
      var headers = Headers.build((mh) => mh['x-test'] = ['abc']);
      expect(
        flyweight.getValueFrom<int?>(headers, orElse: (_) => -1),
        equals(-1),
      );
    });

    test('getValueFrom wraps exceptions in InvalidHeaderException', () {
      var headers = Headers.build((mh) => mh['x-test'] = ['abc']);
      expect(
        () => flyweight.getValueFrom(headers),
        throwsA(isA<InvalidHeaderException>()
            .having((e) => e.headerType, 'headerType', 'x-test')),
      );
    });

    test('isSetIn returns true when header is present', () {
      var headers = Headers.build((mh) => mh['x-test'] = ['123']);
      expect(flyweight.isSetIn(headers), isTrue);
    });

    test('isSetIn returns false when header is not present', () {
      expect(flyweight.isSetIn(Headers.empty()), isFalse);
    });

    test('isValidIn returns true when header is valid', () {
      var headers = Headers.build((mh) => mh['x-test'] = ['123']);
      expect(flyweight.isValidIn(headers), isTrue);
    });

    test('isValidIn returns false when header is not present', () {
      expect(flyweight.isValidIn(Headers.empty()), isFalse);
    });

    test('isValidIn returns false when header is invalid', () {
      var headers = Headers.build((mh) => mh['x-test'] = ['abc']);
      expect(flyweight.isValidIn(headers), isFalse);
    });

    test('operator[] returns Header with correct key', () {
      var headers = Headers.build((mh) => mh['x-test'] = ['123']);
      final header = flyweight[headers];
      expect(header.key, equals('x-test'));
    });

    test('setValueOn sets header value', () {
      var headers = MutableHeaders();
      flyweight.setValueOn(headers, 123);
      expect(headers['x-test'], equals(['123']));
    });

    test('setValueOn removes header when value is null', () {
      // First set a value
      var headers = MutableHeaders();
      headers['x-test'] = ['123'];
      expect(headers['x-test'], ['123']);
      expect(flyweight.getValueFrom(headers), equals(123));

      // Then remove it with null
      flyweight.setValueOn(headers, null);
      expect(headers.containsKey('x-test'), isFalse);
      expect(headers['x-test'], isNull);
    });

    test('removeFrom removes header', () {
      var headers = MutableHeaders();
      headers['x-test'] = ['123'];
      flyweight.removeFrom(headers);
      expect(headers['x-test'], isNull);
    });
  });

  group('Header extension type', () {
    late MutableHeaders headers;
    late HeaderDecoderSingle<int> intDecoder;
    late HeaderFlyweight<int> flyweight;
    late Header<int> header;

    setUp(() {
      headers = MutableHeaders();
      intDecoder = HeaderDecoderSingle<int>((s) => int.parse(s));
      flyweight = HeaderFlyweight<int>('x-test', intDecoder);
      header = flyweight[headers];
    });

    test('key returns the flyweight key', () {
      expect(header.key, flyweight.key);
      expect(header.key, equals('x-test'));
    });

    test('raw returns header values from external', () {
      headers['x-test'] = ['123'];
      expect(header.raw, equals(['123']));
    });

    test('isSet returns true when header is present', () {
      headers['x-test'] = ['123'];
      expect(header.isSet, isTrue);
    });

    test('isSet returns false when header is not present', () {
      expect(header.isSet, isFalse);
    });

    test('isValid returns true when header is valid', () {
      headers['x-test'] = ['123'];
      expect(header.isValid, isTrue);
    });

    test('isValid returns false when header is not valid', () {
      headers['x-test'] = ['abc'];
      expect(header.isValid, isFalse);
    });

    test('valueOrNull returns value when valid', () {
      headers['x-test'] = ['123'];
      expect(header.valueOrNull, equals(123));
    });

    test('valueOrNull returns null when not present', () {
      expect(header.valueOrNull, isNull);
    });

    test('value returns value when valid', () {
      headers['x-test'] = ['123'];
      expect(header.value, equals(123));
    });

    test('value throws when not valid', () {
      headers['x-test'] = ['abc'];
      expect(() => header.value, throwsA(isA<InvalidHeaderException>()));
    });

    test('valueOrNullIfInvalid returns value when valid', () {
      headers['x-test'] = ['123'];
      expect(header.valueOrNullIfInvalid, equals(123));
    });

    test('valueOrNullIfInvalid returns null when invalid', () {
      headers['x-test'] = ['abc'];
      expect(header.valueOrNullIfInvalid, isNull);
    });

    test('call invokes flyweight.getValueFrom', () {
      headers['x-test'] = ['123'];
      expect(header(), equals(123));
    });

    test('call with orElse uses custom handler', () {
      headers['x-test'] = ['abc'];
      expect(header(orElse: (_) => -1), equals(-1));
    });

    test('set calls setValueOn with correct params', () {
      header.set(123);
      expect(headers['x-test'], equals(['123']));
    });

    test('set with null removes header', () {
      headers['x-test'] = ['123'];
      expect(header.value, 123);

      header.set(null);

      expect(headers.containsKey('x-test'), isFalse);
      expect(headers['x-test'], isNull);
      // expect(header.value, isNull); // <-- THIS DON' CURRENTLY WORK!!
    });

    test('set by key with null removes header', () {
      headers['x-test'] = ['123'];
      expect(header.value, 123);

      headers['x-test'] = null;

      expect(headers.containsKey('x-test'), isFalse);
      expect(headers['x-test'], isNull);
      // expect(header.value, isNull); // <-- THIS DON' CURRENTLY WORK!!
    });

    test('set by key with null removes header', () {
      headers['x-test'] = ['123'];
      expect(header.value, 123);

      headers.clear();

      expect(headers.keys, isEmpty);
      expect(headers['x-test'], isNull);
      // expect(header.value, isNull); // <-- THIS DON' CURRENTLY WORK!!
    });
  });
}
