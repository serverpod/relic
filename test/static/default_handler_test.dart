import 'dart:io';

import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'test_util.dart';

void main() {
  group('Given a default handler that returns 403 Forbidden', () {
    late final Handler handler;

    setUpAll(() async {
      await d.dir('files', [
        d.file('index.html', '<html><body>files</body></html>'),
      ]).create();

      // Return 403 Forbidden instead of 404 Not Found, as default
      handler = StaticHandler.directory(
        Directory(d.sandbox),
        cacheControl: (_, _) => null,
        defaultHandler: respondWith((_) => Response.forbidden()),
      ).asHandler;
    });

    test('when accessing exisiting directory "/files" '
        'then it returns 403 Forbidden', () async {
      final response = await makeRequest(handler, '/files');
      expect(response.statusCode, HttpStatus.forbidden);
    });

    test('when accessing existing file "/files/index.html" '
        'then it returns the default document', () async {
      final response = await makeRequest(handler, '/files/index.html');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.body.contentLength, 31);
      expect(
        response.readAsString(),
        completion('<html><body>files</body></html>'),
      );
      expect(response.mimeType?.primaryType, 'text');
      expect(response.mimeType?.subType, 'html');
    });

    test('when accessing non-existing file entity "/files/none" '
        'then it returns 403 Forbidden', () async {
      final response = await makeRequest(handler, '/files/none');
      expect(response.statusCode, HttpStatus.forbidden);
    });
  });
}
