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
      throw _toInvalidHeaderException(e, key: key.lower, raw: raw);
    }
  }

  Iterable<String> encode(final T value) => codec.encode(value);

  /// [decoder] over [bytes], the wire bytes of the first field.
  ///
  /// Wraps any exception the codec throws in an [InvalidHeaderException].
  T decodeBytes(final T Function(Uint8List) decoder, final Uint8List bytes) {
    try {
      return decoder(bytes);
    } on Exception catch (e) {
      throw _toInvalidHeaderException(
        e,
        key: key.lower,
        raw: [String.fromCharCodes(bytes)],
      );
    }
  }

  /// [decoder] over [fields], the wire bytes of every field.
  ///
  /// Wraps any exception the codec throws in an [InvalidHeaderException].
  T decodeFields(
    final T Function(List<Uint8List>) decoder,
    final List<Uint8List> fields,
  ) {
    try {
      return decoder(fields);
    } on Exception catch (e) {
      throw _toInvalidHeaderException(
        e,
        key: key.lower,
        raw: [for (final f in fields) String.fromCharCodes(f)],
      );
    }
  }
}

/// Wraps [exception] as an [InvalidHeaderException] for [key], unless it
/// already is one.
InvalidHeaderException _toInvalidHeaderException(
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
/// The four constructors are the cells of a grid, text or bytes by the
/// first field or every field:
///
/// |       | first field                 | every field                  |
/// |-------|-----------------------------|------------------------------|
/// | text  | [HeaderCodec.single]        | [HeaderCodec.new]            |
/// | bytes | [HeaderCodec.bytes]         | [HeaderCodec.fields]         |
///
/// Relic's own headers parse bytes. A text parser reads the same bytes
/// decoded as Latin-1, and a bytes parser reads text encoded as Latin-1,
/// so the two shapes see the same values.
sealed class HeaderCodec<T extends Object>
    implements _Codec<T, Iterable<String>> {
  final Iterable<String> Function(T decoded) _encode;

  const HeaderCodec._(this._encode);

  @override
  Iterable<String> encode(final T value) => _encode(value);

  /// A codec that parses the text of every field.
  ///
  /// - [decode]: Function that converts a collection of header values to type [T]
  /// - [encode]: Function to convert type [T] back to header values
  const factory HeaderCodec(
    final T Function(Iterable<String> encoded) decode,
    final Iterable<String> Function(T decoded) encode,
  ) = MultiHeaderCodec<T>;

  /// A codec that parses the wire bytes of the first field.
  const factory HeaderCodec.bytes(
    final T Function(Uint8List bytes) decode,
    final Iterable<String> Function(T decoded) encode,
  ) = BytesHeaderCodec<T>;

  /// A codec that parses the wire bytes of every field.
  const factory HeaderCodec.fields(
    final T Function(List<Uint8List> fields) decode,
    final Iterable<String> Function(T decoded) encode,
  ) = FieldsHeaderCodec<T>;

  /// A codec that parses the text of the first field.
  ///
  /// - [singleDecode]: Function that converts a single header value to type [T]
  /// - [encode]: Function to convert type [T] back to header values
  const factory HeaderCodec.single(
    final T Function(String) singleDecode,
    final Iterable<String> Function(T) encode,
  ) = SingleHeaderCodec<T>;
}

/// The store reads a codec by its kind, not exported from relic_core.dart.
extension HeaderCodecInternal<T extends Object> on HeaderCodec<T> {
  /// Whether [HeaderCodec.decode] reads only the first value.
  bool get isSingle => switch (this) {
    SingleHeaderCodec<T>() || BytesHeaderCodec<T>() => true,
    MultiHeaderCodec<T>() || FieldsHeaderCodec<T>() => false,
  };
}

/// [HeaderCodec.new]: the text of every field.
final class MultiHeaderCodec<T extends Object> extends HeaderCodec<T> {
  final T Function(Iterable<String>) _decode;

  const MultiHeaderCodec(
    this._decode,
    final Iterable<String> Function(T) encode,
  ) : super._(encode);

  @override
  T decode(final Iterable<String> encoded) => _decode(encoded);
}

/// [HeaderCodec.single]: the text of the first field.
final class SingleHeaderCodec<T extends Object> extends HeaderCodec<T> {
  final T Function(String) _decode;

  const SingleHeaderCodec(
    this._decode,
    final Iterable<String> Function(T) encode,
  ) : super._(encode);

  @override
  T decode(final Iterable<String> encoded) => _decode(encoded.first);
}

/// [HeaderCodec.bytes]: the wire bytes of the first field.
final class BytesHeaderCodec<T extends Object> extends HeaderCodec<T> {
  /// The decoder over the wire bytes of the first field.
  final T Function(Uint8List bytes) decodeBytes;

  const BytesHeaderCodec(
    this.decodeBytes,
    final Iterable<String> Function(T) encode,
  ) : super._(encode);

  @override
  T decode(final Iterable<String> encoded) =>
      decodeBytes(latin1Bytes(encoded.first));
}

/// [HeaderCodec.fields]: the wire bytes of every field.
final class FieldsHeaderCodec<T extends Object> extends HeaderCodec<T> {
  /// The decoder over the wire bytes of every field.
  final T Function(List<Uint8List> fields) decodeFields;

  const FieldsHeaderCodec(
    this.decodeFields,
    final Iterable<String> Function(T) encode,
  ) : super._(encode);

  @override
  T decode(final Iterable<String> encoded) =>
      decodeFields([for (final value in encoded) latin1Bytes(value)]);
}
