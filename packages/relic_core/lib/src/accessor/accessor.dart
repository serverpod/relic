import 'package:meta/meta.dart';

import '../headers/codec.dart';

/// A read-only accessor for extracting typed values from a keyed storage.
///
/// This is a flyweight pattern where the accessor defines how to decode
/// a value, and an [AccessorStateMixin] holds the actual data.
///
/// Type parameters:
/// - [T]: The decoded type
/// - [K]: The key type used to identify values in storage
/// - [R]: The raw storage type
abstract class ReadOnlyAccessor<T extends Object, K, R> {
  /// The key used to identify this value in storage.
  final K key;

  const ReadOnlyAccessor(this.key);

  /// Decodes [raw] into the typed value.
  ///
  /// Throws for a value that does not decode.
  T decode(R raw);
}

/// A [ReadOnlyAccessor] that decodes with a function.
///
/// The base for the path, query and form accessors, whose decoder is a
/// plain function such as `int.parse`.
abstract class FunctionAccessor<T extends Object, K, R>
    extends ReadOnlyAccessor<T, K, R> {
  final Decoder<T, R> _decode;

  const FunctionAccessor(super.key, this._decode);

  @override
  T decode(R raw) => _decode(raw);
}

/// Typed reads over a keyed storage, with a cache of decoded values.
///
/// Path, query and form parameters and headers all mix this in, so they
/// read the same way. [call] gives the value or null, [get] throws when it
/// is absent, and [tryGet] gives null for a value that does not decode.
mixin AccessorStateMixin<K, R> {
  /// Decoded values by accessor, each with the raw it was decoded from.
  ///
  /// The raw is the raw value, or whatever else the value was decoded
  /// from, such as a byte view. Accessors compare by identity, so the
  /// lookup hashes no header text. A read with another raw for the same
  /// accessor decodes again and replaces the entry.
  Map<ReadOnlyAccessor<dynamic, K, R>, _Decoded>? _cache;

  /// The raw value for [key], or null when absent.
  R? lookup(K key);

  /// Returns the raw value for the given [accessor], or `null` if not present.
  R? operator [](ReadOnlyAccessor<dynamic, K, R> accessor) =>
      lookup(accessor.key);

  /// Returns the decoded value for the given [accessor].
  ///
  /// Throws if the value is missing or if decoding fails.
  T get<T extends Object>(ReadOnlyAccessor<T, K, R> accessor) =>
      call(accessor) ??
      (throw StateError('Missing value for key: ${accessor.key}'));

  /// Returns the decoded value for the given [accessor], or `null` if missing.
  ///
  /// Throws if decoding fails.
  T? call<T extends Object>(ReadOnlyAccessor<T, K, R> accessor) {
    final rawValue = lookup(accessor.key);
    if (rawValue == null) return null;
    return decodeCached(accessor, rawValue, () => accessor.decode(rawValue));
  }

  /// The value [decode] produces for [accessor] from [raw], decoded once
  /// per (accessor, raw) pair.
  @protected
  T decodeCached<T extends Object>(
    ReadOnlyAccessor<T, K, R> accessor,
    Object raw,
    T Function() decode,
  ) {
    final cache = _cache ??= Map.identity();
    final entry = cache[accessor];
    if (entry != null && (identical(entry.raw, raw) || entry.raw == raw)) {
      return entry.value as T;
    }
    final value = decode();
    cache[accessor] = _Decoded(raw, value);
    return value;
  }

  /// Returns the decoded value for the given [accessor], or `null` if missing
  /// or if decoding fails.
  T? tryGet<T extends Object>(ReadOnlyAccessor<T, K, R> accessor) {
    try {
      return call(accessor);
    } catch (_) {
      return null;
    }
  }

  /// Copies every decoded value [other] holds into this cache.
  ///
  /// A value assigned on a mutable then stays the same object on the
  /// headers built from it, with no second decode.
  @protected
  void adoptCache(AccessorStateMixin<K, R> other) {
    final adopted = other._cache;
    if (adopted == null || adopted.isEmpty) return;
    (_cache ??= Map.identity()).addAll(adopted);
  }

  /// Records [value] as the decoded form of [raw] for [accessor].
  ///
  /// [raw] is whatever [call] will decode from for this accessor, so a
  /// value just encoded is not decoded again on read.
  @protected
  void prime<T extends Object>(
    ReadOnlyAccessor<T, K, R> accessor,
    Object raw,
    T value,
  ) {
    (_cache ??= Map.identity())[accessor] = _Decoded(raw, value);
  }
}

/// Holds the externalized state for [ReadOnlyAccessor] instances in a map.
class AccessorState<K, R> with AccessorStateMixin<K, R> {
  /// The raw key-value storage.
  final Map<K, R> raw;

  /// Creates a new accessor state with the given raw values.
  AccessorState(this.raw);

  @override
  R? lookup(K key) => raw[key];
}

extension RawEx<K, R> on Map<K, R> {
  /// A non-nullable lookup of [key]
  ///
  /// Throws a [StateError] if the value is missing.
  R get(K key) =>
      this[key] ?? (throw StateError('Missing value for key: $key'));
}

/// A decoded value and the raw it came from.
final class _Decoded {
  final Object raw;
  final Object value;

  const _Decoded(this.raw, this.value);
}
