import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('CrossOriginEmbedderPolicyHeader.parse', () {
    group('Given a policy with a report-to parameter,', () {
      test('when parsed, '
          'then the policy and report-to are captured and round-trip.', () {
        final h = CrossOriginEmbedderPolicyHeader.parse(
          'require-corp; report-to="coep-endpoint"',
        );

        expect(h.policy, equals('require-corp'));
        expect(h.reportTo, equals('coep-endpoint'));
        expect(
          CrossOriginEmbedderPolicyHeader.codec.encode(h).single,
          equals('require-corp; report-to="coep-endpoint"'),
        );
      });
    });

    group('Given a report-to value containing a semicolon (quoted),', () {
      test('when parsed, '
          'then the semicolon does not split the value.', () {
        final h = CrossOriginEmbedderPolicyHeader.parse(
          'require-corp; report-to="a;b"',
        );

        expect(h.reportTo, equals('a;b'));
      });
    });

    group('Given a report-to value with an escaped quote on the wire,', () {
      test('when parsed, encoded, and re-parsed, '
          'then the quote round-trips.', () {
        final parsed = CrossOriginEmbedderPolicyHeader.parse(
          r'require-corp; report-to="a\"b"',
        );
        expect(parsed.reportTo, equals(r'a"b'));

        final wire = CrossOriginEmbedderPolicyHeader.codec
            .encode(parsed)
            .single;
        final reparsed = CrossOriginEmbedderPolicyHeader.parse(wire);
        expect(reparsed.reportTo, equals(r'a"b'));
      });
    });

    group('Given a report-to value with a quoted-pair over a plain char,', () {
      test('when parsed, '
          'then the backslash escape is removed (RFC 9110 quoted-pair).', () {
        final h = CrossOriginEmbedderPolicyHeader.parse(
          r'require-corp; report-to="a\b"',
        );

        expect(h.reportTo, equals('ab'));
      });
    });

    group('Given trailing characters after a quoted report-to value,', () {
      test('when parsed, '
          'then it throws.', () {
        expect(
          () => CrossOriginEmbedderPolicyHeader.parse(
            'require-corp; report-to="a"x',
          ),
          throwsFormatException,
        );
      });
    });

    group('Given an unknown policy token,', () {
      test('when parsed, '
          'then it throws.', () {
        expect(
          () => CrossOriginEmbedderPolicyHeader.parse('made-up'),
          throwsFormatException,
        );
      });
    });
  });

  group('CrossOriginOpenerPolicyHeader.parse', () {
    group('Given the noopener-allow-popups value,', () {
      test('when parsed, '
          'then it is accepted.', () {
        final h = CrossOriginOpenerPolicyHeader.parse('noopener-allow-popups');

        expect(h.policy, equals('noopener-allow-popups'));
      });
    });

    group('Given a policy with a report-to parameter,', () {
      test('when parsed, '
          'then the report-to is captured.', () {
        final h = CrossOriginOpenerPolicyHeader.parse(
          'same-origin; report-to="coop-endpoint"',
        );

        expect(h.policy, equals('same-origin'));
        expect(h.reportTo, equals('coop-endpoint'));
      });
    });
  });
}
