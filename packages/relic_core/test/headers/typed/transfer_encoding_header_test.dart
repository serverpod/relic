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
          'then it throws (RFC 9112 6.1) instead of silently reordering.', () {
        expect(
          () => TransferEncodingHeader.parse(['chunked, gzip']),
          throwsFormatException,
        );
      });
    });

    group('Given a coding in mixed case,', () {
      test('when parsed, '
          'then it is matched case-insensitively.', () {
        final header = TransferEncodingHeader.parse(['GZIP, Chunked']);

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

    group('Given a mixed-case duplicate chunked,', () {
      test('when parsed, '
          'then it dedupes by canonical name and does not falsely reject.', () {
        final header = TransferEncodingHeader.parse(['gzip, chunked, CHUNKED']);

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
    group('Given a valid header with chunked last,', () {
      test('when encoded, '
          'then the codings render in order.', () {
        final header = TransferEncodingHeader.parse(['gzip, chunked']);

        expect(
          TransferEncodingHeader.codec.encode(header),
          equals(['gzip, chunked']),
        );
      });
    });
  });
}
