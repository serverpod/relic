import '../../../../relic.dart';
import 'wildcard_list_header.dart';

/// A class representing the HTTP Access-Control-Allow-Methods header.
///
/// This header specifies which methods are allowed when accessing the resource
/// in response to a preflight request.
final class AccessControlAllowMethodsHeader
    extends WildcardListHeader<RequestMethod> {
  static const codec = HeaderCodec(_parse, _encode);

  /// Constructs an instance allowing specific methods to be allowed.
  AccessControlAllowMethodsHeader.methods(
      {required final List<RequestMethod> methods})
      : super(methods);

  /// Constructs an instance allowing all methods to be allowed (`*`).
  const AccessControlAllowMethodsHeader.wildcard() : super.wildcard();

  /// Parses the Access-Control-Allow-Methods header value and returns an
  /// [AccessControlAllowMethodsHeader] instance.
  factory AccessControlAllowMethodsHeader.parse(final Iterable<String> values) {
    return _parse(values);
  }

  /// The list of methods that are allowed
  List<RequestMethod> get methods => values;

  static AccessControlAllowMethodsHeader _parse(final Iterable<String> values) {
    final parsed = WildcardListHeader.parse(values, RequestMethod.parse);

    if (parsed.isWildcard) {
      return const AccessControlAllowMethodsHeader.wildcard();
    } else {
      return AccessControlAllowMethodsHeader.methods(methods: parsed.values);
    }
  }

  static List<String> encodeHeader(
      final AccessControlAllowMethodsHeader header) {
    return header.encode((final RequestMethod rm) => rm.value).toList();
  }

  static List<String> _encode(final AccessControlAllowMethodsHeader header) {
    return encodeHeader(header);
  }
}
