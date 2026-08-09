import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('MimeType.parse', () {
    group('Given a type carrying a line break', () {
      test('when parsed, '
          'then it throws rather than producing a splitting type.', () {
        expect(
          () => MimeType.parse('text/plain\r\nX-Injected: 1'),
          throwsFormatException,
        );
      });
    });

    group('Given a type with characters outside the token grammar', () {
      test('when parsed, '
          'then it throws.', () {
        for (final type in ['text/pl ain', 'te xt/plain', 'text/pl;ain']) {
          expect(
            () => MimeType.parse(type),
            throwsFormatException,
            reason: 'Type "$type" should be rejected',
          );
        }
      });
    });

    group('Given an ordinary type', () {
      test('when parsed, '
          'then the parts are recovered.', () {
        for (final type in [
          'text/plain',
          'application/vnd.api+json',
          'application/octet-stream',
        ]) {
          expect(MimeType.parse(type).toHeaderValue(), type, reason: type);
        }
      });
    });
  });

  group('MimeType.toHeaderValue', () {
    group('Given a type built directly from invalid parts', () {
      test('when rendered, '
          'then it throws rather than emitting the parts.', () {
        expect(
          () =>
              const MimeType('text', 'plain\r\nX-Injected: 1').toHeaderValue(),
          throwsFormatException,
        );
      });
    });
  });
}
