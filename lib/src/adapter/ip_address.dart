import 'dart:typed_data';

import 'package:meta/meta.dart';

@immutable
sealed class IPAddress {
  final Uint8List bytes; // immutable, network order (big-endian)

  IPAddress._(final Uint8List bytes)
      : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  /// Factory constructor for automatic type detection
  factory IPAddress.parse(final String address) {
    if (address.contains(':')) {
      return IPv6Address._parse(address);
    } else {
      return IPv4Address._parse(address);
    }
  }

  /// Create from raw bytes
  factory IPAddress.fromBytes(final Uint8List bytes) {
    return switch (bytes.length) {
      4 => IPv4Address._(bytes),
      16 => IPv6Address._(bytes),
      _ => throw ArgumentError('Invalid byte length: ${bytes.length}'),
    };
  }

  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) return true;
    if (other is! IPAddress) return false;
    return _bytesEqual(bytes, other.bytes);
  }

  static bool _bytesEqual(final Uint8List a, final Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  late final int _hash = Object.hashAll(bytes);
  @override
  int get hashCode => _hash;
}

/// IPv4 address implementation
final class IPv4Address extends IPAddress {
  IPv4Address._(super.bytes) : super._();

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
      final int a, final int b, final int c, final int d) {
    final bytes = <int>[a, b, c, d];
    for (final segment in bytes) {
      if (segment < 0 || segment > 0xFF) {
        throw ArgumentError('Invalid IPv4 segment: $segment');
      }
    }
    return IPv4Address._(Uint8List.fromList(bytes));
  }

  /// Create IPv4 from 32-bit integer
  factory IPv4Address.fromInt(final int value) {
    if (value < 0 || value > 0xFFFFFFFF) {
      throw ArgumentError('IPv4 integer out of range: $value');
    }
    return IPv4Address.fromOctets(
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    );
  }

  late final String _string = bytes.join('.');
  @override
  String toString() => _string;

  /// Common IPv4 addresses
  static final any = IPv4Address.fromOctets(0, 0, 0, 0);
  static final loopback = IPv4Address.fromOctets(127, 0, 0, 1);
  static final broadcast = IPv4Address.fromOctets(255, 255, 255, 255);
}

/// IPv6 address implementation
final class IPv6Address extends IPAddress {
  IPv6Address._(super.bytes) : super._();

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
    final int h,
  ) {
    final segments = <int>[a, b, c, d, e, f, g, h];
    for (final segment in segments) {
      if (segment < 0 || segment > 0xFFFF) {
        throw ArgumentError('Invalid IPv6 segment: $segment');
      }
    }
    return IPv6Address.fromSegments(Uint16List.fromList(segments));
  }

  /// Create IPv6 from 8 16-bit segments
  factory IPv6Address.fromSegments(final Uint16List segments) {
    if (segments.length != 8) {
      throw ArgumentError('IPv6 requires exactly 8 segments');
    }
    return IPv6Address._(segments.toBigEndianUint8List());
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

  /// Get segments as a list of 16-bit integers
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

    final before =
        segments.take(bestStart).map((final s) => s.toRadixString(16));
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

  late final String _string = _compressed; // cache
  @override
  String toString() => _string;

  /// Common IPv6 addresses
  static final any =
      IPv6Address.fromSegments(Uint16List.fromList([0, 0, 0, 0, 0, 0, 0, 0]));
  static final loopback =
      IPv6Address.fromSegments(Uint16List.fromList([0, 0, 0, 0, 0, 0, 0, 1]));
}

extension Uint16ListConversionExtensions on Uint16List {
  /// Converts this Uint16List to a Uint8List, ensuring big-endian byte order.
  ///
  /// Each 16-bit integer is converted to two bytes, with the most significant
  /// byte first.
  ///
  /// Example:
  /// ```dart
  /// final u16list = Uint16List.fromList([0x1234, 0xABCD]);
  /// final u8list = u16list.toBigEndianUint8List();
  /// // u8list will be [0x12, 0x34, 0xAB, 0xCD]
  /// ```
  Uint8List toBigEndianUint8List() {
    // If the host system is already big-endian, we can create a view directly.
    if (Endian.host == Endian.big) {
      // Ensure we are viewing the correct segment of the buffer, especially if this is a sublist.
      return buffer.asUint8List(offsetInBytes, lengthInBytes);
    } else {
      final Uint8List resultBytes = Uint8List(length * 2);
      final ByteData byteDataView = ByteData.view(resultBytes.buffer);

      for (int i = 0; i < length; i++) {
        byteDataView.setUint16(i * 2, this[i], Endian.big);
      }
      return resultBytes;
    }
  }
}

extension Uint8ListConversionExtensions on Uint8List {
  /// Converts this Uint8List (assumed to represent data in big-endian byte order)
  /// to a Uint16List.
  ///
  /// Each pair of bytes from this list is interpreted as a big-endian 16-bit integer.
  /// The length of this Uint8List must be an even number.
  ///
  /// Throws [ArgumentError] if the list length is odd.
  ///
  /// Example:
  /// ```dart
  /// final u8list = Uint8List.fromList([0x12, 0x34, 0xAB, 0xCD]); // Big-endian data
  /// final u16list = u8list.toUint16ListFromBigEndian();
  /// // u16list will be [0x1234, 0xABCD]
  /// ```
  Uint16List toUint16ListFromBigEndian() {
    if (lengthInBytes % 2 != 0) {
      throw ArgumentError(
          'Uint8List length must be even to be converted to Uint16List. Length was $lengthInBytes.');
    }
    if (isEmpty) {
      return Uint16List(0);
    }

    // If the host system is already big-endian, and our source Uint8List is big-endian,
    // we can directly view the buffer as Uint16List.
    if (Endian.host == Endian.big) {
      // Ensure we are viewing the correct segment of the buffer.
      return buffer.asUint16List(offsetInBytes, lengthInBytes ~/ 2);
    } else {
      final int resultLength = lengthInBytes ~/ 2;
      final Uint16List resultList = Uint16List(resultLength);
      final ByteData byteDataView =
          ByteData.view(buffer, offsetInBytes, lengthInBytes);

      for (int i = 0; i < resultLength; i++) {
        resultList[i] = byteDataView.getUint16(i * 2, Endian.big);
      }
      return resultList;
    }
  }
}
