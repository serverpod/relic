import 'dart:typed_data';

import 'package:relic_headers/relic_headers.dart';

import '../accessor/accessor.dart';
import 'exception/header_exception.dart';
import 'typed/primitives/byte_scanner.dart';

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

  /// Decodes [fields], the wire bytes of every field.
  ///
  /// Only for a codec with a [HeaderCodec.decodeFields]. Wraps any
  /// exception the codec throws in an [InvalidHeaderException].
  T decodeFields(final List<Uint8List> fields) {
    try {
      return codec.decodeFields!(fields);
    } on Exception catch (e) {
      throw toInvalidHeaderException(
        e,
        key: key.lower,
        raw: [for (final f in fields) String.fromCharCodes(f)],
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
/// Four factory constructors are provided:
/// - [HeaderCodec.bytes]: a parser over the wire bytes of a single field
/// - [HeaderCodec.fields]: a parser over the wire bytes of every field
/// - [HeaderCodec.single]: a parser over the text of a single field
/// - [HeaderCodec]: a parser over the text of every field
///
/// Relic's own headers parse bytes. A text parser reads the same bytes
/// decoded as Latin-1, and a bytes parser reads text encoded as Latin-1,
/// so the two shapes see the same values.
sealed class HeaderCodec<T extends Object>
    implements _Codec<T, Iterable<String>> {
  final Iterable<String> Function(T decoded) _encode;

  const HeaderCodec._(this._encode);

  /// Whether [decode] reads only the first value.
  bool get isSingle => false;

  /// A decoder over the wire bytes of the first field, with no `String` in
  /// between, or null when this codec reads text.
  ///
  /// It may return null for an input it does not handle, and [decode] then
  /// runs on the text.
  T? Function(Uint8List bytes)? get decodeBytes => null;

  /// A decoder over the wire bytes of every field, or null when this codec
  /// reads the first field alone or reads text.
  T Function(List<Uint8List> fields)? get decodeFields => null;

  @override
  Iterable<String> encode(final T value) => _encode(value);

  /// A codec that parses the text of every field.
  ///
  /// - [decode]: Function that converts a collection of header values to type [T]
  /// - [encode]: Function to convert type [T] back to header values
  const factory HeaderCodec(
    final T Function(Iterable<String> encoded) decode,
    final Iterable<String> Function(T decoded) encode,
  ) = _MultiDecodeHeaderCodec<T>;

  /// A codec that parses the wire bytes of the first field.
  const factory HeaderCodec.bytes(
    final T Function(Uint8List bytes) decode,
    final Iterable<String> Function(T decoded) encode,
  ) = _BytesHeaderCodec<T>;

  /// A codec that parses the wire bytes of every field.
  const factory HeaderCodec.fields(
    final T Function(List<Uint8List> fields) decode,
    final Iterable<String> Function(T decoded) encode,
  ) = _FieldsHeaderCodec<T>;

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
    final Iterable<String> Function(T) encode,
  ) : super._(encode);

  @override
  T decode(final Iterable<String> encoded) => _decode(encoded);
}

final class _SingleDecodeHeaderCodec<T extends Object> extends HeaderCodec<T> {
  final T Function(String) singleDecode;

  @override
  final T? Function(Uint8List bytes)? decodeBytes;

  const _SingleDecodeHeaderCodec(
    this.singleDecode,
    final Iterable<String> Function(T) encode, {
    this.decodeBytes,
  }) : super._(encode);

  @override
  bool get isSingle => true;

  @override
  T decode(final Iterable<String> encoded) => singleDecode(encoded.first);
}

final class _BytesHeaderCodec<T extends Object> extends HeaderCodec<T> {
  final T Function(Uint8List bytes) _decode;

  const _BytesHeaderCodec(
    this._decode,
    final Iterable<String> Function(T) encode,
  ) : super._(encode);

  @override
  bool get isSingle => true;

  @override
  T Function(Uint8List bytes) get decodeBytes => _decode;

  @override
  T decode(final Iterable<String> encoded) =>
      _decode(latin1Bytes(encoded.first));
}

final class _FieldsHeaderCodec<T extends Object> extends HeaderCodec<T> {
  final T Function(List<Uint8List> fields) _decode;

  const _FieldsHeaderCodec(
    this._decode,
    final Iterable<String> Function(T) encode,
  ) : super._(encode);

  @override
  T Function(List<Uint8List> fields) get decodeFields => _decode;

  @override
  T decode(final Iterable<String> encoded) =>
      _decode([for (final value in encoded) latin1Bytes(value)]);
}
