part of 'headers.dart';

/// The builder side of [Headers], a [MutableHeaderStore] with typed reads
/// and writes.
///
/// Write a typed header with its setter or with [assign], and any header
/// by name with `[]=`. Every write rejects a value with CR, LF or NUL, so
/// nothing reaches the wire that would end the field.
final class MutableHeaders extends MutableHeaderStore
    with AccessorStateMixin<HeaderName, Iterable<String>>, _StoreReads {
  @override
  final MutableHeaderStore _store;

  MutableHeaders._(this._store);

  MutableHeaders() : this._(MapHeaderStore());

  /// Sets [accessor] to [value], or removes it when [value] is null.
  void assign<T extends Object>(HeaderAccessor<T> accessor, T? value) {
    if (value == null) {
      remove(accessor.key);
      return;
    }
    set(accessor.key, accessor.encode(value));
    // A value that encodes to no field, such as an empty list, removed the
    // header. Otherwise key the cache the way call() reads, by the first
    // value for a single value codec and by the value list otherwise.
    final stored = lookup(accessor.key);
    if (stored == null) return;
    prime(accessor, accessor.codec.isSingle ? stored.first : stored, value);
  }

  /// Sets the header called [key], a [HeaderName] or a name as text, or
  /// removes it when [values] is null.
  ///
  /// Throws [FormatException] for a name that is not an HTTP token or a
  /// value with CR, LF or NUL.
  void operator []=(Object key, Iterable<String>? values) {
    final name = switch (key) {
      final HeaderName name => name,
      final String text => HeaderName.lookup(text),
      _ => throw ArgumentError.value(key, 'key', 'Not a header name'),
    };
    if (values == null) {
      remove(name);
    } else {
      set(name, values);
    }
  }

  @override
  void set(HeaderName name, Iterable<String> values) =>
      _store.set(name, values);

  @override
  void add(HeaderName name, String value) => _store.add(name, value);

  /// Removes the header called [key], which may be a [HeaderName], a name
  /// as text, or an accessor.
  @override
  void remove(Object key) => _store.remove(switch (key) {
    final HeaderName name => name,
    final ReadOnlyAccessor<dynamic, HeaderName, Iterable<String>> a => a.key,
    final String text => HeaderName.lookup(text),
    _ => throw ArgumentError.value(key, 'key', 'Not a header name'),
  });

  @override
  void clear() => _store.clear();

  @override
  String toString() => 'MutableHeaders(${toMap()})';
}
