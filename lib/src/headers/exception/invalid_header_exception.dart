/// Exception thrown for invalid HTTP header values.
///
/// This exception is used to indicate that a specific HTTP header contains
/// invalid or malformed data. It provides details about the type of header
/// that caused the error and a description of the issue.
///
/// The error details, including the header type and description, are also
/// available in a formatted string for use in HTTP responses via [httpResponseBody].
class InvalidHeaderException implements Exception {
  /// Detailed description of the error.
  ///
  /// This describes what is wrong with the header value and is included
  /// in the HTTP response body as part of [httpResponseBody].
  final String description;

  /// The type of header that caused the error.
  ///
  /// This indicates which specific header caused the issue (e.g., 'Content-Type')
  /// and is included in the HTTP response body as part of [httpResponseBody].
  final String headerType;

  /// Creates an [InvalidHeaderException] with a [description] describing the error
  /// and the [headerType] indicating the problematic header.
  InvalidHeaderException(
    this.description, {
    required this.headerType,
  });

  /// A formatted description of the error for inclusion in an HTTP response body.
  ///
  /// Combines the [headerType] and [description] to create a readable message:
  /// `Invalid '<headerType>' header: <description>`.
  String get httpResponseBody => 'Invalid \'$headerType\' header: $description';

  @override
  String toString() {
    return 'InvalidHeaderException(description: $description, headerType: $headerType)';
  }
}
