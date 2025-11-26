/// Converts from the storage type [StorageT] to the target type [T]
typedef Decoder<T, StorageT> = T Function(StorageT encoded);

/// Converts from the target type [T] to the storage type [StorageT]
typedef Encoder<T, StorageT> = StorageT Function(T value);
