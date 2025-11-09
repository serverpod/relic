import '../headers/codec.dart';

/// A read-only accessor for extracting typed values from a keyed storage.
///
/// This is a flyweight pattern where the accessor defines how to decode
/// a value, and the [AccessorState] holds the actual data.
///
/// Type parameters:
/// - [T]: The decoded type
/// - [K]: The key type used to identify values in storage
/// - [R]: The raw storage type
abstract class ReadOnlyAccessor<T extends Object, K, R> {
  /// The key used to identify this value in storage.
  final K key;

  /// Decodes the raw value into the typed value.
  final Decoder<T, R> decode;

  const ReadOnlyAccessor(this.key, this.decode);
}


/// Holds the externalized state for [ReadOnlyAccessor] instances.
///
/// This class stores the raw values and caches decoded results to avoid
/// repeated parsing of the same values.
class AccessorState<K, R> {
  /// The raw key-value storage.
  final Map<K, R> raw;

  /// Cache for decoded values, keyed by (accessor, rawValue) pair.
  /// Accessor instances remain distinct via their default identity-based `==`.
  final _cache = <(ReadOnlyAccessor<dynamic, K, R>, R), Object?>{};

  /// Creates a new accessor state with the given raw values.
  AccessorState(this.raw);

  /// Returns the raw value for the given [accessor], or `null` if not present.
  R? operator [](final ReadOnlyAccessor<dynamic, K, R> accessor) =>
      raw[accessor.key];

  /// Returns the decoded value for the given [accessor].
  ///
  /// Throws if the value is missing or if decoding fails.
  T call<T extends Object>(final ReadOnlyAccessor<T, K, R> accessor) =>
      get(accessor) ??
      (throw StateError('Missing value for key: ${accessor.key}'));

  /// Returns the decoded value for the given [accessor], or `null` if missing.
  ///
  /// Throws if decoding fails.
  T? get<T extends Object>(final ReadOnlyAccessor<T, K, R> accessor) {
    final rawValue = raw[accessor.key];
    if (rawValue == null) return null;
    return (_cache[(accessor, rawValue)] ??= accessor.decode(rawValue)) as T;
  }

  /// Returns the decoded value for the given [accessor], or `null` if missing
  /// or if decoding fails.
  T? tryGet<T extends Object>(final ReadOnlyAccessor<T, K, R> accessor) {
    try {
      return get(accessor);
    } catch (_) {
      return null;
    }
  }
}

