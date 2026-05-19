/// A non-negative integer number of seconds, used by HTTP headers that carry
/// `delta-seconds` values: `Max-Age` (RFC 9111 5.2.2.1, RFC 6265 5.2.2),
/// `Retry-After` seconds form (RFC 9110 10.2.3), HSTS `max-age` (RFC 6797 6.1),
/// and the second form of `Retry-After`.
///
///     delta-seconds  = 1*DIGIT
///
/// The grammar forbids leading sign characters and any non-digit. Zero is
/// valid (often used to mean "expire immediately" or "clear state now").
extension type const DeltaSeconds._(int seconds) {
  /// Creates a [DeltaSeconds] from [seconds], throwing [FormatException] if
  /// the value is negative.
  factory DeltaSeconds(final int seconds) {
    if (seconds < 0) {
      throw FormatException(
        'delta-seconds must be non-negative',
        seconds.toString(),
      );
    }
    return DeltaSeconds._(seconds);
  }

  /// Parses [source] as `1*DIGIT` per RFC 9110 5.6.1.
  ///
  /// Throws [FormatException] if [source] is empty, contains non-DIGIT
  /// characters, or carries a leading sign / whitespace.
  factory DeltaSeconds.parse(final String source) {
    if (source.isEmpty) {
      throw const FormatException('delta-seconds cannot be empty');
    }
    for (var i = 0; i < source.length; i++) {
      final c = source.codeUnitAt(i);
      if (c < 0x30 || c > 0x39) {
        throw FormatException(
          'delta-seconds must be 1*DIGIT (RFC 9110 5.6.1)',
          source,
          i,
        );
      }
    }
    return DeltaSeconds._(int.parse(source));
  }

  /// The wire representation: the decimal digits of [seconds].
  String encode() => seconds.toString();
}
