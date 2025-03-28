import 'dart:collection';

import 'package:http_parser/http_parser.dart';
import 'package:relic/src/headers/typed/typed_header_interface.dart';

import 'exception/header_exception.dart';
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

  T? getValueFrom(
    HeadersBase external, {
    T? Function(Exception)? orElse,
  }) {
    try {
      var result = _cache[external] as T?;
      if (result != null) return result; // found in cache

      final raw = external[key];
      if (raw == null) return null; // nothing to decode

      result = decode(raw);
      _cache[external] = result;
      return result;
    } on Exception catch (e) {
      if (orElse == null) _throwException(e, key: key);
      return orElse(e);
    }
  }

  bool isSetIn(HeadersBase external) => external[key] != null;

  bool isValidIn(HeadersBase external) =>
      getValueFrom(external, orElse: _returnNull) != null;

  Header<T> operator [](HeadersBase external) =>
      Header((flyweight: this, headers: external));

  /// [null] implies removing the header
  void setValueOn(MutableHeaders external, T? value) =>
      _setValue(external, key, value);

  void removeFrom(MutableHeaders external) => external.remove(key);
}

Null _returnNull<T>(Exception ex) => null;

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
extension type Header<T extends Object>(HeaderTuple<T> tuple) {
  HeadersBase get _headers => tuple.headers;
  HeaderFlyweight<T> get _flyweight => tuple.flyweight;

  String get key => _flyweight.key;
  Iterable<String>? get raw => _headers[_flyweight.key];

  bool get isSet => _flyweight.isSetIn(_headers);
  bool get isValid => _flyweight.isValidIn(_headers);

  T? call() => _flyweight.getValueFrom(_headers);

  T? get valueOrNullIfInvalid =>
      _flyweight.getValueFrom(_headers, orElse: _returnNull);
  T? get valueOrNull => this();
  T get value =>
      _flyweight.getValueFrom(_headers) ??
      (throw MissingHeaderException('', headerType: key));

  void set(T? value) =>
      _flyweight.setValueOn(_headers as MutableHeaders, value);
}

/// Internal record for bundling a [HeaderFlyweight] with its externalized state [Headers].
typedef HeaderTuple<T extends Object> = ({
  HeaderFlyweight<T> flyweight,
  HeadersBase headers,
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

void _setValue<T>(MutableHeaders headers, String key, T value) {
  if (value == null) {
    headers.remove(key);
  } else {
    headers[key] = switch (value) {
      String s => [s],
      DateTime d => [formatHttpDate(d)],
      TypedHeader t => [t.toHeaderString()],
      Iterable<String> i => i,
      Object o => [o.toString()],
    };
  }
}
