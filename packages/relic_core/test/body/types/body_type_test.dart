import 'dart:convert';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('BodyType', () {
    group('toHeaderValue', () {
      test('Given a BodyType with only a mimeType, '
          'when toHeaderValue is called, '
          'then it returns the mimeType string', () {
        // Arrange
        final bodyType = BodyType(mimeType: MimeType.json);

        // Act
        final headerValue = bodyType.toHeaderValue();

        // Assert
        expect(headerValue, 'application/json');
      });

      test('Given a BodyType with a mimeType and an encoding, '
          'when toHeaderValue is called, '
          'then it returns the mimeType and charset string', () {
        // Arrange
        final bodyType = BodyType(mimeType: MimeType.plainText, encoding: utf8);

        // Act
        final headerValue = bodyType.toHeaderValue();

        // Assert
        expect(headerValue, 'text/plain; charset=utf-8');
      });
    });
  });

  test('Given a BodyType with an encoding and a boundary parameter, '
      'when toHeaderValue is called, '
      'then it returns the mimeType, the charset and the boundary.', () {
    final bodyType = BodyType(
      mimeType: MimeType.multipartFormData,
      encoding: utf8,
      parameters: {'boundary': 'abc123'},
    );

    expect(
      bodyType.toHeaderValue(),
      'multipart/form-data; charset=utf-8; boundary=abc123',
    );
  });

  test('Given a BodyType whose parameter value is not a token, '
      'when toHeaderValue is called, '
      'then it writes the value as a quoted string.', () {
    final bodyType = BodyType(
      mimeType: MimeType.multipartFormData,
      parameters: {'boundary': 'a b'},
    );

    expect(bodyType.toHeaderValue(), 'multipart/form-data; boundary="a b"');
  });

  test('Given a BodyType whose parameter value has a line break, '
      'when validate is called, '
      'then it throws FormatException.', () {
    final bodyType = BodyType(
      mimeType: MimeType.multipartFormData,
      parameters: {'boundary': 'abc\r\nX-Injected: 1'},
    );

    expect(bodyType.validate, throwsFormatException);
  });

  test('Given a BodyType created with a mixed-case parameter name, '
      'when its parameters are read, '
      'then the name is lowercase.', () {
    final bodyType = BodyType(
      mimeType: MimeType.multipartFormData,
      parameters: const {'Boundary': 'abc123'},
    );

    expect(bodyType.parameters, {'boundary': 'abc123'});
  });

  test('Given a charset in the parameters, '
      'when a BodyType is created, '
      'then it throws ArgumentError.', () {
    expect(
      () => BodyType(
        mimeType: MimeType.plainText,
        parameters: const {'charset': 'utf-8'},
      ),
      throwsArgumentError,
    );
  });

  test('Given a BodyType whose parameter name is not a token, '
      'when toHeaderValue is called, '
      'then it throws FormatException.', () {
    final bodyType = BodyType(
      mimeType: MimeType.multipartFormData,
      parameters: const {'a b': 'abc123'},
    );

    expect(bodyType.toHeaderValue, throwsFormatException);
  });

  test('Given a body created with a mixed-case parameter name, '
      'when its body type parameters are read, '
      'then the name is lowercase.', () {
    final body = Body.fromData(
      Uint8List(0),
      mimeType: MimeType.multipartFormData,
      parameters: const {'Boundary': 'abc123'},
    );

    expect(body.bodyType!.parameters, {'boundary': 'abc123'});
  });

  test('Given a charset in the parameters, '
      'when a body is created, '
      'then it throws ArgumentError.', () {
    expect(
      () => Body.fromData(
        Uint8List(0),
        mimeType: MimeType.plainText,
        parameters: const {'charset': 'utf-8'},
      ),
      throwsArgumentError,
    );
  });

  test('Given parameters without a mimeType, '
      'when a body is created, '
      'then it throws ArgumentError.', () {
    expect(
      () => Body.fromDataStream(
        const Stream.empty(),
        mimeType: null,
        parameters: const {'boundary': 'abc123'},
      ),
      throwsArgumentError,
    );
  });
}
