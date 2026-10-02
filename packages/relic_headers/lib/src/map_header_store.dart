import 'header_name.dart';
import 'header_store.dart';

/// The reference [MutableHeaderStore], a map from name to values.
///
/// A response is built in one, and so is any header map a package wants
/// with nothing more.
final class MapHeaderStore extends MutableHeaderStore {
  final _fields = <HeaderName, List<String>>{};

  MapHeaderStore();

  /// A store with [fields], whose keys go through [HeaderName.lookup].
  factory MapHeaderStore.from(Map<String, Iterable<String>> fields) {
    final store = MapHeaderStore();
    for (final MapEntry(:key, :value) in fields.entries) {
      store.set(HeaderName.lookup(key), value);
    }
    return store;
  }

  @override
  Iterable<HeaderName> get names => _fields.keys;

  @override
  Iterable<String> values(HeaderName name) => _fields[name] ?? const <String>[];

  @override
  bool contains(HeaderName name) => _fields.containsKey(name);

  @override
  int get fieldCount {
    var count = 0;
    for (final values in _fields.values) {
      count += values.length;
    }
    return count;
  }

  @override
  void set(HeaderName name, Iterable<String> values) {
    final copy = List<String>.unmodifiable(values);
    if (copy.isEmpty) {
      _fields.remove(name);
      return;
    }
    for (final value in copy) {
      MutableHeaderStore.checkValue(name, value);
    }
    _fields[name] = copy;
  }

  @override
  void add(HeaderName name, String value) {
    MutableHeaderStore.checkValue(name, value);
    _fields[name] = List.unmodifiable([...?_fields[name], value]);
  }

  @override
  void remove(HeaderName name) => _fields.remove(name);

  @override
  void clear() => _fields.clear();

  @override
  MutableHeaderStore toMutable() {
    final copy = MapHeaderStore();
    copy._fields.addAll(_fields);
    return copy;
  }
}
