import 'dart:convert';

import 'package:relic/src/body/types/body_type.dart';
import 'package:relic/src/body/types/mime_type.dart';
import 'package:test/test.dart';

void main() {
  group('BodyType', () {
    group('toHeaderValue', () {
      test(
          'Given a BodyType with only a mimeType, '
          'when toHeaderValue is called, '
          'then it returns the mimeType string', () {
        // Arrange
        const bodyType = BodyType(mimeType: MimeType.json);

        // Act
        final headerValue = bodyType.toHeaderValue();

        // Assert
        expect(headerValue, 'application/json');
      });

      test(
          'Given a BodyType with a mimeType and an encoding, '
          'when toHeaderValue is called, '
          'then it returns the mimeType and charset string', () {
        // Arrange
        const bodyType = BodyType(mimeType: MimeType.plainText, encoding: utf8);

        // Act
        final headerValue = bodyType.toHeaderValue();

        // Assert
        expect(headerValue, 'text/plain; charset=utf-8');
      });
    });
  });
}
