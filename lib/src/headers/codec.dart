typedef Decoder<T, StorageT> = T Function(StorageT encoded);
typedef Encoder<T, StorageT> = StorageT Function(T value);

/// An interface defining a bidirectional conversion between types [T] and [StorageT].
///
/// This interface is used as a foundation for [HeaderCodec] which specializes
/// in converting between header values and their string representations.
abstract interface class Codec<T, StorageT> {
  /// Converts from the storage type [StorageT] to the target type [T]
  T decode(final StorageT encoded);

  /// Converts from the target type [T] to the storage type [StorageT]
  StorageT encode(final T value);
}
