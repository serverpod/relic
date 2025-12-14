/// Represents the HTTP methods used in requests as constants.
enum Method {
  get,
  head,
  post,
  put,
  delete,
  patch,
  options,
  trace,
  connect;

  static final _reverseMap = <String, Method>{
    for (final r in values) r.name: r,
  };

  /// Parses a [method] string and returns the corresponding [Method] instance.
  ///
  /// Throws an [FormatException] if the [method] string is invalid.
  factory Method.parse(final String method) {
    final trimmed = method.trim();
    if (trimmed.isEmpty) throw const FormatException('Value cannot be empty');
    return _reverseMap[trimmed.toLowerCase()] ??
        (throw FormatException('Invalid value', method));
  }

  String get value => name.toUpperCase();
}
