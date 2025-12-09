import 'package:relic/relic.dart';
import 'package:test/test.dart';

void main() {
  final element1 = ForwardedElement(
    forwardedFor: const ForwardedIdentifier('client1'),
  );
  final element2 = ForwardedElement(by: const ForwardedIdentifier('proxy1'));
  final element3 = ForwardedElement(
    forwardedFor: const ForwardedIdentifier('client2'),
  );

  group('Equality and HashCode', () {
    test('Given two identical ForwardedHeader instances, '
        'when compared with ==, '
        'then they should be equal and have the same hashCode.', () {
      final header1 = ForwardedHeader([element1, element2]);
      final header2 = ForwardedHeader([element1, element2]);

      expect(header1 == header2, isTrue);
      expect(header1.hashCode, equals(header2.hashCode));
    });

    test('Given two ForwardedHeader instances with different element lists, '
        'when compared with ==, '
        'then they should not be equal.', () {
      final header1 = ForwardedHeader([element1, element2]);
      final header2 = ForwardedHeader([element1, element3]);

      expect(header1 == header2, isFalse);
    });

    test(
      'Given two ForwardedHeader instances with elements in different order, '
      'when compared with ==, '
      'then they should not be equal (order matters for ListEquality).',
      () {
        final header1 = ForwardedHeader([element1, element2]);
        final header2 = ForwardedHeader([element2, element1]);

        expect(header1 == header2, isFalse);
      },
    );
  });
}
