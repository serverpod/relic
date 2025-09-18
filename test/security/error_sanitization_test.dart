import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../headers/headers_test_utils.dart';
import '../util/test_util.dart';

void main() {
  group('Error message sanitization', () {
    test(
        'error messages should be sanitized and not include user input',
        () async {
      final server = await testServe(
        (final ctx) {
          // Simulate a JSON parsing error that includes request content
          throw Exception('Invalid JSON in body: sensitive user data here');
        },
      );

      try {
        final response = await http.post(
          server.url.replace(path: '/test'),
          body: 'This is sensitive user input',
          headers: {'Content-Type': 'application/json'},
        );

        expect(response.statusCode, 400);
        expect(response.body, equals('Bad Request'));
        expect(response.body, isNot(contains('sensitive user data')));
        expect(response.body, isNot(contains('This is sensitive user input')));
      } finally {
        await server.close();
      }
    });

    test(
        'when error is not JSON-related, '
        'should return generic Internal Server Error', () async {
      final server = await testServe(
        (final ctx) {
          throw Exception('Some internal error with sensitive data: SECRET123');
        },
      );

      try {
        final response = await http.get(server.url.replace(path: '/test'));

        expect(response.statusCode, 500);
        expect(response.body, equals('Internal Server Error'));
        expect(response.body, isNot(contains('SECRET123')));
      } finally {
        await server.close();
      }
    });

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

    test(
        'JSON parsing error patterns should be detected correctly', () async {
      final jsonPatterns = [
        'Invalid JSON: malformed data',
        'json decode error: unexpected character',
        'Parse error in JSON data',
        'JSON format exception',
        'Syntax error in JSON',
      ];

      for (final pattern in jsonPatterns) {
        final server = await testServe(
          (final ctx) => throw Exception(pattern),
        );

        try {
          final response = await http.post(
            server.url.replace(path: '/test'),
            body: 'test data',
          );

          expect(
            response.statusCode,
            400,
            reason: 'Pattern "$pattern" should be detected as bad request',
          );
          expect(response.body, equals('Bad Request'));
        } finally {
          await server.close();
        }
      }
    });
  });
}