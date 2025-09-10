/// [HeaderException] serves as the common supertype for specific exceptions that
/// can occur when processing HTTP headers.
///
/// The error details, including the header type and description, are also
/// available in a formatted string for use in HTTP responses via [httpResponseBody].
///
/// Specific subtypes include:
/// - [InvalidHeaderException]: For malformed or invalid header values
/// - [MissingHeaderException]: For required headers that are absent
sealed class HeaderException implements Exception {
  /// Detailed description of the error.
  ///
  /// This describes what is wrong with the header value and is included
  /// in the HTTP response body as part of [httpResponseBody].
  final String description;

  /// The type of header that caused the error.
  ///
  /// This indicates which specific header caused the issue (e.g., 'Content-Type')
  /// and should be included in the HTTP response body as part of [httpResponseBody].
  final String headerType;

  const HeaderException(this.description, {required this.headerType});

  /// A formatted description of the error for inclusion in an HTTP response body.
  String get httpResponseBody;
}

/// Exception thrown for invalid HTTP header values.
///
/// This exception is used to indicate that a specific HTTP header contains
/// invalid or malformed data. It provides details about the type of header
/// that caused the error and a description of the issue.
///
/// The error details, including the header type and description, are also
/// available in a formatted string for use in HTTP responses via [httpResponseBody].
class InvalidHeaderException extends HeaderException {
  /// The raw header values that caused the error.
  ///
  /// This can be useful for debugging purposes to see what values were provided.
  final Iterable<String> raw;

  /// Creates an [InvalidHeaderException] with a [description] describing the error
  /// and the [headerType] indicating the problematic header.
  const InvalidHeaderException(super.description,
      {required super.headerType, this.raw = const []});

  @override
  String get httpResponseBody => "Invalid '$headerType' header: $description";

  @override
  String toString() =>
      'InvalidHeaderException(description: $description, headerType: $headerType, raw: $raw)';
}

/// Exception thrown when a required HTTP header is missing.
///
/// This exception indicates that a header that was expected or required
/// for processing a request was not provided. It provides information about
/// which header was missing through the [headerType] property.
///
/// The error details can be formatted for use in HTTP responses via
/// the [httpResponseBody] property.
class MissingHeaderException extends HeaderException {
  /// Creates a [MissingHeaderException] with a [description] of why the header
  /// is required and the [headerType] indicating which header was missing.
  ///
  /// Use this exception when a required HTTP header is not present in a request
  /// where it is expected or mandatory for proper processing.
  const MissingHeaderException(super.description, {required super.headerType});

  @override
  String get httpResponseBody => "Missing '$headerType' header";

  @override
  String toString() =>
      'MissingHeaderException(description: $description, headerType: $headerType)';
}
