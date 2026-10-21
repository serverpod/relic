import 'dart:typed_data';

import 'header_name.dart';
import 'map_header_store.dart';

/// Read access to the header fields of a message.
///
/// A base class, not an interface. An implementer extends it and provides
/// [names] and [values]. Everything else has a default, so a member added
/// here later breaks no store in another package. Override a default when
/// the store can do better, say [value] on a store that caches its first
/// value.
///
/// Names are matched case-insensitively through [HeaderName]. Values are
/// text.
abstract base class HeaderStore {
  const HeaderStore();

  /// Every distinct name, in the order it first appears.
  Iterable<HeaderName> get names;

  /// Every value for [name], in order, or empty when [name] is absent.
  ///
  /// The same object comes back for the same name while the store is not
  /// modified, so a caller may cache by identity.
  Iterable<String> values(HeaderName name);

  /// The number of name and value pairs.
  int get fieldCount {
    var count = 0;
    for (final name in names) {
      count += values(name).length;
    }
    return count;
  }

  /// The first value for [name], or null.
  String? value(HeaderName name) {
    final all = values(name);
    return all.isEmpty ? null : all.first;
  }

  bool contains(HeaderName name) => values(name).isNotEmpty;

  bool get isEmpty => names.isEmpty;

  bool get isNotEmpty => names.isNotEmpty;

  /// Visits every name and value pair, in order.
  ///
  /// The slow path, since it materializes every value.
  void forEach(void Function(HeaderName name, String value) visit) {
    for (final name in names) {
      for (final value in values(name)) {
        visit(name, value);
      }
    }
  }

  /// A [MapHeaderStore] with this store's fields.
  MutableHeaderStore toMutable() {
    final copy = MapHeaderStore();
    for (final name in names) {
      copy.set(name, values(name));
    }
    return copy;
  }
}

/// A [HeaderStore] that kept the wire bytes of its fields, so a typed
/// header can decode from them without a `String` in between.
abstract interface class ByteHeaderSource {
  /// The wire bytes of the first value for [name], or null when [name] is
  /// absent.
  ///
  /// The same view comes back for the same field, so a caller may cache by
  /// identity.
  Uint8List? rawValue(HeaderName name);
}

/// A [HeaderStore] that can be written.
///
/// Every writer rejects a value with CR, LF or NUL, the characters that
/// would end a header field or the header block and hand the rest of the
/// message to whoever supplied the value. Typed headers check the rest of
/// the field-value grammar when the header is read.
abstract base class MutableHeaderStore extends HeaderStore {
  const MutableHeaderStore();

  /// Replaces every value for [name] with [values], or removes the field
  /// when [values] is empty.
  void set(HeaderName name, Iterable<String> values);

  /// Appends [value] to the values for [name].
  void add(HeaderName name, String value);

  void remove(HeaderName name);

  void clear();

  /// Throws [FormatException] when [value] carries CR, LF or NUL.
  static void checkValue(HeaderName name, String value) {
    for (var i = 0; i < value.length; i++) {
      final c = value.codeUnitAt(i);
      if (c == 0x0D || c == 0x0A || c == 0x00) {
        throw FormatException(
          'Header "${name.lower}" value must not contain CR, LF or NUL',
          value,
          i,
        );
      }
    }
  }
}
