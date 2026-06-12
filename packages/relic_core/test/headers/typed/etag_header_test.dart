import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('ETagHeader.parse', () {
    group('Given a strong etag,', () {
      test('when parsed, '
          'then the opaque-tag and weak flag are recovered.', () {
        final etag = ETagHeader.parse('"abc"');

        expect(etag.value, equals('abc'));
        expect(etag.isWeak, isFalse);
      });
    });

    group('Given a weak etag,', () {
      test('when parsed, '
          'then isWeak is true.', () {
        expect(ETagHeader.parse('W/"abc"').isWeak, isTrue);
      });
    });

    group('Given an interior double-quote in the opaque-tag,', () {
      test('when parsed, '
          'then it is rejected (etagc-validated, not silently stripped).', () {
        expect(() => ETagHeader.parse('"a"b"'), throwsFormatException);
      });
    });

    group('Given whitespace between W/ and the opening quote,', () {
      test('when parsed, '
          'then it is rejected.', () {
        expect(() => ETagHeader.parse('W/ "abc"'), throwsFormatException);
      });
    });
  });
}
