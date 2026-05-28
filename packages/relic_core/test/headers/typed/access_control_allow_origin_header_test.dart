import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('AccessControlAllowOriginHeader equality and hashing', () {
    group('Given the wildcard and the opaque-origin (null) values,', () {
      test('when their hashCodes are compared, '
          'then they differ (no bucket-0 collision).', () {
        const wildcard = AccessControlAllowOriginHeader.wildcard();
        final opaque = AccessControlAllowOriginHeader.origin(
          origin: OpaqueOrigin.instance,
        );

        expect(wildcard.hashCode, isNot(equals(opaque.hashCode)));
        expect(wildcard == opaque, isFalse);
      });
    });

    group('Given two wildcard headers,', () {
      test('when compared, '
          'then they are equal and share a hashCode.', () {
        const a = AccessControlAllowOriginHeader.wildcard();
        const b = AccessControlAllowOriginHeader.wildcard();

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
        expect(a.isWildcard, isTrue);
      });
    });

    group('Given two headers with the same tuple origin,', () {
      test('when compared, '
          'then they are equal and share a hashCode.', () {
        final a = AccessControlAllowOriginHeader.origin(
          origin: Origin.parse('https://example.com'),
        );
        final b = AccessControlAllowOriginHeader.origin(
          origin: Origin.parse('https://example.com'),
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
        expect(a.isWildcard, isFalse);
      });
    });
  });
}
