import 'dart:collection';

import 'package:http_parser/http_parser.dart';
import 'package:relic/src/headers/typed/typed_header_interface.dart';

import 'exception/header_exception.dart';
import 'headers.dart';

/// Flyweight accessor class for headers. It should always be const constructed.
///
/// The externalized state is stored in the Headers external, and to avoid repeated
/// parsing of the raw value the value is cached with an [Expando].
final class HeaderAccessor<T extends Object> {
  /// Static map that stores the cache [Expando] for each [HeaderAccessor] instance.
  /// Using an identity map ensures each accessor gets its own unique cache.
  ///
  /// As this is static container and we only ever add to it, each added Expando will
  /// live until proess terminates. However there should only be a finite number of
  /// const constructed [HeaderAccessor] objects, so this is fine.
  ///
  /// Note that the cached values stored in the [Expando]s follows the lifetime of the
  /// [Headers] objects that are expanded.
  static final _caches = LinkedHashMap<HeaderAccessor, Expando>.identity();

  /// Returns the [Expando] cache for this accessor instance.
  ///
  /// Each accessor has its own unique cache to store parsed header values,
  /// avoiding repeated parsing of the same raw header value.
  ///
  /// This is used internally by [getValueFrom] to implement the caching mechanism.
  Expando get _cache => _caches.putIfAbsent(this, Expando.new);

  /// The [key] is the name of the HTTP header.
  final String key;

  /// The [decode] function converts the raw header value into a typed value of type [T].
  final HeaderDecoder<T> decode;

  /// Creates a new header accessor.
  ///
  /// - [key]: The name of the HTTP header
  /// - [decode]: Function that parses the raw header value into type [T]
  ///
  /// Each accessor instance maintains its own cache to avoid repeated parsing
  /// of the same raw header value.
  const HeaderAccessor(this.key, this.decode);

  /// Retrieves the typed value of this header from the given [external] headers.
  ///
  /// This method gets the raw header value from [external], decodes it into type [T],
  /// and caches the result to avoid re-parsing the same value in future calls.
  ///
  /// Parameters:
  /// - [external]: The headers container from which to retrieve the header value
  /// - [orElse]: Optional function to handle exceptions during header parsing
  ///
  /// Returns:
  /// - The parsed header value of type [T]
  /// - `null` if the header is not present
  /// - The result of [orElse] if parsing fails and [orElse] is provided
  ///
  /// Throws:
  /// - [InvalidHeaderException] if parsing fails and no [orElse] is provided
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

  /// Checks if the header is set in the given [external] headers.
  bool isSetIn(HeadersBase external) => external[key] != null;

  /// Checks if the header is valid in the given [external] headers.
  bool isValidIn(HeadersBase external) =>
      getValueFrom(external, orElse: _returnNull) != null;

  /// Creates a new [Header] instance for the given [external] headers.
  Header<T> operator [](HeadersBase external) =>
      Header((accessor: this, headers: external));

  /// [null] implies removing the header
  void setValueOn(MutableHeaders external, T? value) =>
      _setValue(external, key, value);

  /// Removes the header from the given [external] headers.
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
  HeaderAccessor<T> get _accessor => tuple.accessor;

  String get key => _accessor.key;
  Iterable<String>? get raw => _headers[_accessor.key];

  bool get isSet => _accessor.isSetIn(_headers);
  bool get isValid => _accessor.isValidIn(_headers);

  T? call() => _accessor.getValueFrom(_headers);

  T? get valueOrNullIfInvalid =>
      _accessor.getValueFrom(_headers, orElse: _returnNull);
  T? get valueOrNull => this();
  T get value =>
      _accessor.getValueFrom(_headers) ??
      (throw MissingHeaderException('', headerType: key));

  void set(T? value) => _accessor.setValueOn(_headers as MutableHeaders, value);
}

/// Internal record for bundling a [HeaderAccessor] with its externalized state [Headers].
typedef HeaderTuple<T extends Object> = ({
  HeaderAccessor<T> accessor,
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
  if (exception is InvalidHeaderException) throw exception;
  throw InvalidHeaderException(
    switch (exception) {
      FormatException f => f.message,
      ArgumentError e => e.message,
      _ => '$exception',
    },
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
