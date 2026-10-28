import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../../../relic_core.dart';
import '../primitives/byte_fields.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;

/// A class representing the HTTP Connection header.
///
/// This class manages connection directives, such as `keep-alive`, `close`, or multiple
/// directives (e.g., `upgrade, keep-alive`). It provides functionality to parse and generate
/// connection header values.
final class ConnectionHeader {
  static const codec = HeaderCodec.fields(_parseFields, __encode);
  static List<String> __encode(final ConnectionHeader value) => [
    value._encode(),
  ];

  /// A list of connection directives (e.g., `keep-alive`, `close`, `upgrade`).
  final List<ConnectionHeaderType> directives;

  /// Constructs a [ConnectionHeader] instance with the specified connection directives.
  const ConnectionHeader.directives(this.directives);

  /// Parses the Connection header [values] and returns a [ConnectionHeader]
  /// instance.
  ///
  /// The value is split on commas, and each directive trimmed.
  factory ConnectionHeader.parse(final Iterable<String> values) =>
      _parseFields([for (final value in values) latin1Bytes(value)]);

  /// The header from the wire bytes of its [fields].
  static ConnectionHeader _parseFields(final List<Uint8List> fields) {
    final elements = splitFieldsUnique(fields);
    if (elements.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    return ConnectionHeader.directives(
      List.generate(
        elements.length,
        (final i) => ConnectionHeaderType._parseBytes(elements[i]),
        growable: false,
      ),
    );
  }

  /// Checks if the connection is marked as `keep-alive`.
  bool get isKeepAlive => directives.contains(ConnectionHeaderType.keepAlive);

  /// Checks if the connection is marked as `close`.
  bool get isClose => directives.contains(ConnectionHeaderType.close);

  /// Checks if the connection is marked as `upgrade`.
  bool get isUpgrade => directives.contains(ConnectionHeaderType.upgrade);

  /// Converts the [ConnectionHeader] instance into a string representation suitable for HTTP headers.
  ///
  /// This method generates the header string by concatenating the connection directives.
  String _encode() {
    return directives.map((final directive) => directive.value).join(', ');
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ConnectionHeader &&
          const ListEquality<ConnectionHeaderType>().equals(
            directives,
            other.directives,
          );

  @override
  int get hashCode =>
      const ListEquality<ConnectionHeaderType>().hash(directives);

  @override
  String toString() {
    return 'ConnectionHeader(directives: $directives)';
  }
}

/// A class representing the type of connection directives for the Connection header.
class ConnectionHeaderType {
  /// The string representation of the connection directive.
  final String value;

  /// Constructs a [ConnectionHeaderType] instance with the specified value.
  const ConnectionHeaderType._(this.value);

  /// Predefined connection directives.
  static const _keepAlive = 'keep-alive';
  static const _close = 'close';
  static const _upgrade = 'upgrade';

  static const keepAlive = ConnectionHeaderType._(_keepAlive);
  static const close = ConnectionHeaderType._(_close);
  static const upgrade = ConnectionHeaderType._(_upgrade);

  /// Parses a [value] into a [ConnectionHeaderType].
  ///
  /// A `connection-option` is a `token` naming a hop-by-hop field (RFC 9110
  /// 7.6.1), so any valid token is accepted (e.g. `TE`, `Trailer`, custom
  /// hop-by-hop headers), not only the predefined ones. Options are
  /// case-insensitive and canonicalized to lowercase.
  factory ConnectionHeaderType.parse(final String value) =>
      ConnectionHeaderType._parseBytes(trimmed(latin1Bytes(value)));

  /// [parse] over the wire bytes of one trimmed element.
  static ConnectionHeaderType _parseBytes(final Uint8List element) {
    if (element.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    for (final b in element) {
      if (!Token.isTchar(b)) {
        throw FormatException('Invalid token', textOf(element));
      }
    }
    return ConnectionHeaderType._(lowerTextOf(element));
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ConnectionHeaderType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ConnectionHeaderType(value: $value)';
}
