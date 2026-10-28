import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:http_parser/http_parser.dart';
import '../../../../relic_core.dart';
import '../primitives/byte_fields.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;

// RFC 7230: HTTP/1.1 Message Syntax
// token = 1*tchar
// tchar = "!" / "#" / "$" / "%" / "&" / "'" / "*" /
//         "+" / "-" / "." / "^" / "_" / "`" / "|" / "~" /
//         DIGIT / ALPHA
final _isTokenRegExp = RegExp(r"^[a-zA-Z0-9!#$%&'*+-.^_`|~]+$");
bool _isToken(final String s) => _isTokenRegExp.hasMatch(s);

/// The text of [value], a trimmed parameter value, with the quotes of a
/// quoted-string removed and `\\` and `\"` unescaped.
///
/// A minimal unescaper: quoted-pair = "\" ( DQUOTE / "\" ). A full one
/// handles every qdtext and quoted-pair.
String _unquote(final Uint8List value) {
  if (value.length >= 2 &&
      value[0] == 0x22 &&
      value[value.length - 1] == 0x22) {
    return textOf(
      value,
      1,
      value.length - 1,
    ).replaceAll(r'\\', r'\').replaceAll(r'\"', '"');
  }
  return textOf(value);
}

String _quote(final String rawValue) {
  // If rawValue is not a valid token, it must be a quoted-string.
  if (!_isToken(rawValue)) {
    // Minimal escaping for characters within a quoted-string:
    final escaped = rawValue.replaceAll(r'\', r'\\').replaceAll(r'"', r'\"');
    return '"$escaped"';
  }
  return rawValue;
}

/// Represents a node identifier in the Forwarded header, as per RFC 7239 Section 6.
/// This can be an IP address (v4 or v6), "unknown", or an obfuscated identifier,
/// optionally with a port.
final class ForwardedIdentifier {
  /// The main identifier part (e.g., "192.0.2.43", "[2001:db8::1]", "unknown", "_obfuscated").
  final String identifier;

  /// The optional port part (e.g., "8080", "_obfport").
  final String? port;

  const ForwardedIdentifier(this.identifier, [this.port]);

  /// Parses a string value (which should be unquoted if it was a quoted-string)
  /// into a [ForwardedIdentifier].
  factory ForwardedIdentifier.parse(final String value) =>
      ForwardedIdentifier._parseBytes(trimmed(latin1Bytes(value)));

  /// [parse] over the wire bytes of a trimmed value.
  static ForwardedIdentifier _parseBytes(final Uint8List bytes) {
    final value = textOf(bytes);
    if (value.startsWith('[')) {
      if (value.endsWith(']')) {
        // Case 1: IPv6 address like "[2001:db8::1]" (no port)
        return ForwardedIdentifier(value);
      }
      // Ensure structure is [IPv6]:port and not something more complex or malformed
      final closingBracketIndex = value.indexOf(']:');
      if (closingBracketIndex != -1 &&
          // No other ']' after ']:'
          value.indexOf(']', closingBracketIndex + 1) == -1 &&
          // No other ':' after ']:'
          value.indexOf(':', closingBracketIndex + 2) == -1 &&
          // No other '[' after the first one
          value.indexOf('[', 1) == -1) {
        // Case 2: IPv6 address with port like "[2001:db8::1]:8080"
        return ForwardedIdentifier(
          value.substring(0, closingBracketIndex + 1),
          value.substring(closingBracketIndex + 2),
        );
      } else {
        // Malformed or too complex, treat the whole thing as the identifier
        return ForwardedIdentifier(value);
      }
    } else {
      // Case 3: IPv4, "unknown", or obfuscated node, possibly with a port
      final lastColonIndex = value.lastIndexOf(':');
      if (lastColonIndex != -1) {
        return ForwardedIdentifier(
          value.substring(0, lastColonIndex),
          value.substring(lastColonIndex + 1),
        );
      } else {
        // No port
        return ForwardedIdentifier(value);
      }
    }
  }

  /// Returns the string representation of this node as it would appear as a
  /// value in a forwarded-pair (before potential quoting).
  String toValueString() {
    if (port != null) {
      return '$identifier:$port';
    }
    return identifier;
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ForwardedIdentifier &&
          identifier == other.identifier &&
          port == other.port;

  @override
  int get hashCode => Object.hash(identifier, port);

  @override
  String toString() => 'ForwardedNode(identifier: $identifier, port: $port)';
}

/// Represents one `forwarded-element` in the `Forwarded` header.
final class ForwardedElement {
  /// The `for` parameter value.
  final ForwardedIdentifier? forwardedFor;

  /// The `by` parameter value.
  final ForwardedIdentifier? by;

  /// The `proto` parameter value.
  final String? proto;

  /// The `host` parameter value.
  final String? host;

  /// Any extension parameters. Keys are case-insensitive.
  final Map<String, String>? extensions;

  ForwardedElement({
    this.forwardedFor,
    this.by,
    this.proto,
    this.host,
    final Map<String, String>? extensions,
  }) : extensions = extensions != null && extensions.isNotEmpty
           ? CaseInsensitiveMap<String>.from(extensions)
           : null;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ForwardedElement &&
          forwardedFor == other.forwardedFor &&
          by == other.by &&
          proto == other.proto &&
          host == other.host &&
          const MapEquality<String, String>().equals(
            extensions,
            other.extensions,
          );

  @override
  int get hashCode => Object.hashAll([
    forwardedFor,
    by,
    proto,
    host,
    ...[
      extensions != null
          ? const MapEquality<String, String>().hash(extensions)
          : 0,
    ],
  ]);

  @override
  String toString() =>
      'ForwardedElement(by: $by, for: $forwardedFor, host: $host, proto: $proto, extensions: $extensions)';
}

/// Typed representation of the `Forwarded` HTTP header.
/// It's a list of [ForwardedElement]s.
///
// RFC 7239: Forwarded HTTP Extension
// Forwarded   = 1#forwarded-element
// forwarded-element = [ forwarded-pair ] *( ";" [ forwarded-pair ] )
// forwarded-pair = token "=" value
// value          = token / quoted-string
final class ForwardedHeader {
  static const codec = HeaderCodec.fields(_parseFields, __encode);
  static List<String> __encode(final ForwardedHeader value) =>
      value.toStrings().toList();

  final List<ForwardedElement> elements;

  ForwardedHeader(final List<ForwardedElement> elements)
    : assert(elements.isNotEmpty),
      elements = List.unmodifiable(elements);

  factory ForwardedHeader.parse(final Iterable<String> values) =>
      _parseFields([for (final value in values) latin1Bytes(value)]);

  /// Takes [elements], a list the parser built, as its own.
  const ForwardedHeader._(this.elements);

  /// [parse] over the wire bytes of every field.
  ///
  /// Elements split on commas, their pairs on `;`, which fails for a
  /// quoted-string containing the delimiter, see
  /// https://github.com/serverpod/relic/issues/102.
  static ForwardedHeader _parseFields(final List<Uint8List> fields) {
    final elements = splitFieldsUnique(fields);
    if (elements.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }
    final allElements = <ForwardedElement>[];
    for (final element in elements) {
      ForwardedIdentifier? byNode;
      ForwardedIdentifier? forNode;
      String? hostStr;
      String? protoStr;
      final extensionsMap = <String, String>{};
      var pairStart = 0;
      while (pairStart <= element.length) {
        var pairEnd = indexOfByte(element, 0x3B, pairStart);
        final next = pairEnd < 0 ? element.length + 1 : pairEnd + 1;
        if (pairEnd < 0) pairEnd = element.length;
        // A pair is `token "=" value` with exactly one `=` and something
        // on both sides of it.
        final eq = indexOfByte(element, 0x3D, pairStart, pairEnd);
        if (eq < 0 ||
            eq == pairStart ||
            eq + 1 == pairEnd ||
            indexOfByte(element, 0x3D, eq + 1, pairEnd) >= 0) {
          pairStart = next;
          continue;
        }
        // Parameter names are case-insensitive.
        final key = lowerTextOf(trimmed(element, pairStart, eq));
        final value = _unquote(trimmed(element, eq + 1, pairEnd));
        switch (key) {
          case 'by':
            byNode = ForwardedIdentifier.parse(value);
          case 'for':
            forNode = ForwardedIdentifier.parse(value);
          case 'host':
            hostStr = value;
          case 'proto':
            protoStr = value;
          default:
            extensionsMap[key] = value;
        }
        pairStart = next;
      }
      if (forNode != null ||
          byNode != null ||
          protoStr != null ||
          hostStr != null ||
          extensionsMap.isNotEmpty) {
        allElements.add(
          ForwardedElement(
            forwardedFor: forNode,
            by: byNode,
            proto: protoStr,
            host: hostStr,
            extensions: extensionsMap,
          ),
        );
      }
    }
    if (allElements.isEmpty) throw const FormatException('');
    return ForwardedHeader._(allElements);
  }

  Iterable<String> toStrings() {
    if (elements.isEmpty) return [];

    final elementsAsStrings = <String>[];
    for (final element in elements) {
      final pairs = <String>[];
      final forwardedFor = element.forwardedFor;
      if (forwardedFor != null) {
        pairs.add('for=${_quote(forwardedFor.toValueString())}');
      }
      final by = element.by;
      if (by != null) {
        pairs.add('by=${_quote(by.toValueString())}');
      }
      final proto = element.proto;
      if (proto != null) {
        pairs.add('proto=${_quote(proto)}');
      }
      final host = element.host;
      if (host != null) {
        pairs.add('host=${_quote(host)}');
      }
      final extensions = element.extensions;
      if (extensions != null) {
        extensions.forEach((final key, final value) {
          pairs.add('$key=${_quote(value)}');
        });
      }
      if (pairs.isNotEmpty) {
        elementsAsStrings.add(pairs.join(';'));
      }
    }
    return [elementsAsStrings.join(', ')];
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ForwardedHeader &&
          const ListEquality<ForwardedElement>().equals(
            elements,
            other.elements,
          );

  @override
  int get hashCode => Object.hashAll(elements);

  @override
  String toString() => 'ForwardedHeader(elements: $elements)';
}
