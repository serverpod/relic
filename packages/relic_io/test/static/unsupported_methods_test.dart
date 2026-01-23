import 'dart:io';

import 'package:relic_core/relic_core.dart';
import 'package:relic_io/relic_io.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'test_util.dart'; // Provides the makeRequest helper

void main() {
  const fileContent = '0123456789ABCDEF'; // 16 bytes
  late Handler handler;

  setUp(() async {
    await d.file('test_file.txt', fileContent).create();
    handler = StaticHandler.directory(
      Directory(d.sandbox),
      cacheControl: (_, _) => null,
    ).asHandler;
  });

  group('Given unsupported HTTP methods', () {
    test(
      'Given a POST request to a static file, '
      'when the request is made, '
      'then a 405 Method Not Allowed status is returned with Allow header',
      () async {
        final response = await makeRequest(
          handler,
          '/test_file.txt',
          method: Method.post,
        );

        expect(response.statusCode, HttpStatus.methodNotAllowed);
        expect(response.body.contentLength, 0);
        expect(await response.readAsString(), isEmpty);

        final allowHeader = response.headers.allow;
        expect(allowHeader, isNotNull);
        expect(allowHeader, contains(Method.get));
        expect(allowHeader, contains(Method.head));
        expect(allowHeader!.length, 2);
      },
    );

    test(
      'Given a PUT request to a static file, '
      'when the request is made, '
      'then a 405 Method Not Allowed status is returned with Allow header',
      () async {
        final response = await makeRequest(
          handler,
          '/test_file.txt',
          method: Method.put,
        );

        expect(response.statusCode, HttpStatus.methodNotAllowed);
        expect(response.body.contentLength, 0);
        expect(await response.readAsString(), isEmpty);

        final allowHeader = response.headers.allow;
        expect(allowHeader, isNotNull);
        expect(allowHeader, contains(Method.get));
        expect(allowHeader, contains(Method.head));
        expect(allowHeader!.length, 2);
      },
    );

    test(
      'Given a DELETE request to a static file, '
      'when the request is made, '
      'then a 405 Method Not Allowed status is returned with Allow header',
      () async {
        final response = await makeRequest(
          handler,
          '/test_file.txt',
          method: Method.delete,
        );

        expect(response.statusCode, HttpStatus.methodNotAllowed);
        expect(response.body.contentLength, 0);
        expect(await response.readAsString(), isEmpty);

        final allowHeader = response.headers.allow;
        expect(allowHeader, isNotNull);
        expect(allowHeader, contains(Method.get));
        expect(allowHeader, contains(Method.head));
        expect(allowHeader!.length, 2);
      },
    );

    test(
      'Given an OPTIONS request to a static file, '
      'when the request is made, '
      'then a 405 Method Not Allowed status is returned with Allow header',
      () async {
        final response = await makeRequest(
          handler,
          '/test_file.txt',
          method: Method.options,
        );

        expect(response.statusCode, HttpStatus.methodNotAllowed);
        expect(response.body.contentLength, 0);
        expect(await response.readAsString(), isEmpty);

        final allowHeader = response.headers.allow;
        expect(allowHeader, isNotNull);
        expect(allowHeader, contains(Method.get));
        expect(allowHeader, contains(Method.head));
        expect(allowHeader!.length, 2);
      },
    );
  });
}
