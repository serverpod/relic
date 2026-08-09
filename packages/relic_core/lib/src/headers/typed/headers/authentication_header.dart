import 'package:collection/collection.dart';

import '../../../../relic_core.dart';
import 'util/auth_params.dart';

/// A class representing the HTTP Authentication header.
final class AuthenticationHeader {
  static const codec = HeaderCodec.single(AuthenticationHeader.parse, __encode);
  static List<String> __encode(final AuthenticationHeader value) => [
    value._encode(),
  ];

  /// The authentication scheme (e.g., "Basic", "Bearer", "Digest").
  final String scheme;

  /// The parameters associated with the authentication scheme.
  final List<AuthenticationParameter> parameters;

  const AuthenticationHeader._({
    required this.scheme,
    required this.parameters,
  });

  /// Constructs an [AuthenticationHeader] instance with the specified scheme and parameters.
  AuthenticationHeader({
    required this.scheme,
    required final List<AuthenticationParameter> parameters,
  }) : parameters = List.unmodifiable(parameters);

  /// Parses the Authentication header value and returns an [AuthenticationHeader] instance.
  factory AuthenticationHeader.parse(final String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Value cannot be empty');
    }

    // Split into scheme and parameters part
    final firstSpace = trimmed.indexOf(' ');
    if (firstSpace == -1) {
      throw const FormatException('Missing scheme or parameters');
    }

    final scheme = trimmed.substring(0, firstSpace).trim();
    final paramsString = trimmed.substring(firstSpace + 1).trim();
    final parameters = <AuthenticationParameter>[];

    if (paramsString.isNotEmpty) {
      final authParams = _tryParseAuthParams(paramsString);
      if (authParams == null) {
        parameters.add(AuthenticationParameter('', paramsString));
      } else {
        parameters.addAll(authParams);
      }
    }

    return AuthenticationHeader._(scheme: scheme, parameters: parameters);
  }

  /// Parses [value] as an `#auth-param` list, returning `null` if it is not
  /// one so the caller can fall back to the `token68` form.
  static List<AuthenticationParameter>? _tryParseAuthParams(
    final String value,
  ) {
    final List<(String, String)> params;
    try {
      params = parseAuthParams(value);
    } on FormatException {
      return null;
    }
    if (params.isEmpty) return null;
    return [
      for (final (name, paramValue) in params)
        AuthenticationParameter(name, paramValue),
    ];
  }

  /// Converts the [AuthenticationHeader] instance into a string representation
  /// suitable for HTTP headers.
  String _encode() {
    final paramsString = parameters
        .map((final param) {
          if (param.key.isEmpty) return param.value;
          return '${param.key}="${param.value}"';
        })
        .join(', ');
    return '$scheme $paramsString';
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is AuthenticationHeader &&
          scheme == other.scheme &&
          const ListEquality<AuthenticationParameter>().equals(
            parameters,
            other.parameters,
          );

  @override
  int get hashCode => Object.hash(
    scheme,
    const ListEquality<AuthenticationParameter>().hash(parameters),
  );

  @override
  String toString() {
    return 'AuthenticationHeader(scheme: $scheme, parameters: $parameters)';
  }
}

/// A class representing a key-value pair parameter for authentication.
class AuthenticationParameter {
  final String key;
  final String value;

  const AuthenticationParameter(this.key, this.value);

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is AuthenticationParameter &&
          key == other.key &&
          value == other.value;

  @override
  int get hashCode => Object.hash(key, value);

  @override
  String toString() => 'AuthenticationParameter(key: $key, value: $value)';
}
