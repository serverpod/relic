import 'package:relic_core/src/headers/typed/primitives/ext_value.dart';
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  test('Given a UTF-8 ext-value with percent-encoded bytes, '
      'when parsed, '
      'then it decodes the bytes as UTF-8.', () {
    final extValue = ExtValue.parse("UTF-8''caf%C3%A9%20%E2%82%AC.txt");
    expect(extValue.value, 'caf\u00e9 \u20ac.txt');
    expect(extValue.language, isNull);
  });

  test('Given an ext-value whose charset is in lower case, '
      'when parsed, '
      'then it parses as UTF-8.', () {
    expect(ExtValue.parse("utf-8''a.txt").value, 'a.txt');
  });

  test('Given an ext-value with a language between the quotes, '
      'when parsed, '
      'then it reads the language as a language tag.', () {
    expect(
      ExtValue.parse("UTF-8'en-US'a.txt").language,
      LanguageTag.parse('en-US'),
    );
  });

  test('Given an ext-value with every attr-char unencoded, '
      'when parsed, '
      'then the value holds them unchanged.', () {
    const attrChars = r'AZaz09!#$&+-.^_`|~';
    expect(ExtValue.parse("UTF-8''$attrChars").value, attrChars);
  });

  test('Given an ext-value with a charset other than UTF-8, '
      'when parsed, '
      'then it throws a FormatException.', () {
    expect(
      () => ExtValue.parse("ISO-8859-1''na%EFve.txt"),
      throwsFormatException,
    );
    expect(() => ExtValue.parse("UTF8''a.txt"), throwsFormatException);
  });

  test('Given an ext-value with an empty charset, '
      'when parsed, '
      'then it throws a FormatException.', () {
    expect(() => ExtValue.parse("''a.txt"), throwsFormatException);
    expect(() => ExtValue.parse("'en'a.txt"), throwsFormatException);
  });

  test('Given an ext-value without both quote delimiters, '
      'when parsed, '
      'then it throws a FormatException.', () {
    expect(() => ExtValue.parse('a.txt'), throwsFormatException);
    expect(() => ExtValue.parse("UTF-8'a.txt"), throwsFormatException);
  });

  test('Given an ext-value whose language is not a language tag, '
      'when parsed, '
      'then it throws a FormatException.', () {
    expect(
      () => ExtValue.parse("UTF-8'not a tag'a.txt"),
      throwsFormatException,
    );
  });

  test('Given an ext-value with a percent sign not followed by two hex digits, '
      'when parsed, '
      'then it throws a FormatException.', () {
    expect(() => ExtValue.parse("UTF-8''%zz.txt"), throwsFormatException);
    expect(() => ExtValue.parse("UTF-8''%4"), throwsFormatException);
    expect(() => ExtValue.parse("UTF-8''report%"), throwsFormatException);
  });

  test('Given an ext-value with a character outside attr-char, '
      'when parsed, '
      'then it throws a FormatException.', () {
    for (final value in ['a b', 'a"b', "a'b", 'a*b', 'a%b', 'caf\u00e9']) {
      expect(
        () => ExtValue.parse("UTF-8''$value"),
        throwsFormatException,
        reason: value,
      );
    }
  });

  test('Given an ext-value whose percent-encoded bytes are not valid UTF-8, '
      'when parsed, '
      'then it throws a FormatException.', () {
    expect(() => ExtValue.parse("UTF-8''%FF.txt"), throwsFormatException);
    expect(() => ExtValue.parse("UTF-8''%C3"), throwsFormatException);
  });

  test('Given an ExtValue with characters outside attr-char, '
      'when encoded, '
      'then it percent-encodes their UTF-8 bytes in upper case.', () {
    expect(
      const ExtValue("it's (1) caf\u00e9*.txt").encode(),
      "UTF-8''it%27s%20%281%29%20caf%C3%A9%2A.txt",
    );
  });

  test('Given an ExtValue with a language, '
      'when encoded, '
      'then it writes the language between the quotes.', () {
    expect(
      ExtValue('a.txt', language: LanguageTag.parse('en')).encode(),
      "UTF-8'en'a.txt",
    );
  });

  test('Given any ExtValue, '
      'when encoded and parsed back, '
      'then it round-trips unchanged.', () {
    for (final value in [
      '',
      'a.txt',
      "it's 100% (ok)",
      '\u00c6r\u00f8 \u20ac\u{1f600}',
    ]) {
      expect(
        ExtValue.parse(ExtValue(value).encode()).value,
        value,
        reason: value,
      );
    }
  });
}
