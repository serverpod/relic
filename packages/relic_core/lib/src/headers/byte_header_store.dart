import 'dart:convert';
import 'dart:typed_data';

import 'package:relic_headers/relic_headers.dart';

/// A [HeaderStore] over the bytes of a request head.
///
/// The adapter copies the head once and indexes it: four slots per field
/// give the offset and length of the name and of the value. Nothing is
/// decoded until asked. A name is interned on first use, a value becomes a
/// `String` on first read and is then cached per field, and [rawValue] is
/// a view into the bytes.
///
/// Values are decoded as Latin-1 (RFC 9110 5.5). A byte at or above 0x80
/// becomes the code point of the same value, which is what
/// `String.fromCharCodes` does for a byte list, and it is a single copy
/// into a one-byte string.
final class ByteHeaderStore extends HeaderStore {
  /// The head. Dart-owned, so views into it outlive the exchange.
  final Uint8List bytes;

  /// Four entries per field: name offset, name length, value offset, value
  /// length, all into [bytes].
  final Int32List slots;

  final List<HeaderName?> _fieldNames;
  List<String?>? _fieldValues;
  List<Uint8List?>? _fieldRaw;
  List<HeaderName>? _names;
  Map<HeaderName, List<String>>? _values;

  ByteHeaderStore(this.bytes, this.slots)
    : _fieldNames = List.filled(slots.length ~/ 4, null) {
    assert(slots.length % 4 == 0, 'four slots per field');
  }

  /// Encodes [fields] as Latin-1 head bytes and indexes them, the way an
  /// adapter would. For tests and for stores built in Dart.
  factory ByteHeaderStore.encode(final Iterable<(String, String)> fields) {
    final buffer = BytesBuilder(copy: false);
    final slots = <int>[];
    for (final (name, value) in fields) {
      slots.add(buffer.length);
      slots.add(name.length);
      buffer.add(latin1.encode(name));
      buffer.add(const [0x3a, 0x20]); // ': '
      slots.add(buffer.length);
      slots.add(value.length);
      buffer.add(latin1.encode(value));
      buffer.add(const [0x0d, 0x0a]);
    }
    return ByteHeaderStore(buffer.toBytes(), Int32List.fromList(slots));
  }

  @override
  int get fieldCount => _fieldNames.length;

  @override
  Iterable<HeaderName> get names {
    if (_names case final names?) return names;
    final names = <HeaderName>[];
    for (var i = 0; i < fieldCount; i++) {
      final name = _nameAt(i);
      if (!names.contains(name)) names.add(name);
    }
    return _names = List.unmodifiable(names);
  }

  @override
  String? value(final HeaderName name) {
    for (var i = 0; i < fieldCount; i++) {
      if (_nameAt(i) == name) return _valueAt(i);
    }
    return null;
  }

  @override
  Iterable<String> values(final HeaderName name) {
    final cache = _values ??= {};
    final cached = cache[name];
    if (cached != null) return cached;
    final found = <String>[
      for (var i = 0; i < fieldCount; i++)
        if (_nameAt(i) == name) _valueAt(i),
    ];
    if (found.isEmpty) return const [];
    return cache[name] = List.unmodifiable(found);
  }

  @override
  bool contains(final HeaderName name) {
    for (var i = 0; i < fieldCount; i++) {
      if (_nameAt(i) == name) return true;
    }
    return false;
  }

  /// The wire bytes of the first value for [name], or null when [name] is
  /// absent, so a typed header can parse without a `String` in between.
  /// The same view comes back for the same field, so a caller may cache by
  /// identity.
  Uint8List? rawValue(final HeaderName name) {
    for (var i = 0; i < fieldCount; i++) {
      if (_nameAt(i) == name) {
        final raws = _fieldRaw ??= List.filled(fieldCount, null);
        if (raws[i] case final raw?) return raw;
        final offset = slots[i * 4 + 2];
        return raws[i] = Uint8List.sublistView(
          bytes,
          offset,
          offset + slots[i * 4 + 3],
        );
      }
    }
    return null;
  }

  HeaderName _nameAt(final int i) {
    if (_fieldNames[i] case final name?) return name;
    final offset = slots[i * 4];
    final end = offset + slots[i * 4 + 1];
    final name =
        HeaderName.lookupBytes(bytes, offset, end) ??
        HeaderName.lookup(String.fromCharCodes(bytes, offset, end));
    return _fieldNames[i] = name;
  }

  String _valueAt(final int i) {
    final values = _fieldValues ??= List.filled(fieldCount, null);
    if (values[i] case final value?) return value;
    final offset = slots[i * 4 + 2];
    return values[i] = String.fromCharCodes(
      bytes,
      offset,
      offset + slots[i * 4 + 3],
    );
  }
}
