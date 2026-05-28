import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('TransferEncodingHeader.parse', () {
    group('Given a valid multi-coding value,', () {
      test('when parsed, '
          'then the encodings are preserved in order.', () {
        final header = TransferEncodingHeader.parse(['gzip, chunked']);

        expect(
          header.encodings.map((final e) => e.name),
          equals(['gzip', 'chunked']),
        );
      });
    });

    group('Given "chunked" is not the last coding,', () {
      test('when parsed, '
          'then it is reordered to be last (RFC 9112).', () {
        final header = TransferEncodingHeader.parse(['chunked, gzip']);

        expect(
          header.encodings.map((final e) => e.name),
          equals(['gzip', 'chunked']),
        );
      });
    });

    group('Given duplicate codings,', () {
      test('when parsed, '
          'then duplicates are removed.', () {
        final header = TransferEncodingHeader.parse(['gzip, chunked, chunked']);

        expect(
          header.encodings.map((final e) => e.name),
          equals(['gzip', 'chunked']),
        );
      });
    });

    group('Given a value that contains "chunked",', () {
      test('when parsed, '
          'then chunked is among the encodings.', () {
        final header = TransferEncodingHeader.parse(['gzip, chunked']);

        expect(
          header.encodings.any(
            (final e) => e.name == TransferEncoding.chunked.name,
          ),
          isTrue,
        );
      });
    });

    group('Given an invalid coding,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(
          () => TransferEncodingHeader.parse(['custom-encoding']),
          throwsFormatException,
        );
      });
    });

    group('Given an empty value,', () {
      test('when parsed, '
          'then it throws a FormatException.', () {
        expect(() => TransferEncodingHeader.parse(['']), throwsFormatException);
      });
    });
  });

  group('TransferEncodingHeader encoding', () {
    group('Given a reordered header,', () {
      test('when encoded, '
          'then chunked appears last on the wire.', () {
        final header = TransferEncodingHeader.parse(['chunked, gzip']);

        expect(
          TransferEncodingHeader.codec.encode(header),
          equals(['gzip, chunked']),
        );
      });
    });
  });
}
