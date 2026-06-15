import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('ContentLanguageHeader.parse', () {
    group('Given mixed-case BCP 47 tags,', () {
      test('when parsed, '
          'then they are stored in canonical case.', () {
        final h = ContentLanguageHeader.parse(['en-us, ZH-hant-tw']);

        expect(h.languages, equals(['en-US', 'zh-Hant-TW']));
      });
    });

    group('Given two tags that differ only in case,', () {
      test('when parsed, '
          'then they canonicalize to equal headers.', () {
        expect(
          ContentLanguageHeader.parse(['en-US']),
          equals(ContentLanguageHeader.parse(['EN-us'])),
        );
      });
    });
  });
}
