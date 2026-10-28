import 'dart:typed_data';

import 'package:relic_headers/relic_headers.dart';

import '../accessor/accessor.dart';
import 'exception/header_exception.dart';

/// A typed header, the [HeaderName] and the [HeaderCodec] that reads and
/// writes it.
///
/// Always const constructed. Read one through a [Headers] like any other
/// accessor:
///
/// ```dart
/// final length = headers(Headers.contentLength);   // int?
/// final host = headers.get(Headers.host);           // throws if absent
/// ```
///
/// The headers cache decoded values by accessor and raw value, so a header
/// is parsed once per message.
final class HeaderAccessor<T extends Object>
    extends ReadOnlyAccessor<T, HeaderName, Iterable<String>> {
  final HeaderCodec<T> codec;

  const HeaderAccessor(super.key, this.codec);

  /// Decodes [raw].
  ///
  /// Wraps any exception the codec throws in an [InvalidHeaderException].
  @override
  T decode(final Iterable<String> raw) {
    try {
      return codec.decode(raw);
    } on Exception catch (e) {
      throw toInvalidHeaderException(e, key: key.lower, raw: raw);
    }
  }

  Iterable<String> encode(final T value) => codec.encode(value);

  /// Decodes [bytes], the wire bytes of the first value, or returns null
  /// for the caller to decode the text instead.
  ///
  /// Wraps any exception the codec throws in an [InvalidHeaderException].
  T? decodeBytes(final Uint8List bytes) {
    final decoder = codec.decodeBytes;
    if (decoder == null) return null;
    try {
      return decoder(bytes);
    } on Exception catch (e) {
      throw toInvalidHeaderException(
        e,
        key: key.lower,
        raw: [String.fromCharCodes(bytes)],
      );
    }
  }
}

/// Wraps [exception] as an [InvalidHeaderException] for [key], unless it
/// already is one.
InvalidHeaderException toInvalidHeaderException(
  final Object exception, {
  required final String key,
  required final Iterable<String> raw,
}) {
  if (exception is InvalidHeaderException) return exception;
  return InvalidHeaderException(
    switch (exception) {
      final FormatException f => f.message,
      final ArgumentError e => e.message.toString(),
      _ => '$exception',
    },
    headerType: key,
    raw: raw,
  );
}

/// An interface defining a bidirectional conversion between types [T] and [StorageT].
///
/// This interface is used as a foundation for [HeaderCodec] which specializes
/// in converting between header values and their string representations.
abstract interface class _Codec<T, StorageT> {
  /// Converts from the storage type [StorageT] to the target type [T]
  T decode(final StorageT encoded);

  /// Converts from the target type [T] to the storage type [StorageT]
  StorageT encode(final T value);
}

/// A specialized codec for HTTP headers that defines conversion between a typed
/// value [T] and its string representation in headers.
///
/// This interface extends the generic [_Codec] by specializing the storage type
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
    implements _Codec<T, Iterable<String>> {
  final Iterable<String> Function(T decoded) _encode;

  /// A decoder over the wire bytes of the value, with no `String` in
  /// between.
  ///
  /// It returns null for an input it does not handle, and [decode] then
  /// runs on the text. [decode] stays the reference. A codec that reads a
  /// single value gets the bytes of the first field. One that joins its
  /// fields gets them only when there is exactly one field, since the text
  /// path reads them all.
  final T? Function(Uint8List bytes)? decodeBytes;

  const HeaderCodec._(this._encode, this.decodeBytes);

  /// Whether [decode] reads only the first value.
  bool get isSingle => this is _SingleDecodeHeaderCodec<T>;

  @override
  Iterable<String> encode(final T value) => _encode(value);

  /// Factory constructor for creating a [HeaderCodec] that processes multiple values.
  ///
  /// - [decode]: Function that converts a collection of header values to type [T]
  /// - [encode]: Function to convert type [T] back to header values
  const factory HeaderCodec(
    final T Function(Iterable<String> encoded) decode,
    final Iterable<String> Function(T decoded) encode, {
    final T? Function(Uint8List bytes)? decodeBytes,
  }) = _MultiDecodeHeaderCodec<T>;

  /// Factory constructor for creating a [HeaderCodec] that processes a single value.
  ///
  /// - [singleDecode]: Function that converts a single header value to type [T]
  /// - [encode]: Function to convert type [T] back to header values
  ///
  /// This is a simplified constructor for headers that only need to process the first
  /// value in a collection of header values.
  const factory HeaderCodec.single(
    final T Function(String) singleDecode,
    final Iterable<String> Function(T) encode, {
    final T? Function(Uint8List bytes)? decodeBytes,
  }) = _SingleDecodeHeaderCodec<T>;
}

final class _MultiDecodeHeaderCodec<T extends Object> extends HeaderCodec<T> {
  final T Function(Iterable<String>) _decode;

  const _MultiDecodeHeaderCodec(
    this._decode,
    final Iterable<String> Function(T) encode, {
    final T? Function(Uint8List bytes)? decodeBytes,
  }) : super._(encode, decodeBytes);

  @override
  T decode(final Iterable<String> encoded) => _decode(encoded);
}

final class _SingleDecodeHeaderCodec<T extends Object> extends HeaderCodec<T> {
  final T Function(String) singleDecode;

  const _SingleDecodeHeaderCodec(
    this.singleDecode,
    final Iterable<String> Function(T) encode, {
    final T? Function(Uint8List bytes)? decodeBytes,
  }) : super._(encode, decodeBytes);

  @override
  T decode(final Iterable<String> encoded) => singleDecode(encoded.first);
}
