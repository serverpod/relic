import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../headers/headers_test_utils.dart';
import '../util/test_util.dart';

void main() {
  group('Error message sanitization', () {
    test(
        'HeaderException errors should be sanitized', () async {
      final server = await testServe(
        (final ctx) {
          throw const InvalidHeaderException(
            'Value contains sensitive data: SECRET123',
            headerType: 'test-header',
          );
        },
      );

      try {
        final response = await http.get(server.url.replace(path: '/test'));

        expect(response.statusCode, 400);
        expect(response.body, equals('Bad Request'));
        expect(response.body, isNot(contains('SECRET123')));
      } finally {
        await server.close();
      }
    });
  });
}