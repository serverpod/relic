import 'dart:collection';

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
  Expando<T> get _cache =>
      _caches.putIfAbsent(this, Expando<T>.new) as Expando<T>;

  /// The [key] is the name of the HTTP header.
  final String key;

  /// The [decode] function converts the raw header value into a typed value of type [T].
  final HeaderCodec<T> codec;

  /// Creates a new header accessor.
  ///
  /// - [key]: The name of the HTTP header
  /// - [decode]: Function that parses the raw header value into type [T]
  ///
  /// Each accessor instance maintains its own cache to avoid repeated parsing
  /// of the same raw header value.
  const HeaderAccessor(this.key, this.codec);

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
    final HeadersBase external, {
    final T? Function(Exception)? orElse,
  }) {
    try {
      final raw = external[key];
      if (raw == null) return null; // nothing to decode

      var result = _cache[raw];
      if (result != null) return result; // found in cache

      result = codec.decode(raw);
      _cache[raw] = result;
      return result;
    } on Exception catch (e) {
      if (orElse == null) _throwException(e, key: key);
      return orElse(e);
    }
  }

  /// Checks if the header is set in the given [external] headers.
  bool isSetIn(final HeadersBase external) => external[key] != null;

  /// Checks if the header is valid in the given [external] headers.
  bool isValidIn(final HeadersBase external) =>
      getValueFrom(external, orElse: _returnNull) != null;

  /// Creates a new [Header] instance for the given [external] headers.
  Header<T> operator [](final HeadersBase external) =>
      Header((accessor: this, headers: external));

  /// If [value] is [null] it implies removing the header
  void setValueOn(final MutableHeaders external, final T? value) {
    if (value != null) {
      final raw = codec.encode(value);
      external[key] = raw;
      // prime cache immediately (not needed, but avoids a decode)
      _cache[raw] = value;
    } else {
      external.remove(key);
      // no need to touch _cache. Lifetime of cached value handled by Expando
    }
  }

  /// Removes the header from the given [external] headers.
  void removeFrom(final MutableHeaders external) => external.remove(key);
}

Null _returnNull(final Exception ex) => null;

/// An interface defining a bidirectional conversion between types [T] and [StorageT].
///
/// The [Codec] class provides two methods:
/// - [decode]: Converts from the storage type [StorageT] to the target type [T]
/// - [encode]: Converts from the target type [T] to the storage type [StorageT]
///
/// This interface is used as a foundation for the [HeaderCodec] which specializes
/// in converting between header values and their string representations.
abstract interface class Codec<T, StorageT> {
  T decode(final StorageT encoded);
  StorageT encode(final T decoded);
}

/// A specialized codec for HTTP headers that defines conversion between a typed
/// value [T] and its string representation in headers.
///
/// This interface extends the generic [Codec] by specializing the storage type
/// to [Iterable<String>], which represents how multiple header values can be
/// stored for a single header name.
///
/// The interface provides two methods:
/// - [decode]: Converts from header string values to the typed value [T]
/// - [encode]: Converts from the typed value [T] to header string values
///
/// Two factory constructors are provided:
/// - [HeaderCodec]: For handling headers that need to process multiple values
/// - [HeaderCodec.single]: For simpler headers that only need to process a single value
sealed class HeaderCodec<T extends Object>
    implements Codec<T, Iterable<String>> {
  final Iterable<String> Function(T decoded) _encode;

  const HeaderCodec._(this._encode);

  @override
  Iterable<String> encode(final T value) => _encode(value);

  /// Factory constructor for creating a [HeaderCodec] that processes multiple values.
  ///
  /// - [decode]: Function that converts a collection of header values to type [T]
  /// - [encode]: Optional function to convert type [T] back to header values
  const factory HeaderCodec(
    final T Function(Iterable<String> encoded) decode,
    final Iterable<String> Function(T decoded) encode,
  ) = _MultiDecodeHeaderCodec<T>;

  /// Factory constructor for creating a [HeaderCodec] that processes a single value.
  ///
  /// - [singleDecode]: Function that converts a single header value to type [T]
  /// - [encode]: Optional function to convert type [T] back to header values
  ///
  /// This is a simplified constructor for headers that only need to process the first
  /// value in a collection of header values.
  const factory HeaderCodec.single(
    final T Function(String) singleDecode,
    final Iterable<String> Function(T) encode,
  ) = _SingleDecodeHeaderCodec<T>;
}

final class _MultiDecodeHeaderCodec<T extends Object> extends HeaderCodec<T> {
  final T Function(Iterable<String>) _decode;

  const _MultiDecodeHeaderCodec(
    this._decode,
    final Iterable<String> Function(T) encode,
  ) : super._(encode);

  @override
  T decode(final Iterable<String> encoded) => _decode(encoded);
}

final class _SingleDecodeHeaderCodec<T extends Object> extends HeaderCodec<T> {
  final T Function(String) singleDecode;

  const _SingleDecodeHeaderCodec(
    this.singleDecode,
    final Iterable<String> Function(T) encode,
  ) : super._(encode);

  @override
  T decode(final Iterable<String> encoded) => singleDecode(encoded.first);
}

/// A "class" representing a typed header.
///
/// Instances are intended to be short-lived. They are typically used as
/// temporary objects during header processing.
///
/// This is implemented as an extension type over a record type
/// to keep runtime cost low.
extension type const Header<T extends Object>(HeaderTuple<T> tuple) {
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

  void set(final T? value) =>
      _accessor.setValueOn(_headers as MutableHeaders, value);
}

/// Internal record for bundling an [accessor] with its externalized state [headers].
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
  final Object exception, {
  required final String key,
}) {
  if (exception is InvalidHeaderException) throw exception;
  throw InvalidHeaderException(
    switch (exception) {
      final FormatException f => f.message,
      final ArgumentError e => e.message.toString(),
      _ => '$exception',
    },
    headerType: key,
  );
}
