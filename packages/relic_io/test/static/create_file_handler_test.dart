import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:relic_core/relic_core.dart';
import 'package:relic_io/relic_io.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'test_util.dart';

void main() {
  setUp(() async {
    await d.file('file.txt', 'contents').create();
    await d.file('random.unknown', 'no clue').create();
  });

  test('Given a file when served then it returns the file contents', () async {
    final handler = StaticHandler.file(
      File(p.join(d.sandbox, 'file.txt')),
      cacheControl: (_, _) => null,
    ).asHandler;
    final response = await makeRequest(handler, '/file.txt');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.body.contentLength, 8);
    expect(response.readAsString(), completion('contents'));
  });

  test('Given a non-matching URL when served then it returns a 404', () async {
    final router = RelicRouter()
      ..get(
        '/foo/bar',
        StaticHandler.file(
          File(p.join(d.sandbox, 'file.txt')),
          cacheControl: (_, _) => null,
        ).asHandler,
      );

    final handler = router.asHandler;
    final response = await makeRequest(handler, '/foo/file.txt');
    expect(response.statusCode, HttpStatus.notFound);
  });

  test(
    'Given a file under a custom URL when served then it returns the file contents',
    () async {
      final router = RelicRouter()
        ..get(
          '/foo/bar',
          StaticHandler.file(
            File(p.join(d.sandbox, 'file.txt')),
            cacheControl: (_, _) => null,
          ).asHandler,
        );

      final handler = router.asHandler;
      final response = await makeRequest(handler, '/foo/bar');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.contentLength, 8);
      expect(response.readAsString(), completion('contents'));
    },
  );

  test(
    "Given a custom URL that isn't matched when served then it returns a 404",
    () async {
      final router = RelicRouter()
        ..get(
          '/foo/bar',
          StaticHandler.file(
            File(p.join(d.sandbox, 'file.txt')),
            cacheControl: (_, _) => null,
          ).asHandler,
        );

      final handler = router.asHandler;
      final response = await makeRequest(handler, '/file.txt');
      expect(response.statusCode, HttpStatus.notFound);
    },
  );

  group('Given the content type header', () {
    test('when inferred from the file path then it is set correctly', () async {
      final handler = StaticHandler.file(
        File(p.join(d.sandbox, 'file.txt')),
        cacheControl: (_, _) => null,
      ).asHandler;
      final response = await makeRequest(handler, '/file.txt');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.mimeType?.primaryType, 'text');
      expect(response.mimeType?.subType, 'plain');
    });

    test(
      "when it can't be inferred then it defaults to application/octet-stream",
      () async {
        final handler = StaticHandler.file(
          File(p.join(d.sandbox, 'random.unknown')),
          cacheControl: (_, _) => null,
        ).asHandler;
        final response = await makeRequest(handler, '/random.unknown');
        expect(response.statusCode, HttpStatus.ok);
        expect(response.mimeType, MimeType.octetStream);
      },
    );
  });

  group('Given the content range header', () {
    test(
      'when bytes from 0 to 4 are requested then it returns partial content',
      () async {
        final handler = StaticHandler.file(
          File(p.join(d.sandbox, 'file.txt')),
          cacheControl: (_, _) => null,
        ).asHandler;
        final response = await makeRequest(
          handler,
          '/file.txt',
          headers: Headers.build(
            (final mh) => mh.range = RangeHeader.parse('bytes=0-4'),
          ),
        );
        expect(response.statusCode, HttpStatus.partialContent);
        expect(response.headers.acceptRanges?.isBytes, isTrue);
        expect(response.headers.contentRange?.start, 0);
        expect(response.headers.contentRange?.end, 4);
        expect(response.headers.contentRange?.size, 8);
      },
    );

    test(
      'when range at the end overflows from 0 to 9 then it returns partial content',
      () async {
        final handler = StaticHandler.file(
          File(p.join(d.sandbox, 'file.txt')),
          cacheControl: (_, _) => null,
        ).asHandler;
        final response = await makeRequest(
          handler,
          '/file.txt',
          headers: Headers.build(
            (final mh) => mh.range = RangeHeader.parse('bytes=0-9'),
          ),
        );
        expect(response.statusCode, HttpStatus.partialContent);
        expect(response.headers.acceptRanges?.isBytes, isTrue);

        expect(response.headers.contentRange?.start, 0);
        expect(response.headers.contentRange?.end, 7);
        expect(response.headers.contentRange?.size, 8);

        expect(response.body.contentLength, 8);
      },
    );

    test('when range at the start overflows from 8 to 9, '
        'then it returns 416 Request Range Not Satisfiable', () async {
      final handler = StaticHandler.file(
        File(p.join(d.sandbox, 'file.txt')),
        cacheControl: (_, _) => null,
      ).asHandler;
      final response = await makeRequest(
        handler,
        '/file.txt',
        headers: Headers.build(
          (final mh) => mh.range = RangeHeader.parse('bytes=8-9'),
        ),
      );

      expect(response.statusCode, HttpStatus.requestedRangeNotSatisfiable);
      expect(response.body.contentLength, 0);
      expect(response.headers.acceptRanges?.isBytes, isTrue);
    });

    test('when invalid request with start > end is received, '
        'then it returns 416 Request Range Not Satisfiable', () async {
      final handler = StaticHandler.file(
        File(p.join(d.sandbox, 'file.txt')),
        cacheControl: (_, _) => null,
      ).asHandler;
      final response = await makeRequest(
        handler,
        '/file.txt',
        headers: Headers.build(
          (final mh) => mh.range = RangeHeader.parse('bytes=2-1'),
        ),
      );
      expect(response.statusCode, HttpStatus.requestedRangeNotSatisfiable);
      expect(response.body.contentLength, 0);
      expect(response.headers.acceptRanges?.isBytes, isTrue);
    });

    test('when request with start > end is received, '
        'then it returns 416 Request Range Not Satisfiable', () async {
      final handler = StaticHandler.file(
        File(p.join(d.sandbox, 'file.txt')),
        cacheControl: (_, _) => null,
      ).asHandler;
      final response = await makeRequest(
        handler,
        '/file.txt',
        headers: Headers.build(
          (final mh) => mh.range = RangeHeader.parse('bytes=2-1'),
        ),
      );
      expect(response.statusCode, HttpStatus.requestedRangeNotSatisfiable);
      expect(response.body.contentLength, 0);
      expect(response.headers.acceptRanges?.isBytes, isTrue);
    });
  });

  group('Given an ArgumentError is thrown for', () {
    test("when a file doesn't exist then it throws an ArgumentError", () {
      expect(
        () => StaticHandler.file(
          File(p.join(d.sandbox, 'nothing.txt')),
          cacheControl: (_, _) => null,
        ),
        throwsArgumentError,
      );
    });
  });
}
