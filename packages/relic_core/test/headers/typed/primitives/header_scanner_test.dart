import 'package:relic_core/src/headers/typed/primitives/header_scanner.dart';
import 'package:test/test.dart';

const int $comma = 0x2C;
const int $semicolon = 0x3B;
const int $equals = 0x3D;
const int $dquote = 0x22;

void main() {
  group('HeaderScanner basics', () {
    group('Given an empty source string,', () {
      test('when constructed, '
          'then position is 0 and atEnd is true.', () {
        final s = HeaderScanner('');

        expect(s.position, equals(0));
        expect(s.atEnd, isTrue);
        expect(s.remaining, equals(0));
        expect(s.peek(), equals(-1));
      });
    });

    group('Given a non-empty source,', () {
      test('when peek is called, '
          'then it returns the code unit at the cursor without advancing.', () {
        final s = HeaderScanner('ab');

        expect(s.peek(), equals(0x61));
        expect(s.position, equals(0));
      });

      test('when position is set within bounds, '
          'then the cursor moves.', () {
        final s = HeaderScanner('abc');

        s.position = 2;
        expect(s.peek(), equals(0x63));
        expect(s.remaining, equals(1));
      });

      test('when position is set out of bounds, '
          'then it throws a RangeError.', () {
        final s = HeaderScanner('abc');

        expect(() => s.position = -1, throwsRangeError);
        expect(() => s.position = 4, throwsRangeError);
      });
    });
  });

  group('HeaderScanner.skipOws', () {
    group('Given a string with leading SP and HTAB,', () {
      test('when skipOws is called, '
          'then all SP and HTAB are consumed.', () {
        final s = HeaderScanner('  \t \tabc');

        s.skipOws();

        expect(s.position, equals(5));
        expect(s.peek(), equals(0x61));
      });
    });

    group('Given a string with no leading OWS,', () {
      test('when skipOws is called, '
          'then the cursor does not move.', () {
        final s = HeaderScanner('abc');

        s.skipOws();

        expect(s.position, equals(0));
      });
    });

    group('Given a position at end of source,', () {
      test('when skipOws is called, '
          'then it is a no-op.', () {
        final s = HeaderScanner('abc')..position = 3;

        s.skipOws();

        expect(s.atEnd, isTrue);
      });
    });
  });

  group('HeaderScanner.tryConsume and expect', () {
    group('Given a cursor pointing at a specific character,', () {
      test('when tryConsume is called with that char, '
          'then it returns true and advances.', () {
        final s = HeaderScanner(',a');

        expect(s.tryConsume($comma), isTrue);
        expect(s.position, equals(1));
      });

      test('when tryConsume is called with a different char, '
          'then it returns false and does not advance.', () {
        final s = HeaderScanner(',a');

        expect(s.tryConsume($semicolon), isFalse);
        expect(s.position, equals(0));
      });

      test('when expect is called with that char, '
          'then it advances without error.', () {
        final s = HeaderScanner(',a');

        s.expect($comma);

        expect(s.position, equals(1));
      });

      test('when expect is called with a different char, '
          'then it throws a FormatException.', () {
        final s = HeaderScanner(',a');

        expect(() => s.expect($semicolon), throwsFormatException);
      });
    });
  });

  group('HeaderScanner.tryReadToken', () {
    group('Given a token at the cursor,', () {
      test('when tryReadToken is called, '
          'then it returns the token and advances past it.', () {
        final s = HeaderScanner('gzip;q=0.5');

        final token = s.tryReadToken();

        expect(token, equals('gzip'));
        expect(s.position, equals(4));
      });
    });

    group('Given non-tchar at the cursor,', () {
      test('when tryReadToken is called, '
          'then it returns null and does not advance.', () {
        final s = HeaderScanner(' gzip');

        final token = s.tryReadToken();

        expect(token, isNull);
        expect(s.position, equals(0));
      });
    });

    group('Given an empty source,', () {
      test('when readToken is called, '
          'then it throws a FormatException.', () {
        final s = HeaderScanner('');

        expect(s.readToken, throwsFormatException);
      });
    });
  });

  group('HeaderScanner.tryReadQuotedString', () {
    group('Given a simple quoted-string,', () {
      test(
        'when tryReadQuotedString is called, '
        'then it returns the inner text and advances past the closing quote.',
        () {
          final s = HeaderScanner('"hello"world');

          final value = s.tryReadQuotedString();

          expect(value, equals('hello'));
          expect(s.position, equals(7));
        },
      );
    });

    group('Given a quoted-string containing quoted-pair escapes,', () {
      test('when tryReadQuotedString is called, '
          'then the escapes are decoded.', () {
        final s = HeaderScanner(r'"a\"b\\c"');

        final value = s.tryReadQuotedString();

        expect(value, equals(r'a"b\c'));
        expect(s.atEnd, isTrue);
      });
    });

    group('Given an empty quoted-string,', () {
      test('when tryReadQuotedString is called, '
          'then it returns the empty string.', () {
        final s = HeaderScanner('""');

        final value = s.tryReadQuotedString();

        expect(value, equals(''));
        expect(s.atEnd, isTrue);
      });
    });

    group('Given a cursor not pointing at a quote,', () {
      test('when tryReadQuotedString is called, '
          'then it returns null without advancing.', () {
        final s = HeaderScanner('hello');

        final value = s.tryReadQuotedString();

        expect(value, isNull);
        expect(s.position, equals(0));
      });
    });

    group('Given an unterminated quoted-string,', () {
      test('when tryReadQuotedString is called, '
          'then it throws and rewinds the cursor.', () {
        final s = HeaderScanner('"missing-close');

        expect(s.tryReadQuotedString, throwsFormatException);
        expect(s.position, equals(0));
      });
    });

    group('Given a dangling backslash before EOF,', () {
      test('when tryReadQuotedString is called, '
          'then it throws and rewinds the cursor.', () {
        final s = HeaderScanner(r'"abc\');

        expect(s.tryReadQuotedString, throwsFormatException);
        expect(s.position, equals(0));
      });
    });

    group('Given an invalid character inside the quoted-string,', () {
      test('when tryReadQuotedString is called, '
          'then it throws and rewinds the cursor.', () {
        // 0x01 (SOH) is a control character, not allowed unescaped.
        final s = HeaderScanner('"a\x01b"');

        expect(s.tryReadQuotedString, throwsFormatException);
        expect(s.position, equals(0));
      });
    });
  });

  group('HeaderScanner.tryReadTokenOrQuotedString', () {
    group('Given a token at the cursor,', () {
      test('when tryReadTokenOrQuotedString is called, '
          'then it reads the token.', () {
        final s = HeaderScanner('gzip,deflate');

        final value = s.tryReadTokenOrQuotedString();

        expect(value, equals('gzip'));
      });
    });

    group('Given a quoted-string at the cursor,', () {
      test('when tryReadTokenOrQuotedString is called, '
          'then it reads and unescapes the quoted-string.', () {
        final s = HeaderScanner('"hello world"');

        final value = s.tryReadTokenOrQuotedString();

        expect(value, equals('hello world'));
      });
    });

    group('Given neither a token nor a quoted-string,', () {
      test('when tryReadTokenOrQuotedString is called, '
          'then it returns null.', () {
        final s = HeaderScanner(' ');

        expect(s.tryReadTokenOrQuotedString(), isNull);
      });

      test('when readTokenOrQuotedString is called, '
          'then it throws a FormatException.', () {
        final s = HeaderScanner(' ');

        expect(s.readTokenOrQuotedString, throwsFormatException);
      });
    });
  });

  group('HeaderScanner.indexOfTopLevel', () {
    group('Given a separator outside any quoted-string,', () {
      test('when indexOfTopLevel is called, '
          'then it returns the index without advancing.', () {
        final s = HeaderScanner('a,b');

        expect(s.indexOfTopLevel($comma), equals(1));
        expect(s.position, equals(0));
      });
    });

    group('Given a separator only inside a quoted-string,', () {
      test('when indexOfTopLevel is called, '
          'then the inner occurrence is skipped.', () {
        final s = HeaderScanner('"a,b"c');

        expect(s.indexOfTopLevel($comma), equals(-1));
      });

      test('when there is also a top-level occurrence after, '
          'then the top-level occurrence is returned.', () {
        final s = HeaderScanner('"a,b",c');

        expect(s.indexOfTopLevel($comma), equals(5));
      });
    });

    group('Given a malformed quoted-string before any separator,', () {
      test('when indexOfTopLevel is called, '
          'then it throws and leaves the cursor unchanged.', () {
        final s = HeaderScanner('"unterminated, more');

        expect(() => s.indexOfTopLevel($comma), throwsFormatException);
        expect(s.position, equals(0));
      });
    });
  });

  group('HeaderScanner.splitTopLevel', () {
    group('Given a simple comma-separated list,', () {
      test('when splitTopLevel(comma) is iterated, '
          'then each element is yielded with OWS trimmed.', () {
        final s = HeaderScanner('gzip, deflate ,identity');

        expect(
          s.splitTopLevel($comma),
          equals(['gzip', 'deflate', 'identity']),
        );
        expect(s.atEnd, isTrue);
      });
    });

    group('Given a list with a quoted-string containing the separator,', () {
      test('when splitTopLevel(semicolon) is iterated, '
          'then the inner separator does not split the element.', () {
        final s = HeaderScanner('for="[::1]:4711";desc="semi;colon"');

        expect(
          s.splitTopLevel($semicolon),
          equals(['for="[::1]:4711"', 'desc="semi;colon"']),
        );
      });
    });

    group('Given a list with empty elements between separators,', () {
      test('when splitTopLevel(comma) is iterated, '
          'then empty elements are preserved as empty strings.', () {
        final s = HeaderScanner('a,,b');

        expect(s.splitTopLevel($comma), equals(['a', '', 'b']));
      });
    });

    group('Given an empty source,', () {
      test('when splitTopLevel(comma) is iterated, '
          'then no elements are yielded.', () {
        final s = HeaderScanner('');

        expect(s.splitTopLevel($comma), isEmpty);
      });
    });

    group('Given a source with a trailing separator,', () {
      test('when splitTopLevel(comma) is iterated, '
          'then a trailing empty element is yielded.', () {
        final s = HeaderScanner('a,b,');

        expect(s.splitTopLevel($comma), equals(['a', 'b', '']));
      });
    });
  });

  group('HeaderScanner end-to-end parameter parsing', () {
    group('Given a parameter chain with quoted and bare values,', () {
      test('when scanned semicolon-by-semicolon, '
          'then names and values round-trip correctly.', () {
        // Mimics what a Content-Disposition parser does.
        final s = HeaderScanner(r'attachment; filename="a;b\".pdf"; size=1234');

        final firstSemi = s.indexOfTopLevel($semicolon);
        expect(firstSemi, equals(10));
        final type = s.source.substring(0, firstSemi);
        expect(type, equals('attachment'));
        s.position = firstSemi + 1;
        s.skipOws();

        expect(s.readToken(), equals('filename'));
        s.expect($equals);
        expect(s.peek(), equals($dquote));
        expect(s.readQuotedString(), equals(r'a;b".pdf'));

        s.expect($semicolon);
        s.skipOws();
        expect(s.readToken(), equals('size'));
        s.expect($equals);
        expect(s.readToken(), equals('1234'));
        expect(s.atEnd, isTrue);
      });
    });
  });
}
