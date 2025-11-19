part of 'ip_address.dart';

/// Represents an IPv4 address with optional CIDR prefix.
///
/// IPv4 addresses consist of 4 octets (bytes) ranging from 0-255.
/// Can be created via [IPv4Address.fromOctets], [IPv4Address.fromInt],
/// or [IPAddress.parse] for automatic type detection.
///
/// Example:
/// ```dart
/// final ip = IPv4Address.fromOctets(192, 168, 1, 1);
/// final subnet = IPAddress.parse('10.0.0.0/8');
/// print(ip.toInt()); // 3232235777
/// ```
final class IPv4Address extends IPAddress {
  IPv4Address._(super.bytes, {super.prefixLength}) : super._();

  /// Create IPv4 from string
  factory IPv4Address._parse(final String address) {
    final parts = address.split('.');
    if (parts.length != 4) {
      throw FormatException('Invalid IPv4 address: $address');
    }

    final bytes = Uint8List(4);
    for (int i = 0; i < 4; i++) {
      final octet = int.tryParse(parts[i]);
      if (octet == null || octet < 0 || octet > 255) {
        throw FormatException('Invalid IPv4 octet: ${parts[i]}');
      }
      bytes[i] = octet;
    }

    return IPv4Address._(bytes);
  }

  /// Create IPv4 from individual octets
  factory IPv4Address.fromOctets(
    final int a,
    final int b,
    final int c,
    final int d, {
    final int? prefixLength,
  }) {
    final bytes = <int>[a, b, c, d];
    for (final octet in bytes) {
      if (octet < 0 || octet > 0xFF) {
        throw ArgumentError('Invalid IPv4 octet: $octet');
      }
    }
    return IPv4Address._(Uint8List.fromList(bytes), prefixLength: prefixLength);
  }

  /// Create IPv4 from 32-bit integer
  factory IPv4Address.fromInt(final int value, {final int? prefixLength}) {
    if (value < 0 || value > 0xFFFFFFFF) {
      throw ArgumentError('IPv4 integer out of range: $value');
    }
    return IPv4Address.fromOctets(
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
      prefixLength: prefixLength,
    );
  }

  /// Convert to 32-bit integer representation
  int toInt() {
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  @override
  late final String _addressString = bytes.join('.');

  /// Common IPv4 addresses
  static final any = IPv4Address.fromOctets(0, 0, 0, 0);
  static final loopback = IPv4Address.fromOctets(127, 0, 0, 1);
  static final broadcastAddr = IPv4Address.fromOctets(255, 255, 255, 255);
}
