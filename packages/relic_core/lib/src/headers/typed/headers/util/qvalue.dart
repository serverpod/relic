/// Formats an HTTP quality value (`qvalue`, RFC 9110 12.4.2) with at most 3
/// fractional digits, truncating toward zero so a value just under 1.0 is not
/// rounded up to `1` (which would change the advertised preference).
///
/// Trailing zeros are stripped (`0.500` -> `0.5`), and the bounds render as
/// `0` and `1`.
String formatQValue(final double q) {
  if (q <= 0) return '0';
  if (q >= 1) return '1';
  // Truncate toward zero to 3 fractional digits. Computing the millis with
  // floor (not toStringAsFixed, which rounds) keeps e.g. 0.99996 as 0.999
  // rather than rounding it up to 1. The tiny epsilon absorbs binary-float
  // error so an exact value like 0.001 does not floor to 0.
  final millis = (q * 1000 + 1e-9).floor();
  if (millis <= 0) return '0';
  if (millis >= 1000) return '1';
  var s = '0.${millis.toString().padLeft(3, '0')}';
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}
