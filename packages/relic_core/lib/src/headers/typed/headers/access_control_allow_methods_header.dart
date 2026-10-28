import 'dart:typed_data';

import '../../../../relic_core.dart';
import '../primitives/byte_scanner.dart' show latin1Bytes;
import 'wildcard_list_header.dart';

/// A class representing the HTTP Access-Control-Allow-Methods header.
///
/// This header specifies which methods are allowed when accessing the resource
/// in response to a preflight request.
final class AccessControlAllowMethodsHeader extends WildcardListHeader<Method> {
  static const codec = HeaderCodec.fields(_parseFields, _encode);

  /// Constructs an instance allowing specific methods to be allowed.
  AccessControlAllowMethodsHeader.methods(super.methods);

  /// Constructs an instance allowing all methods to be allowed (`*`).
  const AccessControlAllowMethodsHeader.wildcard() : super.wildcard();

  /// Parses the Access-Control-Allow-Methods header value and returns an
  /// [AccessControlAllowMethodsHeader] instance.
  factory AccessControlAllowMethodsHeader.parse(
    final Iterable<String> values,
  ) => _parseFields([for (final value in values) latin1Bytes(value)]);

  AccessControlAllowMethodsHeader._owned(super.methods) : super.owned();

  /// The list of methods that are allowed
  List<Method> get methods => values;

  /// The header from the wire bytes of its [fields].
  static AccessControlAllowMethodsHeader _parseFields(
    final List<Uint8List> fields,
  ) {
    final parsed = WildcardListHeader.parseFields(fields, parseMethodBytes);
    if (parsed.isWildcard) {
      return const AccessControlAllowMethodsHeader.wildcard();
    }
    return AccessControlAllowMethodsHeader._owned(parsed.values);
  }

  static List<String> encodeHeader(
    final AccessControlAllowMethodsHeader header,
  ) {
    return header.encode((final Method m) => m.value).toList();
  }

  static List<String> _encode(final AccessControlAllowMethodsHeader header) {
    return encodeHeader(header);
  }
}
