part of 'headers.dart';

class MutableHeaders extends HeadersBase
    with MapMixin<String, Iterable<String>> {
  MutableHeaders._(super.backing) : super._();

  MutableHeaders._from(Headers headers)
      : this._(_BackingStore.from(headers._backing));

  Headers _freeze() {
    // TODO:
    // Would be nice if we could decouple _backing from this MutableHeaders object
    // at this point to prevent caller to hold on to the mutable headers after freezing
    //
    // Will require a change to MapView or
    return Headers._(_backing);
  }

  @override
  Iterable<String>? operator [](Object? key) => _backing[key];

  @override
  void operator []=(String key, Iterable<String>? value) {
    if (value == null) {
      _backing.remove(key);
    } else {
      _backing[key] = value;
    }
  }

  @override
  void clear() => _backing.clear();

  @override
  Iterable<String> get keys => _backing.keys;

  @override
  Iterable<String>? remove(Object? key) => _backing.remove(key);
}
