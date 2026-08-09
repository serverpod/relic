import 'dart:io';

import 'package:relic_core/relic_core.dart';
import 'package:relic_io/relic_io.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'test_util.dart';

void main() {
  late Handler handler;

  setUp(() async {
    await d.file('test_file.txt', '0123456789ABCDEF').create();
    handler = StaticHandler.directory(
      Directory(d.sandbox),
      cacheControl: (_, _) => null,
    ).asHandler;
  });

  Future<String> boundaryOfMultipartResponse() async {
    final response = await makeRequest(
      handler,
      '/test_file.txt',
      headers: Headers.build(
        (final mh) => mh.range = RangeHeader(
          ranges: [Range(start: 0, end: 0), Range(start: 2, end: 3)],
        ),
      ),
    );
    final contentType = response.headers[Headers.contentTypeHeader]!.first;
    return contentType.split('boundary=').last;
  }

  group('Given many multipart range responses', () {
    test('when their boundaries are compared, '
        'then no two responses share a boundary.', () async {
      const sampleSize = 5000;
      final boundaries = <String>{};
      for (var i = 0; i < sampleSize; i++) {
        boundaries.add(await boundaryOfMultipartResponse());
      }

      expect(
        boundaries,
        hasLength(sampleSize),
        reason:
            'Boundaries must be drawn from a space large enough that '
            'they do not collide',
      );
    });
  });
}
