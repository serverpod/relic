import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';

/// A message the receiver will not take, with the status that answers it.
final class HttpParseException implements Exception {
  final int status;
  final String message;

  const HttpParseException(this.status, this.message);

  @override
  String toString() => 'HTTP $status: $message';
}

/// A request head parsed in place: the bytes, and where things are in
/// them. Shaped as the native adapter hands a head over, so the same
/// [ByteHeaderStore] reads it.
final class RequestHead {
  final Method method;
  final HttpProtocol protocol;

  /// The head, through the empty line that ends it.
  final Uint8List bytes;

  /// Four entries per field, as [ByteHeaderStore] reads them: name offset,
  /// name id or -1, value offset and length.
  final Int32List slots;
  final int targetStart;
  final int targetEnd;

  /// The field index of Host, or -1.
  final int hostSlot;
  final int? contentLength;
  final bool chunked;
  final bool keepAlive;

  RequestHead._({
    required this.method,
    required this.protocol,
    required this.bytes,
    required this.slots,
    required this.targetStart,
    required this.targetEnd,
    required this.hostSlot,
    required this.contentLength,
    required this.chunked,
    required this.keepAlive,
  });

  Uint8List get target => Uint8List.sublistView(bytes, targetStart, targetEnd);

  /// The Host value, or null without one.
  String? get host {
    if (hostSlot < 0) return null;
    final start = slots[hostSlot * 4 + 2];
    return latin1.decode(
      Uint8List.sublistView(bytes, start, start + slots[hostSlot * 4 + 3]),
    );
  }

  /// Whether a body follows the head.
  bool get hasBody => chunked || (contentLength ?? 0) > 0;
}

/// A response head as a client reads it.
final class StatusHead {
  final HttpProtocol protocol;
  final int status;
  final String reason;

  /// Field values by lowercase name, in order of appearance.
  final Map<String, List<String>> headers;

  /// How many bytes of the buffer the head took.
  final int length;

  StatusHead._(
    this.protocol,
    this.status,
    this.reason,
    this.headers,
    this.length,
  );

  /// The values of [name] joined with a comma, or null.
  String? header(final String name) => headers[name.toLowerCase()]?.join(', ');

  int? get contentLength {
    final value = header('content-length');
    return value == null ? null : int.tryParse(value);
  }

  bool get chunked => _tokens(header('transfer-encoding')).contains('chunked');

  /// Whether the server closes the connection after this response.
  bool get closes => _tokens(header('connection')).contains('close');

  /// Whether a body follows this head for a request with [method].
  bool hasBody(final Method method) =>
      method != Method.head && statusMayHaveBody(status);
}

const _cr = 0x0d;
const _lf = 0x0a;
const _sp = 0x20;
const _htab = 0x09;
const _colon = 0x3a;

/// Parses the request head at the start of [buffer]'s first [length]
/// bytes. Null when the head is not complete yet.
///
/// Throws [HttpParseException] for a head the server answers with a
/// status: 400 for one that is malformed, 431 for one over [maxHeadSize],
/// 501 for an unknown method or a transfer coding other than chunked, 505
/// for an HTTP version other than 1.0 and 1.1.
RequestHead? parseRequestHead(
  final Uint8List buffer,
  final int length, {
  required final int maxHeadSize,
}) {
  final scanned = _scanLines(buffer, length, maxHeadSize);
  if (scanned == null) return null;
  final (lines, headEnd) = scanned;

  final (lineStart, lineEnd) = lines.first;
  final sp1 = _indexOf(buffer, _sp, lineStart, lineEnd);
  final sp2 = sp1 < 0 ? -1 : _indexOf(buffer, _sp, sp1 + 1, lineEnd);
  if (sp1 < 0 || sp2 < 0 || _indexOf(buffer, _sp, sp2 + 1, lineEnd) >= 0) {
    throw const HttpParseException(400, 'The request line has three parts');
  }
  if (sp1 == lineStart || sp2 == sp1 + 1) {
    throw const HttpParseException(400, 'The method and target are not empty');
  }
  final Method method;
  try {
    method = Method.parse(
      latin1.decode(Uint8List.sublistView(buffer, lineStart, sp1)),
    );
  } on FormatException {
    throw const HttpParseException(501, 'The method is not implemented');
  }
  final protocol = switch (latin1.decode(
    Uint8List.sublistView(buffer, sp2 + 1, lineEnd),
  )) {
    'HTTP/1.1' => HttpProtocol.http11,
    'HTTP/1.0' => HttpProtocol.http10,
    final version when version.startsWith('HTTP/') =>
      throw const HttpParseException(505, 'The HTTP version is not supported'),
    _ => throw const HttpParseException(400, 'The HTTP version is malformed'),
  };

  final fieldCount = lines.length - 1;
  final slots = Int32List(fieldCount * 4);
  var hostSlot = -1;
  var hostCount = 0;
  int? contentLength;
  var transferEncoding = false;
  var chunked = false;
  var close = false;
  var keepAlive = false;
  for (var f = 0; f < fieldCount; f++) {
    final (start, end) = lines[f + 1];
    final colon = _indexOf(buffer, _colon, start, end);
    if (colon <= start) {
      throw const HttpParseException(400, 'A field has a name and a colon');
    }
    for (var i = start; i < colon; i++) {
      if (!_isTokenChar(buffer[i])) {
        throw const HttpParseException(400, 'A field name is a token');
      }
    }
    var valueStart = colon + 1;
    while (valueStart < end && _isBlank(buffer[valueStart])) {
      valueStart++;
    }
    var valueEnd = end;
    while (valueEnd > valueStart && _isBlank(buffer[valueEnd - 1])) {
      valueEnd--;
    }
    for (var i = valueStart; i < valueEnd; i++) {
      final b = buffer[i];
      if (b == 0x7f || (b < _sp && b != _htab)) {
        throw const HttpParseException(400, 'A field value has no controls');
      }
    }
    final name = _lowerAscii(buffer, start, colon);
    slots[f * 4] = start;
    slots[f * 4 + 1] = HeaderName.lookup(name).id;
    slots[f * 4 + 2] = valueStart;
    slots[f * 4 + 3] = valueEnd - valueStart;
    final value = latin1.decode(
      Uint8List.sublistView(buffer, valueStart, valueEnd),
    );
    switch (name) {
      case 'host':
        hostCount++;
        hostSlot = f;
      case 'content-length':
        final parsed = _isDigits(value) ? int.tryParse(value) : null;
        if (parsed == null) {
          throw const HttpParseException(400, 'Content-Length is digits');
        }
        if (contentLength != null && contentLength != parsed) {
          throw const HttpParseException(400, 'Content-Length differs');
        }
        contentLength = parsed;
      case 'transfer-encoding':
        transferEncoding = true;
        for (final coding in _tokens(value)) {
          if (chunked) {
            throw const HttpParseException(400, 'chunked is the last coding');
          }
          if (coding != 'chunked') {
            throw const HttpParseException(501, 'A coding is not implemented');
          }
          chunked = true;
        }
      case 'connection':
        final tokens = _tokens(value);
        close |= tokens.contains('close');
        keepAlive |= tokens.contains('keep-alive');
    }
  }
  if (transferEncoding && !chunked) {
    throw const HttpParseException(400, 'Transfer-Encoding names a coding');
  }
  if (chunked && contentLength != null) {
    throw const HttpParseException(
      400,
      'A message has Content-Length or Transfer-Encoding, not both',
    );
  }
  if (hostCount > 1 || (protocol == HttpProtocol.http11 && hostCount == 0)) {
    throw const HttpParseException(400, 'A request has one Host');
  }
  return RequestHead._(
    method: method,
    protocol: protocol,
    bytes: buffer.sublist(0, headEnd),
    slots: slots,
    targetStart: sp1 + 1,
    targetEnd: sp2,
    hostSlot: hostSlot,
    contentLength: contentLength,
    chunked: chunked,
    keepAlive: protocol == HttpProtocol.http11 ? !close : keepAlive,
  );
}

/// Parses the response head at the start of [buffer]'s first [length]
/// bytes. Null when the head is not complete yet. Throws
/// [HttpParseException] with status 0 for a head that does not parse.
StatusHead? parseStatusHead(final Uint8List buffer, final int length) {
  final scanned = _scanLines(buffer, length, 1 << 20);
  if (scanned == null) return null;
  final (lines, headEnd) = scanned;
  final (lineStart, lineEnd) = lines.first;
  final line = latin1.decode(Uint8List.sublistView(buffer, lineStart, lineEnd));
  final match = RegExp(r'^HTTP/1\.([01]) (\d{3})(?: (.*))?$').firstMatch(line);
  if (match == null) {
    throw HttpParseException(0, 'Not a status line: "$line"');
  }
  final headers = <String, List<String>>{};
  for (var f = 1; f < lines.length; f++) {
    final (start, end) = lines[f];
    final colon = _indexOf(buffer, _colon, start, end);
    if (colon <= start) {
      throw const HttpParseException(0, 'A field has a name and a colon');
    }
    final value = latin1
        .decode(Uint8List.sublistView(buffer, colon + 1, end))
        .trim();
    headers.putIfAbsent(_lowerAscii(buffer, start, colon), () => []).add(value);
  }
  return StatusHead._(
    match.group(1) == '0' ? HttpProtocol.http10 : HttpProtocol.http11,
    int.parse(match.group(2)!),
    match.group(3) ?? '',
    headers,
    headEnd,
  );
}

/// The CRLF-ended lines of a head and the offset past its empty line, or
/// null when the empty line has not arrived. Empty lines before the first
/// line are skipped (RFC 9112 2.2).
(List<(int, int)>, int)? _scanLines(
  final Uint8List buffer,
  final int length,
  final int maxHeadSize,
) {
  final lines = <(int, int)>[];
  var lineStart = 0;
  while (true) {
    final lf = _indexOf(buffer, _lf, lineStart, length);
    if (lf < 0) {
      if (length > maxHeadSize) {
        throw const HttpParseException(431, 'The head is too large');
      }
      return null;
    }
    if (lf == lineStart || buffer[lf - 1] != _cr) {
      throw const HttpParseException(400, 'A line ends with CRLF');
    }
    final end = lf - 1;
    if (end == lineStart) {
      if (lines.isNotEmpty) return (lines, lf + 1);
    } else {
      lines.add((lineStart, end));
    }
    lineStart = lf + 1;
    if (lineStart > maxHeadSize) {
      throw const HttpParseException(431, 'The head is too large');
    }
  }
}

/// Decodes a chunked body as its bytes arrive (RFC 9112 7.1).
final class ChunkedDecoder {
  var _state = _ChunkState.size;
  var _remaining = 0;
  final _line = BytesBuilder(copy: true);
  var _done = false;

  /// Whether the last chunk and the trailer section have been read.
  bool get isDone => _done;

  /// Decodes [buffer] from [start] to [end], handing chunk data to [out].
  /// Returns where it stopped: [end], or earlier once the body is done,
  /// where the next message begins. Throws [FormatException] for a body
  /// that is not chunked coding.
  int feed(
    final Uint8List buffer,
    final int start,
    final int end,
    final void Function(Uint8List) out,
  ) {
    var i = start;
    while (i < end && !_done) {
      if (_state == _ChunkState.data) {
        final n = min(_remaining, end - i);
        out(Uint8List.sublistView(buffer, i, i + n));
        i += n;
        _remaining -= n;
        if (_remaining == 0) _state = _ChunkState.dataEnd;
        continue;
      }
      final lf = _indexOf(buffer, _lf, i, end);
      if (lf < 0) {
        _line.add(Uint8List.sublistView(buffer, i, end));
        if (_line.length > 1024) throw const FormatException('Chunk line');
        return end;
      }
      _line.add(Uint8List.sublistView(buffer, i, lf));
      i = lf + 1;
      final line = _line.takeBytes();
      if (line.isEmpty || line.last != _cr) {
        throw const FormatException('A chunk line ends with CRLF');
      }
      final text = latin1.decode(line.sublist(0, line.length - 1));
      switch (_state) {
        case _ChunkState.size:
          final semicolon = text.indexOf(';');
          final hex = (semicolon < 0 ? text : text.substring(0, semicolon))
              .trim();
          if (hex.isEmpty || !RegExp(r'^[0-9a-fA-F]{1,15}$').hasMatch(hex)) {
            throw FormatException('Not a chunk size: "$text"');
          }
          _remaining = int.parse(hex, radix: 16);
          _state = _remaining == 0 ? _ChunkState.trailer : _ChunkState.data;
        case _ChunkState.dataEnd:
          if (text.isNotEmpty) {
            throw const FormatException('Chunk data ends with CRLF');
          }
          _state = _ChunkState.size;
        case _ChunkState.trailer:
          if (text.isEmpty) _done = true;
        case _ChunkState.data:
          throw StateError('unreachable');
      }
    }
    return i;
  }
}

enum _ChunkState { size, data, dataEnd, trailer }

/// One chunk of a chunked body: the size in hex, the data, CRLFs.
Uint8List encodeChunk(final Uint8List data) {
  final size = ascii.encode('${data.length.toRadixString(16)}\r\n');
  final out = Uint8List(size.length + data.length + 2);
  out.setRange(0, size.length, size);
  out.setRange(size.length, size.length + data.length, data);
  out[out.length - 2] = _cr;
  out[out.length - 1] = _lf;
  return out;
}

/// The last chunk and an empty trailer section.
final lastChunk = Uint8List.fromList(ascii.encode('0\r\n\r\n'));

int _indexOf(
  final Uint8List bytes,
  final int byte,
  final int start,
  final int end,
) {
  for (var i = start; i < end; i++) {
    if (bytes[i] == byte) return i;
  }
  return -1;
}

bool _isBlank(final int byte) => byte == _sp || byte == _htab;

bool _isDigits(final String text) => RegExp(r'^[0-9]+$').hasMatch(text);

bool _isTokenChar(final int b) =>
    (b >= 0x30 && b <= 0x39) ||
    (b >= 0x41 && b <= 0x5a) ||
    (b >= 0x61 && b <= 0x7a) ||
    const [
      0x21, 0x23, 0x24, 0x25, 0x26, 0x27, 0x2a, 0x2b, 0x2d, 0x2e, //
      0x5e, 0x5f, 0x60, 0x7c, 0x7e,
    ].contains(b);

String _lowerAscii(final Uint8List bytes, final int start, final int end) =>
    latin1.decode(Uint8List.sublistView(bytes, start, end)).toLowerCase();

List<String> _tokens(final String? value) => value == null
    ? const []
    : [
        for (final token in value.split(','))
          if (token.trim().isNotEmpty) token.trim().toLowerCase(),
      ];
