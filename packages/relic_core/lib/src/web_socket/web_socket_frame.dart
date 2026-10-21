import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// RFC 6455 5.2 opcodes.
enum WebSocketOpcode {
  continuation(0x0),
  text(0x1),
  binary(0x2),
  close(0x8),
  ping(0x9),
  pong(0xa);

  final int code;
  const WebSocketOpcode(this.code);

  bool get isControl => code >= 0x8;

  static WebSocketOpcode? fromCode(int code) => switch (code) {
    0x0 => continuation,
    0x1 => text,
    0x2 => binary,
    0x8 => close,
    0x9 => ping,
    0xa => pong,
    _ => null,
  };
}

/// One frame off the wire, unmasked.
final class WebSocketFrame {
  final WebSocketOpcode opcode;
  final bool fin;
  final Uint8List payload;

  WebSocketFrame(this.opcode, this.payload, {this.fin = true});
}

/// What [WebSocketMessageAssembler.add] hands out: a complete message,
/// or a control frame as it came.
sealed class WebSocketInbound {
  const WebSocketInbound();
}

/// A text message.
///
/// The assembler decodes it once, as the UTF-8 check.
final class WebSocketText extends WebSocketInbound {
  final String text;

  const WebSocketText(this.text);
}

/// A binary message.
final class WebSocketBinary extends WebSocketInbound {
  final Uint8List bytes;

  const WebSocketBinary(this.bytes);
}

/// A ping, pong or close frame, which passes through the assembler at
/// once, even in the middle of a fragmented message.
final class WebSocketControl extends WebSocketInbound {
  final WebSocketFrame frame;

  const WebSocketControl(this.frame);
}

/// A peer that broke the framing rules.
///
/// [code] is the close code to answer with: 1002 for a protocol error,
/// 1007 for bad UTF-8, 1009 for a message over the size limit.
final class WebSocketProtocolException implements Exception {
  final int code;
  final String message;

  WebSocketProtocolException(this.code, this.message);

  @override
  String toString() => 'WebSocketProtocolException($code): $message';
}

/// Whether [code] is one a peer may send in a close frame (RFC 6455 7.4
/// and the IANA registry).
///
/// 1005, 1006 and 1015 are reserved for local use and 1004 is not defined.
bool isValidCloseCode(int code) =>
    (code >= 1000 && code <= 1003) ||
    (code >= 1007 && code <= 1014) ||
    (code >= 3000 && code <= 4999);

/// Throws [ArgumentError] unless [code] is one this side may close with:
/// none, 1000, or 3000 to 4999.
void checkCloseCode(int? code) {
  if (code != null && code != 1000 && !(code >= 3000 && code <= 4999)) {
    throw ArgumentError(
      'Invalid argument: $code, close code must be 1000 or '
      'in the range 3000-4999',
    );
  }
}

/// Throws [ArgumentError] when [reason] is over 123 bytes as UTF-8.
void checkCloseReason(String? reason) {
  if (reason != null && utf8.encode(reason).length > 123) {
    throw ArgumentError.value(
      reason,
      'reason',
      'reason must be <= 123 bytes long when encoded as UTF-8',
    );
  }
}

/// Encodes a server frame, which is never masked (RFC 6455 5.1).
Uint8List encodeWebSocketFrame(
  WebSocketOpcode opcode,
  List<int> payload, {
  bool fin = true,
}) {
  final length = payload.length;
  final extra = length < 126
      ? 0
      : length <= 0xffff
      ? 2
      : 8;
  final frame = Uint8List(2 + extra + length);
  frame[0] = (fin ? 0x80 : 0) | opcode.code;
  if (extra == 0) {
    frame[1] = length;
  } else if (extra == 2) {
    frame[1] = 126;
    frame[2] = length >> 8;
    frame[3] = length & 0xff;
  } else {
    frame[1] = 127;
    var n = length;
    for (var i = 9; i >= 2; i--) {
      frame[i] = n & 0xff;
      n >>= 8;
    }
  }
  frame.setRange(2 + extra, frame.length, payload);
  return frame;
}

/// The payload of a close frame: the code, then the reason in UTF-8, or
/// nothing at all when there is no code.
Uint8List encodeClosePayload(int? code, String reason) {
  if (code == null) return Uint8List(0);
  final text = utf8.encode(reason);
  final payload = Uint8List(2 + text.length);
  payload[0] = code >> 8;
  payload[1] = code & 0xff;
  payload.setRange(2, payload.length, text);
  return payload;
}

/// The inverse of [encodeClosePayload].
///
/// A payload without a code decodes to 1005 and no reason. The reason must
/// be valid UTF-8.
({int code, String reason}) decodeClosePayload(Uint8List payload) {
  if (payload.length < 2) return (code: 1005, reason: '');
  return (
    code: (payload[0] << 8) | payload[1],
    reason: utf8.decode(Uint8List.sublistView(payload, 2)),
  );
}

/// Splits a byte stream from a client into frames.
///
/// Checks what RFC 6455 lets a server check at the frame level: reserved
/// bits, opcodes, the mask, control frame size and fragmentation. Payloads
/// come out unmasked. A violation ends the stream with a
/// [WebSocketProtocolException].
///
/// Message assembly and the UTF-8 check happen one level up, in
/// [WebSocketMessageAssembler], so a ping in the middle of a fragmented
/// message gets its answer without waiting for the message.
final class WebSocketFrameDecoder
    extends StreamTransformerBase<Uint8List, WebSocketFrame> {
  /// The payload size over which a frame is refused with 1009.
  final int? maxFrameSize;

  const WebSocketFrameDecoder({this.maxFrameSize});

  @override
  Stream<WebSocketFrame> bind(Stream<Uint8List> stream) {
    final parser = _FrameParser(maxFrameSize);
    return stream.transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) {
          try {
            parser.add(data, sink.add);
          } on WebSocketProtocolException catch (e, st) {
            sink.addError(e, st);
            sink.close();
          }
        },
      ),
    );
  }
}

enum _ParseState { header, length, mask, payload }

final class _FrameParser {
  final int? maxFrameSize;
  var _state = _ParseState.header;
  var _fin = false;
  WebSocketOpcode _opcode = WebSocketOpcode.continuation;
  var _masked = false;
  var _lengthBytes = 0;
  var _length = 0;
  final _mask = Uint8List(4);
  var _got = 0;
  Uint8List _payload = Uint8List(0);
  var _inMessage = false;

  _FrameParser(this.maxFrameSize);

  void add(Uint8List data, void Function(WebSocketFrame) emit) {
    var i = 0;
    while (i < data.length) {
      switch (_state) {
        case _ParseState.header:
          final first = data[i++];
          if (first & 0x70 != 0) {
            throw WebSocketProtocolException(1002, 'Reserved bits set');
          }
          _fin = first & 0x80 != 0;
          final opcode = WebSocketOpcode.fromCode(first & 0x0f);
          if (opcode == null) {
            throw WebSocketProtocolException(1002, 'Unknown opcode');
          }
          _opcode = opcode;
          if (opcode.isControl) {
            if (!_fin) {
              throw WebSocketProtocolException(
                1002,
                'A control frame cannot be fragmented',
              );
            }
          } else if (opcode == WebSocketOpcode.continuation) {
            if (!_inMessage) {
              throw WebSocketProtocolException(
                1002,
                'A continuation frame with no message to continue',
              );
            }
          } else if (_inMessage) {
            throw WebSocketProtocolException(
              1002,
              'A new message while one is still being fragmented',
            );
          }
          _state = _ParseState.length;
        case _ParseState.length:
          if (_lengthBytes == 0) {
            final second = data[i++];
            _masked = second & 0x80 != 0;
            if (!_masked) {
              throw WebSocketProtocolException(
                1002,
                'A client frame must be masked',
              );
            }
            final len = second & 0x7f;
            if (len < 126) {
              _length = len;
              _onLength();
            } else {
              if (_opcode.isControl) {
                throw WebSocketProtocolException(
                  1002,
                  'A control frame payload is at most 125 bytes',
                );
              }
              _length = 0;
              _lengthBytes = len == 126 ? 2 : 8;
              _got = 0;
            }
          } else {
            final byte = data[i++];
            if (_got == 0 && _lengthBytes == 8 && byte & 0x80 != 0) {
              throw WebSocketProtocolException(
                1002,
                'The most significant bit of a 64-bit length must be 0',
              );
            }
            _length = (_length << 8) | byte;
            _got++;
            if (_got == _lengthBytes) {
              _lengthBytes = 0;
              _onLength();
            }
          }
        case _ParseState.mask:
          _mask[_got++] = data[i++];
          if (_got == 4) {
            _got = 0;
            _onMaskRead(emit);
          }
        case _ParseState.payload:
          final take = _length - _got < data.length - i
              ? _length - _got
              : data.length - i;
          _payload.setRange(_got, _got + take, data, i);
          _got += take;
          i += take;
          if (_got == _length) _emit(emit);
      }
    }
  }

  void _onLength() {
    final limit = maxFrameSize;
    if (limit != null && _length > limit) {
      throw WebSocketProtocolException(1009, 'Frame too big');
    }
    _got = 0;
    _state = _ParseState.mask;
  }

  void _onMaskRead(void Function(WebSocketFrame) emit) {
    _payload = Uint8List(_length);
    _got = 0;
    _state = _ParseState.payload;
    if (_length == 0) _emit(emit);
  }

  void _emit(void Function(WebSocketFrame) emit) {
    final payload = _payload;
    _unmask(payload);
    if (!_opcode.isControl) _inMessage = !_fin;
    _state = _ParseState.header;
    _lengthBytes = 0;
    _got = 0;
    _payload = _empty;
    emit(WebSocketFrame(_opcode, payload, fin: _fin));
  }

  static final _empty = Uint8List(0);

  /// Unmasks [payload] a word at a time, then the tail by byte.
  ///
  /// The word view needs alignment, which [payload] has since it was
  /// allocated whole.
  void _unmask(Uint8List payload) {
    final mask = _mask;
    final words = payload.length >> 2;
    if (words > 0) {
      final word = Endian.host == Endian.little
          ? mask[0] | (mask[1] << 8) | (mask[2] << 16) | (mask[3] << 24)
          : (mask[0] << 24) | (mask[1] << 16) | (mask[2] << 8) | mask[3];
      final view = Uint32List.view(
        payload.buffer,
        payload.offsetInBytes,
        words,
      );
      for (var k = 0; k < words; k++) {
        view[k] ^= word;
      }
    }
    for (var k = words << 2; k < payload.length; k++) {
      payload[k] ^= mask[k & 3];
    }
  }
}

/// Joins fragments into messages and decodes text.
///
/// Throws [WebSocketProtocolException] 1007 on malformed text and 1009 on
/// a message over [maxMessageSize]. Control frames pass straight through.
final class WebSocketMessageAssembler {
  final int? maxMessageSize;
  WebSocketOpcode? _opcode;
  final _parts = BytesBuilder(copy: false);

  WebSocketMessageAssembler({this.maxMessageSize});

  /// The message [frame] completes, or null while one is still being
  /// fragmented.
  ///
  /// A control frame comes back as is.
  WebSocketInbound? add(WebSocketFrame frame) {
    if (frame.opcode.isControl) return WebSocketControl(frame);
    final opcode = _opcode ??= frame.opcode;
    final limit = maxMessageSize;
    if (limit != null && _parts.length + frame.payload.length > limit) {
      throw WebSocketProtocolException(1009, 'Message too big');
    }
    _parts.add(frame.payload);
    if (!frame.fin) return null;
    _opcode = null;
    final payload = _parts.takeBytes();
    if (opcode != WebSocketOpcode.text) return WebSocketBinary(payload);
    try {
      return WebSocketText(utf8.decode(payload));
    } on FormatException {
      throw WebSocketProtocolException(1007, 'Text is not valid UTF-8');
    }
  }
}
