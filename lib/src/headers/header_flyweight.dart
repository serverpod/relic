import 'dart:collection';

import 'exception/invalid_header_exception.dart';
import 'headers.dart';

/// Flyweight class for headers. It should always be const constructed.
///
/// The externalized state is stored in the Headers external, and to avoid repeated
/// parsing of the raw value the value is cached with an [Expando].
final class HeaderFlyweight<T extends Object> {
  static final _caches = LinkedHashMap<HeaderFlyweight, Expando>.identity();
  Expando get _cache => _caches.putIfAbsent(this, Expando.new);

  final String key;
  final HeaderDecoder<T> decode;

  const HeaderFlyweight(this.key, this.decode);

  Iterable<String>? rawFrom(Headers external) => external[key];

  V getValueFrom<V extends T?>(
    Headers external, {
    V Function(Exception) orElse = _raise,
  }) {
    try {
      try {
        var result = _cache[external];
        if (result != null) return result as V;
        final raw = rawFrom(external);
        result = _cache[external] ??= // update cache
            raw == null ? null : decode(raw);
        return result as V;
      } on Exception catch (e) {
        return orElse(e);
      }
    } catch (o) {
      _throwException(o, key: key);
    }
  }

  bool isSetIn(Headers external) => rawFrom(external) != null;

  bool isValidIn(Headers external) =>
      getValueFrom<T?>(external, orElse: _returnNull) != null;

  Header<T> operator [](Headers external) =>
      Header((flyweight: this, headers: external));
}

Never _raise(Exception ex) => throw ex;
Null _returnNull(Exception ex) => null;

sealed class HeaderDecoder<T extends Object> {
  const HeaderDecoder();
  T call(Iterable<String> value);
}

final class HeaderDecoderSingle<T extends Object> extends HeaderDecoder<T> {
  final T Function(String) parse;
  const HeaderDecoderSingle(this.parse);

  @override
  T call(Iterable<String> value) => parse(value.first);
}

final class HeaderDecoderMulti<T extends Object> extends HeaderDecoder<T> {
  final T Function(Iterable<String>) parse;
  const HeaderDecoderMulti(this.parse);

  @override
  T call(Iterable<String> value) => parse(value);
}

/// A "class" representing a typed header.
///
/// Instances are intended to be short-lived. They are typically used as
/// temporary objects during header processing.
///
/// This is implemented as an extension type over a record type
/// to keep runtime cost low.
// ignore: library_private_types_in_public_api
extension type Header<T extends Object>(_HeaderTuple<T> tuple) {
  Headers get _headers => tuple.headers;
  HeaderFlyweight<T> get _flyweight => tuple.flyweight;

  String get key => _flyweight.key;
  Iterable<String>? get raw => _flyweight.rawFrom(_headers);

  bool get isSet => _flyweight.isSetIn(_headers);
  bool get isValid => _flyweight.isValidIn(_headers);

  T? get valueOrNullIfInvalid => this(orElse: _returnNull);
  T? get valueOrNull => this();
  T get value => this(); // magic of type inference

  V call<V extends T?>({V Function(Exception) orElse = _raise}) =>
      _flyweight.getValueFrom<V>(_headers, orElse: orElse);
}

/// Internal record for bundling a [HeaderFlyweight] with its externalized state [Headers].
typedef _HeaderTuple<T extends Object> = ({
  HeaderFlyweight<T> flyweight,
  Headers headers,
});

/// Throws an [InvalidHeaderException] with the appropriate message based on
/// the type of the given [exception].
///
/// This function extracts the message from the given [exception] and throws
/// an [InvalidHeaderException] with the extracted message and the specified
/// [key] as the header type.
///
/// - [exception]: The exception object from which to extract the message.
/// - [key]: The header type associated with the exception.
///
/// Throws:
/// - [InvalidHeaderException]: Always thrown with the extracted message and
/// the specified header type.
Never _throwException(
  Object exception, {
  required String key,
}) {
  var message = "$exception";
  if (exception is InvalidHeaderException) {
    message = exception.description;
  } else if (exception is FormatException) {
    message = exception.message;
  } else if (exception is ArgumentError) {
    message = exception.message;
  }

  throw InvalidHeaderException(
    message,
    headerType: key,
  );
}
