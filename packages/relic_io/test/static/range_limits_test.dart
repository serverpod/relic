import 'dart:io';

import 'package:relic_core/relic_core.dart';
import 'package:relic_io/relic_io.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'test_util.dart';

void main() {
  const fileContent = '0123456789ABCDEF';
  late Handler handler;

  setUp(() async {
    await d.file('test_file.txt', fileContent).create();
    handler = StaticHandler.directory(
      Directory(d.sandbox),
      cacheControl: (_, _) => null,
    ).asHandler;
  });

  Headers rangeHeaders(final int count) => Headers.build(
    (final mh) => mh.range = RangeHeader(
      ranges: List.generate(count, (final _) => Range(start: 0, end: 15)),
    ),
  );

  group(
    'Given a multi-range request with more ranges than the server allows',
    () {
      test('when a request is made for the file, '
          'then it is rejected with 416 rather than served.', () async {
        final response = await makeRequest(
          handler,
          '/test_file.txt',
          headers: rangeHeaders(500),
        );

        expect(response.statusCode, HttpStatus.requestedRangeNotSatisfiable);
      });

      test('when a request repeats one range many times, '
          'then the response body cannot amplify the file size.', () async {
        final response = await makeRequest(
          handler,
          '/test_file.txt',
          headers: rangeHeaders(500),
        );

        final contentLength = response.body.contentLength ?? 0;
        expect(
          contentLength,
          lessThan(fileContent.length * 100),
          reason:
              'A short request must not ask the server to produce a '
              'response orders of magnitude larger than the file',
        );
      });
    },
  );

  group('Given an accepted multi-range request', () {
    test('when the response is created but the body is not yet read, '
        'then the file is not read until the body is consumed.', () async {
      final response = await makeRequest(
        handler,
        '/test_file.txt',
        headers: Headers.build(
          (final mh) => mh.range = RangeHeader(
            ranges: [Range(start: 0, end: 3), Range(start: 4, end: 7)],
          ),
        ),
      );
      expect(response.statusCode, HttpStatus.partialContent);

      await File(
        '${d.sandbox}/test_file.txt',
      ).writeAsString('WXYZwxyz01234567');

      final bodyString = await response.readAsString();
      expect(
        bodyString,
        contains('WXYZ'),
        reason:
            'Sections must be generated as the body is consumed, not '
            'buffered into the response before it is returned',
      );
    });

    test(
      'when the body is read, '
      'then the declared content length matches the bytes produced.',
      () async {
        final response = await makeRequest(
          handler,
          '/test_file.txt',
          headers: Headers.build(
            (final mh) => mh.range = RangeHeader(
              ranges: [Range(start: 0, end: 0), Range(start: 2, end: 3)],
            ),
          ),
        );

        final bytes = await response.read().expand((final c) => c).toList();
        expect(response.body.contentLength, equals(bytes.length));
      },
    );
  });
}
