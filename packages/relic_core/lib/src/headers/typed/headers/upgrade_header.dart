import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../../../relic_core.dart';
import '../primitives/byte_fields.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;

/// A class representing the HTTP Upgrade header.
///
/// This class manages the protocols that the client supports for upgrading the
/// connection.
final class UpgradeHeader {
  static const codec = HeaderCodec.fields(_parseFields, __encode);
  static List<String> __encode(final UpgradeHeader value) => [value._encode()];

  /// The list of protocols that the client supports.
  final List<UpgradeProtocol> protocols;

  /// Constructs an [UpgradeHeader] instance with the specified protocols.
  UpgradeHeader.protocols(final List<UpgradeProtocol> protocols)
    : assert(protocols.isNotEmpty),
      protocols = List.unmodifiable(protocols);

  /// Parses the Upgrade header value and returns an [UpgradeHeader] instance.
  ///
  /// This method processes the header value, extracting the list of protocols.
  factory UpgradeHeader.parse(final Iterable<String> values) =>
      _parseFields([for (final value in values) latin1Bytes(value)]);

  /// Takes [protocols], a list the parser built, as its own.
  const UpgradeHeader._(this.protocols);

  /// The header from the wire bytes of its [fields].
  static UpgradeHeader _parseFields(final List<Uint8List> fields) {
    final elements = splitFieldsUnique(fields);
    if (elements.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    return UpgradeHeader._(
      List.generate(
        elements.length,
        (final i) => UpgradeProtocol._parseBytes(elements[i]),
        growable: false,
      ),
    );
  }

  /// Converts the [UpgradeHeader] instance into a string representation
  /// suitable for HTTP headers.

  String _encode() {
    return protocols.map((final protocol) => protocol._encode()).join(', ');
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is UpgradeHeader &&
          const ListEquality<UpgradeProtocol>().equals(
            protocols,
            other.protocols,
          );

  @override
  int get hashCode => const ListEquality<UpgradeProtocol>().hash(protocols);

  @override
  String toString() {
    return 'UpgradeHeader(protocols: $protocols)';
  }
}

/// A single protocol entry in an `Upgrade` header.
///
///     protocol         = protocol-name ["/" protocol-version]
///     protocol-name    = token
///     protocol-version = token
///
/// `protocol-version` is therefore an opaque token (e.g. `13` for WebSocket,
/// `2` for HTTP/2, `6.9` for IRC); it is not a number. Storing it as a string
/// preserves whatever the peer sent and avoids `HTTP/2` and `HTTP/2.0`
/// collapsing into the same value on the wire.
class UpgradeProtocol {
  /// The name of the protocol (a token, e.g. `HTTP`, `WebSocket`).
  final String protocol;

  /// The version of the protocol (a token), or `null` when absent.
  final String? version;

  /// Constructs an [UpgradeProtocol] instance with the specified name and version.
  UpgradeProtocol({required final String protocol, final String? version})
    : protocol = Token.validate(protocol),
      version = version == null ? null : Token.validate(version);

  /// Parses a protocol string and returns an [UpgradeProtocol] instance.
  factory UpgradeProtocol.parse(final String value) =>
      UpgradeProtocol._parseBytes(trimmed(latin1Bytes(value)));

  /// [parse] over the wire bytes of one trimmed element.
  static UpgradeProtocol _parseBytes(final Uint8List element) {
    if (element.isEmpty) {
      throw const FormatException('Protocol cannot be empty');
    }
    final slash = indexOfByte(element, 0x2F);
    if (slash < 0) {
      return UpgradeProtocol(protocol: textOf(element));
    }
    if (slash == 0) {
      throw const FormatException('Protocol cannot be empty');
    }
    if (slash == element.length - 1) {
      throw const FormatException('Version cannot be empty');
    }
    return UpgradeProtocol(
      protocol: textOf(element, 0, slash),
      version: textOf(element, slash + 1),
    );
  }

  /// Converts the [UpgradeProtocol] instance into a string representation.
  String _encode() => version != null ? '$protocol/$version' : protocol;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is UpgradeProtocol &&
          protocol == other.protocol &&
          version == other.version;

  @override
  int get hashCode => Object.hash(protocol, version);

  @override
  String toString() {
    return 'UpgradeProtocol(protocol: $protocol, version: $version)';
  }
}
