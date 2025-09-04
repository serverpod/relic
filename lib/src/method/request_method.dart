import '../../relic.dart';

/// Represents the HTTP methods used in requests as constants.
enum RequestMethod {
  /// Predefined HTTP method constants.
  get,
  post,
  put,
  delete,
  patch,
  head,
  options,
  trace,
  connect;

  static final _reverseMap = <String, RequestMethod>{
    for (final r in values) r.name: r
  };

  /// Parses a [method] string and returns the corresponding [RequestMethod] instance.
  ///
  /// Throws an [ArgumentError] if the [method] string is empty.
  /// If the method is not found in the predefined values,
  /// it returns a new [RequestMethod] instance with the method name in uppercase.
  factory RequestMethod.parse(final String method) {
    if (method.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    return _reverseMap[method.trim().toLowerCase()] ??
        (throw FormatException('Invalid value', method));
  }

  String get value => name.toUpperCase();

  static const codec = HeaderCodec.single(RequestMethod.parse, __encode);
  static List<String> __encode(final RequestMethod value) => [value.value];
}
