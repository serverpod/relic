@Timeout.none
library;

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
    handler = createStaticHandler(cacheControl: null, d.sandbox);
  });

  group('Given malformed Range headers', () {
    test(
        'Given a syntactically invalid Range header, '
        'when a request is made for the file, '
        'then an InvalidHeaderException is thrown', () async {
      final headers = Headers.fromMap({
        'range': ['bytes=invalid']
      });

      expect(
          () async =>
              await makeRequest(handler, '/test_file.txt', headers: headers),
          throwsA(isA<InvalidHeaderException>()));
    });

    test(
        'Given a Range header with no "bytes=" prefix, '
        'when a request is made for the file, '
        'then an InvalidHeaderException is thrown', () async {
      final headers = Headers.fromMap({
        'range': ['0-5']
      });

      expect(
          () async =>
              await makeRequest(handler, '/test_file.txt', headers: headers),
          throwsA(isA<InvalidHeaderException>()));
    });

    test(
        'Given a completely malformed Range header, '
        'when a request is made for the file, '
        'then an InvalidHeaderException is thrown', () async {
      final headers = Headers.fromMap({
        'range': ['abc123xyz']
      });

      expect(
          () async =>
              await makeRequest(handler, '/test_file.txt', headers: headers),
          throwsA(isA<InvalidHeaderException>()));
    });
  });

  group('Given potentially problematic Range requests', () {
    test(
        'Given a Range request with start beyond file length, '
        'when a request is made for the file, '
        'then a 416 Requested Range Not Satisfiable is returned', () async {
      // File is 16 bytes (0-15), requesting bytes starting from 100
      final headers = Headers.build((final mh) =>
          mh.range = RangeHeader(ranges: [Range(start: 100, end: 105)]));

      final response =
          await makeRequest(handler, '/test_file.txt', headers: headers);

      expect(response.statusCode, HttpStatus.requestedRangeNotSatisfiable);
    });

    test(
        'Given a suffix-byte-range-spec greater than file length, '
        'when a request is made for the file, '
        'then content is returned', () async {
      // File is 16 bytes, requesting last 100 bytes
      final headers = Headers.build(
          (final mh) => mh.range = RangeHeader(ranges: [Range(end: 100)]));

      final response =
          await makeRequest(handler, '/test_file.txt', headers: headers);

      expect(response.statusCode, HttpStatus.partialContent);
      expect(response.body.contentLength, 16);
    });

    test(
        'Given a Range request where end < start, '
        'when a request is made for the file, '
        'then a 416 Requested Range Not Satisfiable is returned', () async {
      // Invalid range: end (2) < start (5)
      final headers = Headers.build((final mh) =>
          mh.range = RangeHeader(ranges: [Range(start: 5, end: 2)]));

      final response =
          await makeRequest(handler, '/test_file.txt', headers: headers);

      expect(response.statusCode, HttpStatus.requestedRangeNotSatisfiable);
    });
  });

  group('Given boundary Range requests', () {
    test(
        'Given a Range request for the last byte, '
        'when a request is made for the file, '
        'then a 206 Partial Content status is returned with correct content',
        () async {
      // File is 16 bytes (0-15), requesting byte 15
      final headers = Headers.build((final mh) =>
          mh.range = RangeHeader(ranges: [Range(start: 15, end: 15)]));

      final response =
          await makeRequest(handler, '/test_file.txt', headers: headers);

      expect(response.statusCode, HttpStatus.partialContent);
      expect(response.body.contentLength, 1);
      expect(response.readAsString(), completion('F')); // Last character

      final contentRange = response.headers.contentRange;
      expect(contentRange, isNotNull);
      expect(contentRange!.start, 15);
      expect(contentRange.end, 15);
      expect(contentRange.size, fileContent.length);
    });

    test(
        'Given a Range request for the first byte, '
        'when a request is made for the file, '
        'then a 206 Partial Content status is returned with correct content',
        () async {
      // File is 16 bytes (0-15), requesting byte 0
      final headers = Headers.build((final mh) =>
          mh.range = RangeHeader(ranges: [Range(start: 0, end: 0)]));

      final response =
          await makeRequest(handler, '/test_file.txt', headers: headers);

      expect(response.statusCode, HttpStatus.partialContent);
      expect(response.body.contentLength, 1);
      expect(response.readAsString(), completion('0')); // First character

      expect(response.headers.acceptRanges?.isBytes, isTrue);
      final contentRange = response.headers.contentRange;
      expect(contentRange, isNotNull);
      expect(contentRange!.start, 0);
      expect(contentRange.end, 0);
      expect(contentRange.size, fileContent.length);
    });

    test(
        'Given a Range request that extends to exactly the end of file, '
        'when a request is made for the file, '
        'then a 206 Partial Content status is returned with correct content',
        () async {
      // File is 16 bytes (0-15), requesting bytes 10-15
      final headers = Headers.build((final mh) =>
          mh.range = RangeHeader(ranges: [Range(start: 10, end: 15)]));

      final response =
          await makeRequest(handler, '/test_file.txt', headers: headers);

      expect(response.statusCode, HttpStatus.partialContent);
      expect(response.body.contentLength, 6);
      expect(response.readAsString(), completion('ABCDEF')); // Last 6 chars

      final contentRange = response.headers.contentRange;
      expect(contentRange, isNotNull);
      expect(contentRange!.start, 10);
      expect(contentRange.end, 15);
      expect(contentRange.size, fileContent.length);
    });

    test(
        'Given a Range request that extends beyond the end of file, '
        'when a request is made for the file, '
        'then a 206 Partial Content response is returned with adjusted range',
        () async {
      // File is 16 bytes (0-15), requesting bytes 10-25 (beyond file end)
      final headers = Headers.build((final mh) =>
          mh.range = RangeHeader(ranges: [Range(start: 10, end: 25)]));

      final response =
          await makeRequest(handler, '/test_file.txt', headers: headers);

      expect(response.statusCode, HttpStatus.partialContent);
      expect(response.body.contentLength, 6);
      expect(response.readAsString(), completion('ABCDEF')); // Last 6 chars

      final contentRange = response.headers.contentRange;
      expect(contentRange, isNotNull);
      expect(contentRange!.start, 10);
      expect(contentRange.end, 15);
      expect(contentRange.size, fileContent.length);
    });
  });

  group('Given suffix-byte-range-spec edge cases', () {
    test(
        'Given a suffix-byte-range-spec for the entire file, '
        'when a request is made for the file, '
        'then a 206 Partial Content status is returned with full content',
        () async {
      // File is 16 bytes, requesting last 16 bytes (entire file)
      final headers = Headers.build(
          (final mh) => mh.range = RangeHeader(ranges: [Range(end: 16)]));

      final response =
          await makeRequest(handler, '/test_file.txt', headers: headers);

      expect(response.statusCode, HttpStatus.partialContent);
      expect(response.body.contentLength, fileContent.length);
      expect(response.readAsString(), completion(fileContent));

      final contentRange = response.headers.contentRange;
      expect(contentRange, isNotNull);
      expect(contentRange!.start, 0);
      expect(contentRange.end, 15);
      expect(contentRange.size, fileContent.length);
    });

    test(
        'Given a suffix-byte-range-spec for 1 byte, '
        'when a request is made for the file, '
        'then a 206 Partial Content status is returned with the last byte',
        () async {
      // File is 16 bytes, requesting last 1 byte
      final headers = Headers.build(
          (final mh) => mh.range = RangeHeader(ranges: [Range(end: 1)]));

      final response =
          await makeRequest(handler, '/test_file.txt', headers: headers);

      expect(response.statusCode, HttpStatus.partialContent);
      expect(response.body.contentLength, 1);
      expect(response.readAsString(), completion('F')); // Last character

      final contentRange = response.headers.contentRange;
      expect(contentRange, isNotNull);
      expect(contentRange!.start, 15); // Last byte is at index 15
      expect(contentRange.end, 15);
      expect(contentRange.size, fileContent.length);
    });
  });

  group('Given empty Range requests', () {
    test(
        'Given a Range header with no ranges, '
        'when a request is made for the file, '
        'then a 200 OK status is returned with full content', () async {
      final headers =
          Headers.build((final mh) => mh.range = RangeHeader(ranges: []));

      final response =
          await makeRequest(handler, '/test_file.txt', headers: headers);

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.contentLength, fileContent.length);
      expect(response.readAsString(), completion(fileContent));
      expect(response.headers.contentRange, isNull);
    });
  });
}
