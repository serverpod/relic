import 'package:collection/collection.dart';
import 'package:http_parser/http_parser.dart';
import '../../../../relic.dart';
import '../../extension/string_list_extensions.dart';

// RFC 7230: HTTP/1.1 Message Syntax
// token = 1*tchar
// tchar = "!" / "#" / "$" / "%" / "&" / "'" / "*" /
//         "+" / "-" / "." / "^" / "_" / "`" / "|" / "~" /
//         DIGIT / ALPHA
final _isTokenRegExp = RegExp(r"^[a-zA-Z0-9!#$%&'*+-.^_`|~]+$");
bool _isToken(final String s) => _isTokenRegExp.hasMatch(s);

String _unquote(final String value) {
  if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
    final inner = value.substring(1, value.length - 1);
    // Minimal unescaping for relevant characters in quoted-string:
    // quoted-pair = "\" ( DQUOTE / "\" )
    // This is a simplified unescaper. A full one handles all qdtext/quoted-pair.
    // Fx. r'\t', r'\n', etc
    return inner.replaceAll(r'\\', r'\').replaceAll(r'\"', '"');
  }
  return value;
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
  factory ForwardedIdentifier.parse(String value) {
    value = value.trim();
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
  }) : extensions =
           extensions != null && extensions.isNotEmpty
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
  static const codec = HeaderCodec(ForwardedHeader.parse, __encode);
  static List<String> __encode(final ForwardedHeader value) =>
      value.toStrings().toList();

  final List<ForwardedElement> elements;

  ForwardedHeader(final List<ForwardedElement> elements)
    : assert(elements.isNotEmpty),
      elements = List.unmodifiable(elements);

  factory ForwardedHeader.parse(final Iterable<String> values) {
    final splitValues = values.splitTrimAndFilterUnique();

    if (splitValues.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    final allElements = <ForwardedElement>[];
    for (final elementStr in splitValues) {
      if (elementStr.isEmpty) continue;

      ForwardedIdentifier? byNode;
      ForwardedIdentifier? forNode;
      String? hostStr;
      String? protoStr;
      final extensionsMap = <String, String>{};

      // TODO: Simple split. Fails for quoted strings containing the delimiter.
      // see https://github.com/serverpod/relic/issues/102
      final pairStrings = elementStr.split(';');

      for (final pairStr in pairStrings) {
        final parts = pairStr.split('=');
        if (parts.length != 2) continue;
        if (parts[0].isEmpty) continue;
        if (parts[1].isEmpty) continue;

        final key =
            parts[0]
                .trim()
                .toLowerCase(); // Parameter names are case-insensitive
        String value = parts[1].trim();
        value = _unquote(value); // Unquote if it's a quoted-string

        switch (key) {
          case 'by':
            byNode = ForwardedIdentifier.parse(value);
            break;
          case 'for':
            forNode = ForwardedIdentifier.parse(value);
            break;
          case 'host':
            hostStr = value;
            break;
          case 'proto':
            protoStr = value;
            break;
          default:
            // Store as an extension parameter
            extensionsMap[key] = value;
            break;
        }
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

    return ForwardedHeader(allElements);
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
