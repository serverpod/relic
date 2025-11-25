import 'package:collection/collection.dart';

import '../../../../relic.dart';
import '../../extension/string_list_extensions.dart';

/// A class representing the HTTP Upgrade header.
///
/// This class manages the protocols that the client supports for upgrading the
/// connection.
final class UpgradeHeader {
  static const codec = HeaderCodec(UpgradeHeader.parse, __encode);
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
  factory UpgradeHeader.parse(final Iterable<String> values) {
    final splitValues = values.splitTrimAndFilterUnique(separator: ',');
    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    final protocols =
        splitValues
            .map((final protocol) => UpgradeProtocol.parse(protocol))
            .toList();

    return UpgradeHeader.protocols(protocols);
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

/// A class representing a single protocol in the Upgrade header.
class UpgradeProtocol {
  /// The name of the protocol.
  final String protocol;

  /// The version of the protocol.
  final double? version;

  /// Constructs an [UpgradeProtocol] instance with the specified name and version.
  UpgradeProtocol({required this.protocol, this.version});

  /// Parses a protocol string and returns an [UpgradeProtocol] instance.
  factory UpgradeProtocol.parse(final String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Protocol cannot be empty');
    }

    final split = trimmed.split('/');
    if (split.length == 1) {
      return UpgradeProtocol(protocol: split[0]);
    }

    final protocol = split[0];
    if (protocol.isEmpty) {
      throw const FormatException('Protocol cannot be empty');
    }

    final version = split[1];
    if (version.isEmpty) {
      throw const FormatException('Version cannot be empty');
    }

    final parsedVersion = double.tryParse(version);
    if (parsedVersion == null) {
      throw const FormatException('Invalid version');
    }

    return UpgradeProtocol(protocol: protocol, version: parsedVersion);
  }

  /// Converts the [UpgradeProtocol] instance into a string representation.
  String _encode() => '$protocol${version != null ? '/$version' : ''}';

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
