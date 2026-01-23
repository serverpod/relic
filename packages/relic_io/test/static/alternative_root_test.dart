import 'dart:io';

import 'package:relic_core/relic_core.dart';
import 'package:relic_io/relic_io.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'test_util.dart';

void main() {
  setUp(() async {
    await d.file('root.txt', 'root txt').create();
    await d.dir('files', [
      d.file('test.txt', 'test txt content'),
      d.file('with space.txt', 'with space content'),
    ]).create();
  });

  test(
    'Given a root file when accessed then it returns the file content',
    () async {
      final handler = StaticHandler.directory(
        Directory(d.sandbox),
        cacheControl: (_, _) => null,
      ).asHandler;

      final response = await makeRequest(handler, '/root.txt');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.contentLength, 8);
      expect(response.readAsString(), completion('root txt'));
    },
  );

  test(
    'Given a root file with space when accessed then it returns the file content',
    () async {
      final handler = StaticHandler.directory(
        Directory(d.sandbox),
        cacheControl: (_, _) => null,
      ).asHandler;

      final response = await makeRequest(handler, '/files/with%20space.txt');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.contentLength, 18);
      expect(response.readAsString(), completion('with space content'));
    },
  );

  test(
    'Given a root file with unencoded space when accessed then it returns the file content',
    () async {
      final handler = StaticHandler.directory(
        Directory(d.sandbox),
        cacheControl: (_, _) => null,
      ).asHandler;

      final response = await makeRequest(handler, '/files/with%20space.txt');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.contentLength, 18);
      expect(response.readAsString(), completion('with space content'));
    },
  );

  test(
    'Given a file under directory when accessed then it returns the file content',
    () async {
      final handler = StaticHandler.directory(
        Directory(d.sandbox),
        cacheControl: (_, _) => null,
      ).asHandler;

      final response = await makeRequest(handler, '/files/test.txt');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.contentLength, 16);
      expect(response.readAsString(), completion('test txt content'));
    },
  );

  test(
    'Given a non-existent file when accessed then it returns a 404 status',
    () async {
      final handler = StaticHandler.directory(
        Directory(d.sandbox),
        cacheControl: (_, _) => null,
      ).asHandler;

      final response = await makeRequest(handler, '/not_here.txt');
      expect(response.statusCode, HttpStatus.notFound);
    },
  );
}
