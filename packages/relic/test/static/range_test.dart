import 'dart:io';

import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'test_util.dart'; // Provides the makeRequest helper

void main() {
  const fileContent = '0123456789ABCDEF'; // 16 bytes
  late Handler handler;

  setUp(() async {
    await d.file('test_file.txt', fileContent).create();
    handler =
        StaticHandler.directory(
          Directory(d.sandbox),
          cacheControl: (_, _) => null,
        ).asHandler;
  });

  group('Given a single byte range request', () {
    test(
      'Given a byte range (start-end), '
      'when a request is made for the file, '
      'then a 206 Partial Content status with partial content and Content-Range is returned',
      () async {
        final headers = Headers.build(
          (final mh) =>
              mh.range = RangeHeader(ranges: [Range(start: 0, end: 4)]),
        ); // 0-4 (5 bytes)

        final response = await makeRequest(
          handler,
          '/test_file.txt',
          headers: headers,
        );

        expect(response.statusCode, HttpStatus.partialContent);
        expect(response.body.contentLength, 5);
        expect(
          response.readAsString(),
          completion(fileContent.substring(0, 5)),
        );
        final contentRange = response.headers.contentRange;
        expect(contentRange, isNotNull);
        expect(contentRange!.unit, 'bytes');
        expect(contentRange.start, 0);
        expect(contentRange.end, 4);
        expect(response.headers.contentRange!.size, fileContent.length);
      },
    );

    test(
      'Given a byte range (start-), '
      'when a request is made for the file, '
      'then a 206 Partial Content status with partial content and Content-Range is returned',
      () async {
        final headers = Headers.build(
          (final mh) => mh.range = RangeHeader(ranges: [Range(start: 10)]),
        ); // 10-END (6 bytes)

        final response = await makeRequest(
          handler,
          '/test_file.txt',
          headers: headers,
        );

        expect(response.statusCode, HttpStatus.partialContent);
        expect(response.body.contentLength, 6);
        expect(response.readAsString(), completion(fileContent.substring(10)));
        expect(response.headers.contentRange, isNotNull);
        expect(response.headers.contentRange!.unit, 'bytes');
        expect(response.headers.contentRange!.start, 10);
        expect(response.headers.contentRange!.end, fileContent.length - 1);
        expect(response.headers.contentRange!.size, fileContent.length);
      },
    );

    test(
      'Given a byte range (-suffixLength), '
      'when a request is made for the file, '
      'then a 206 Partial Content status with partial content and Content-Range is returned',
      () async {
        final headers = Headers.build(
          (final mh) => mh.range = RangeHeader(ranges: [Range(end: 5)]),
        ); // last 5 bytes

        final response = await makeRequest(
          handler,
          '/test_file.txt',
          headers: headers,
        );

        expect(response.statusCode, HttpStatus.partialContent);
        expect(response.body.contentLength, 5);
        expect(
          response.readAsString(),
          completion(fileContent.substring(fileContent.length - 5)),
        );
        expect(response.headers.contentRange, isNotNull);
        expect(response.headers.contentRange!.unit, 'bytes');
        expect(response.headers.contentRange!.start, fileContent.length - 5);
        expect(response.headers.contentRange!.end, fileContent.length - 1);
        expect(response.headers.contentRange!.size, fileContent.length);
      },
    );
  });

  group('Given a multiple byte range request', () {
    test(
      'Given a multiple byte range request, '
      'when a request is made for the file, '
      'then a 206 Partial Content status is returned with multipart body',
      () async {
        // Content: '0123456789ABCDEF' (length 16)
        // Ranges: bytes=0-0,2-3,14-
        // Expected parts: '0', '23', 'EF'
        final headers = Headers.build(
          (final mh) =>
              mh.range = RangeHeader(
                ranges: [
                  Range(start: 0, end: 0), // '0'
                  Range(start: 2, end: 3), // '23'
                  Range(start: 14), // 'EF'
                ],
              ),
        );

        final response = await makeRequest(
          handler,
          '/test_file.txt',
          headers: headers,
        );

        expect(response.statusCode, HttpStatus.partialContent);
        final mimeType = response.body.bodyType!.mimeType;
        expect(mimeType.primaryType, 'multipart');
        expect(mimeType.subType, 'byteranges');

        final boundary = _extractBoundary(
          response.headers[Headers.contentTypeHeader]!.first,
        );

        final bodyString = await response.readAsString();

        expect(
          bodyString,
          contains(
            '--$boundary\r\nContent-Type: text/plain\r\nContent-Range: bytes 0-0/${fileContent.length}\r\n\r\n0\r\n',
          ),
        );
        expect(
          bodyString,
          contains(
            '--$boundary\r\nContent-Type: text/plain\r\nContent-Range: bytes 2-3/${fileContent.length}\r\n\r\n23\r\n',
          ),
        );
        expect(
          bodyString,
          contains(
            '--$boundary\r\nContent-Type: text/plain\r\nContent-Range: bytes 14-15/${fileContent.length}\r\n\r\nEF\r\n',
          ),
        );
        expect(bodyString, endsWith('--$boundary--\r\n'));
      },
    );
  });
}

String? _extractBoundary(final String contentType) {
  // Split the Content-Type header by ';' to get individual parameters
  final parts = contentType.split(';');

  // Find the part that starts with 'boundary='
  final boundaryPart = parts.firstWhere(
    (final part) => part.trim().startsWith('boundary='),
    orElse: () => '',
  );

  if (boundaryPart.isEmpty) {
    return null;
  }

  // Extract the boundary string itself and remove any surrounding quotes
  final boundary = boundaryPart
      .trim()
      .substring('boundary='.length)
      .replaceAll('"', '');

  return boundary;
}
