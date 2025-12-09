part of 'ip_address.dart';

/// Represents an IPv6 address with optional CIDR prefix.
///
/// IPv6 addresses consist of 8 hextets (16-bit segments) displayed in
/// hexadecimal notation. The canonical form uses `::` compression for
/// the longest run of consecutive zero hextets (RFC 5952).
///
/// Can be created via [IPv6Address.fromHextets], [IPv6Address.fromSegments],
/// or [IPAddress.parse] for automatic type detection.
///
/// Example:
/// ```dart
/// final ip = IPv6Address.fromHextets(0x2001, 0xdb8, 0, 0, 0, 0, 0, 1);
/// print(ip); // '2001:db8::1' (compressed form)
/// final subnet = IPAddress.parse('fe80::/10');
/// ```
final class IPv6Address extends IPAddress {
  IPv6Address._(super.bytes, {super.prefixLength}) : super._();

  /// Create IPv6 from string
  factory IPv6Address._parse(final String address) {
    final bytes = _parseIPv6String(address);
    return IPv6Address._(bytes);
  }

  /// Create IPv6 from individual hextets
  factory IPv6Address.fromHextets(
    final int a,
    final int b,
    final int c,
    final int d,
    final int e,
    final int f,
    final int g,
    final int h, {
    final int? prefixLength,
  }) {
    final segments = <int>[a, b, c, d, e, f, g, h];
    for (final segment in segments) {
      if (segment < 0 || segment > 0xFFFF) {
        throw ArgumentError('Invalid IPv6 segment: $segment');
      }
    }
    return IPv6Address.fromSegments(
      Uint16List.fromList(segments),
      prefixLength: prefixLength,
    );
  }

  /// Create IPv6 from 8 16-bit [segments], and optional [prefixLength].
  factory IPv6Address.fromSegments(
    final Uint16List segments, {
    final int? prefixLength,
  }) {
    if (segments.length != 8) {
      throw ArgumentError('IPv6 requires exactly 8 segments');
    }
    return IPv6Address._(
      segments.toBigEndianUint8List(),
      prefixLength: prefixLength,
    );
  }

  static Uint8List _parseIPv6String(final String address) {
    // Handle :: expansion
    if (address.contains('::')) {
      final parts = address.split('::');
      if (parts.length != 2) {
        throw FormatException('Invalid IPv6 address: $address');
      }

      final left = parts[0].isEmpty ? <String>[] : parts[0].split(':');
      final right = parts[1].isEmpty ? <String>[] : parts[1].split(':');
      final missing = 8 - left.length - right.length;

      if (missing <= 0) {
        throw FormatException('Invalid IPv6 address: $address');
      }

      final expanded = <String>[
        ...left,
        ...List.filled(missing, '0'),
        ...right,
      ];

      return _segmentsToBytes(expanded);
    }

    final parts = address.split(':');
    if (parts.length != 8) {
      throw FormatException('Invalid IPv6 address: $address');
    }

    return _segmentsToBytes(parts);
  }

  static Uint8List _segmentsToBytes(final List<String> segments) {
    final bytes = Uint8List(16);

    for (int i = 0; i < 8; i++) {
      final segment = segments[i];
      if (segment.length > 4) {
        throw FormatException('Invalid IPv6 segment: $segment');
      }

      final value = int.tryParse(segment, radix: 16);
      if (value == null || value < 0 || value > 0xFFFF) {
        throw FormatException('Invalid IPv6 segment: $segment');
      }

      bytes[i * 2] = (value >> 8) & 0xFF;
      bytes[i * 2 + 1] = value & 0xFF;
    }

    return bytes;
  }

  /// Returns the IPv6 address as a list of 8 16-bit segments (hextets).
  ///
  /// Each segment represents 16 bits of the IPv6 address. For example,
  /// the address `2001:db8::1` would return `[0x2001, 0x0db8, 0, 0, 0, 0, 0, 1]`.
  Uint16List get segments => bytes.toUint16ListFromBigEndian();

  /// Get compressed representation (with :: for zero runs)
  String get _compressed {
    final segments = this.segments;

    // Find longest run of zeros
    int bestStart = -1, bestLength = 0;
    int currentStart = -1, currentLength = 0;

    for (int i = 0; i < 8; i++) {
      if (segments[i] == 0) {
        if (currentStart == -1) currentStart = i;
        currentLength++;
      } else {
        if (currentLength > bestLength) {
          bestStart = currentStart;
          bestLength = currentLength;
        }
        currentStart = -1;
        currentLength = 0;
      }
    }

    // Check final run
    if (currentLength > bestLength) {
      bestStart = currentStart;
      bestLength = currentLength;
    }

    // Only compress if run is 2 or more zeros
    if (bestLength < 2) {
      return segments.map((final s) => s.toRadixString(16)).join(':');
    }

    final before = segments
        .take(bestStart)
        .map((final s) => s.toRadixString(16));
    final after = segments
        .skip(bestStart + bestLength)
        .map((final s) => s.toRadixString(16));

    if (bestStart == 0 && bestStart + bestLength == 8) {
      return '::';
    } else if (bestStart == 0) {
      return '::${after.join(':')}';
    } else if (bestStart + bestLength == 8) {
      return '${before.join(':')}::';
    } else {
      return '${before.join(':')}::${after.join(':')}';
    }
  }

  @override
  late final String _addressString = _compressed; // cache

  /// Common IPv6 addresses
  static final any = IPv6Address.fromSegments(
    Uint16List.fromList([0, 0, 0, 0, 0, 0, 0, 0]),
  );
  static final loopback = IPv6Address.fromSegments(
    Uint16List.fromList([0, 0, 0, 0, 0, 0, 0, 1]),
  );
}
