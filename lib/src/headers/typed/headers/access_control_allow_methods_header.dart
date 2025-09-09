import 'package:collection/collection.dart';

import '../../../../relic.dart';
import '../../extension/string_list_extensions.dart';

/// A class representing the HTTP Access-Control-Allow-Methods header.
///
/// This header specifies which methods are allowed when accessing the resource
/// in response to a preflight request.
final class AccessControlAllowMethodsHeader {
  static const codec =
      HeaderCodec(AccessControlAllowMethodsHeader.parse, __encode);
  static List<String> __encode(final AccessControlAllowMethodsHeader value) =>
      [value._encode()];

  /// The list of methods that are allowed.
  final List<RequestMethod> methods;

  /// Whether all methods are allowed (`*`).
  final bool isWildcard;

  /// Constructs an instance allowing specific methods to be allowed.
  AccessControlAllowMethodsHeader.methods(
      {required final List<RequestMethod> methods})
      : assert(methods.isNotEmpty),
        methods = List.unmodifiable(methods),
        isWildcard = false;

  /// Constructs an instance allowing all methods to be allowed (`*`).
  const AccessControlAllowMethodsHeader.wildcard()
      : methods = const [],
        isWildcard = true;

  /// Parses the Access-Control-Allow-Methods header value and returns an
  /// [AccessControlAllowMethodsHeader] instance.
  factory AccessControlAllowMethodsHeader.parse(final Iterable<String> values) {
    final splitValues = values.splitTrimAndFilterUnique();
    if (splitValues.isEmpty) {
      throw const FormatException(
        'Value cannot be empty',
      );
    }

    if (splitValues.length == 1 && splitValues.first == '*') {
      return const AccessControlAllowMethodsHeader.wildcard();
    }

    if (splitValues.length > 1 && splitValues.contains('*')) {
      throw const FormatException(
        'Wildcard (*) cannot be used with other values',
      );
    }

    return AccessControlAllowMethodsHeader.methods(
      methods: splitValues.map(RequestMethod.parse).toList(),
    );
  }

  /// Converts the [AccessControlAllowMethodsHeader] instance into a string
  /// representation suitable for HTTP headers.

  String _encode() =>
      isWildcard ? '*' : methods.map((final m) => m.value).join(', ');

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is AccessControlAllowMethodsHeader &&
          isWildcard == other.isWildcard &&
          const ListEquality<RequestMethod>().equals(methods, other.methods);

  @override
  int get hashCode => Object.hash(
      isWildcard, const ListEquality<RequestMethod>().hash(methods));

  @override
  String toString() =>
      'AccessControlAllowMethodsHeader(methods: $methods, isWildcard: $isWildcard)';
}
