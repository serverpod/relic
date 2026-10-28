import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:relic_headers/relic_headers.dart';

/// A [HeaderStore] over the bytes of a request head.
///
/// The adapter copies the head once and indexes it in [slots]. Nothing is
/// decoded until asked. A known name is an index into [HeaderName.known],
/// an unknown name is interned on first use, a value becomes a `String` on
/// first read and is cached per field, and [rawValue] is a view into the
/// bytes.
///
/// Values decode as Latin-1 (RFC 9110 5.5). A byte at or above 0x80
/// becomes the code point of the same value, which is what
/// `String.fromCharCodes` does for a byte list, in one copy into a one-byte
/// string.
final class ByteHeaderStore extends HeaderStore implements ByteHeaderSource {
  /// The head. Dart-owned, so views into it outlive the exchange.
  final Uint8List bytes;

  /// Four entries per field: name offset, name id or -1, value offset,
  /// value length. Offsets are into [bytes], and the name of a field with
  /// id -1 runs from its offset to the colon.
  final Int32List slots;

  List<HeaderName?>? _fieldNames;
  List<String?>? _fieldValues;
  List<Uint8List?>? _fieldRaw;
  List<HeaderName>? _names;
  Map<HeaderName, UnmodifiableListView<String>>? _values;
  Map<HeaderName, List<Uint8List>>? _rawValues;

  ByteHeaderStore(this.bytes, this.slots)
    : assert(slots.length % 4 == 0, 'four slots per field');

  /// Encodes [fields] as Latin-1 head bytes and indexes them, the way an
  /// adapter would.
  ///
  /// For tests and for stores built in Dart.
  factory ByteHeaderStore.encode(final Iterable<(String, String)> fields) {
    final buffer = BytesBuilder(copy: false);
    final slots = <int>[];
    for (final (name, value) in fields) {
      slots.add(buffer.length);
      slots.add(_idOf(name));
      buffer.add(latin1.encode(name));
      buffer.add(const [0x3a, 0x20]); // ': '
      slots.add(buffer.length);
      slots.add(value.length);
      buffer.add(latin1.encode(value));
      buffer.add(const [0x0d, 0x0a]);
    }
    return ByteHeaderStore(buffer.toBytes(), Int32List.fromList(slots));
  }

  /// The id of [name], or -1 for an unknown name.
  ///
  /// A name that is not a token also gets -1, and [_nameAt] rejects it on
  /// first read.
  static int _idOf(final String name) {
    try {
      return HeaderName.lookup(name).id;
    } on FormatException {
      return -1;
    }
  }

  @override
  int get fieldCount => slots.length ~/ 4;

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
      if (_matches(i, name)) return _valueAt(i);
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
        if (_matches(i, name)) _valueAt(i),
    ];
    if (found.isEmpty) return const [];
    // A view, not a copy: the list is this store's own and never changes.
    return cache[name] = UnmodifiableListView(found);
  }

  @override
  bool contains(final HeaderName name) {
    for (var i = 0; i < fieldCount; i++) {
      if (_matches(i, name)) return true;
    }
    return false;
  }

  @override
  Uint8List? rawValue(final HeaderName name) {
    for (var i = 0; i < fieldCount; i++) {
      if (_matches(i, name)) return _rawAt(i);
    }
    return null;
  }

  @override
  List<Uint8List> rawValues(final HeaderName name) {
    final cache = _rawValues ??= {};
    final cached = cache[name];
    if (cached != null) return cached;
    final found = <Uint8List>[
      for (var i = 0; i < fieldCount; i++)
        if (_matches(i, name)) _rawAt(i),
    ];
    if (found.isEmpty) return const [];
    return cache[name] = found;
  }

  Uint8List _rawAt(final int i) {
    final raws = _fieldRaw ??= List.filled(fieldCount, null);
    if (raws[i] case final raw?) return raw;
    final offset = slots[i * 4 + 2];
    return raws[i] = Uint8List.sublistView(
      bytes,
      offset,
      offset + slots[i * 4 + 3],
    );
  }

  /// Whether field [i] is named [name].
  ///
  /// Two known names compare by id alone, so the walk to a known name reads
  /// nothing but the slot table. A custom name may spell a known one, so it
  /// compares by text.
  bool _matches(final int i, final HeaderName name) {
    final id = slots[i * 4 + 1];
    if (id >= 0 && name.id >= 0) return id == name.id;
    return _nameAt(i) == name;
  }

  HeaderName _nameAt(final int i) {
    final id = slots[i * 4 + 1];
    if (id >= 0) return HeaderName.known[id];
    final names = _fieldNames ??= List.filled(fieldCount, null);
    if (names[i] case final name?) return name;
    final offset = slots[i * 4];
    var end = offset;
    while (end < bytes.length && bytes[end] != 0x3a) {
      end++;
    }
    final name = HeaderName.lookup(String.fromCharCodes(bytes, offset, end));
    assert(
      name.id < 0,
      'The slot of ${name.lower} came without the id of a known name',
    );
    return names[i] = name;
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
