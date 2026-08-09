part of 'headers.dart';

class MutableHeaders extends HeadersBase
    with MapMixin<String, Iterable<String>> {
  MutableHeaders._(super.backing) : super._();

  MutableHeaders() : this._(_BackingStore());

  MutableHeaders._from(final Headers headers)
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
  Iterable<String>? operator [](final Object? key) => _backing[key];

  @override
  void operator []=(final String key, final Iterable<String>? value) {
    if (value == null) {
      _backing.remove(key);
    } else {
      if (!Token.isValid(key)) {
        throw FormatException('Invalid header name', key);
      }
      for (final v in value) {
        _validateFieldValue(key, v);
      }
      _backing[key] = value;
    }
  }

  /// Rejects the characters that would end a header field or the header block
  /// itself, handing the rest of the message to whoever supplied [value].
  ///
  /// Deliberately narrower than RFC 9110 `field-value`: the rest of the
  /// grammar is checked by the typed accessors, which report a malformed
  /// header as a bad request, and only when that header is actually read. A
  /// stricter check here would turn any odd inbound header into a failure to
  /// construct the request at all.
  static void _validateFieldValue(final String name, final String value) {
    for (var i = 0; i < value.length; i++) {
      final c = value.codeUnitAt(i);
      if (c == 0x0D || c == 0x0A || c == 0x00) {
        throw FormatException(
          'Header "$name" value must not contain CR, LF or NUL',
          value,
          i,
        );
      }
    }
  }

  @override
  void clear() => _backing.clear();

  @override
  Iterable<String> get keys => _backing.keys;

  @override
  Iterable<String>? remove(final Object? key) => _backing.remove(key);
}
