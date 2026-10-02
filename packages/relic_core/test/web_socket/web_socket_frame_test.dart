import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

/// A client frame: masked, with the given header bits, as a client sends
/// it (RFC 6455 5.1).
Uint8List _clientFrame(
  final int opcode,
  final List<int> payload, {
  final bool fin = true,
  final int rsv = 0,
  final bool masked = true,
  final bool longLength = false,
}) {
  final mask = [0x12, 0x34, 0x56, 0x78];
  final length = payload.length;
  final out = BytesBuilder();
  out.addByte((fin ? 0x80 : 0) | (rsv << 4) | opcode);
  final maskBit = masked ? 0x80 : 0;
  if (length < 126 && !longLength) {
    out.addByte(maskBit | length);
  } else if (length <= 0xffff) {
    out.addByte(maskBit | 126);
    out.add([length >> 8, length & 0xff]);
  } else {
    out.addByte(maskBit | 127);
    out.add([
      0,
      0,
      0,
      0,
      length >> 24,
      (length >> 16) & 0xff,
      (length >> 8) & 0xff,
      length & 0xff,
    ]);
  }
  if (masked) {
    out.add(mask);
    out.add([for (var i = 0; i < length; i++) payload[i] ^ mask[i & 3]]);
  } else {
    out.add(payload);
  }
  return out.takeBytes();
}

Future<List<WebSocketFrame>> _decode(final List<Uint8List> chunks) =>
    Stream.fromIterable(
      chunks,
    ).transform(const WebSocketFrameDecoder()).toList();

Future<Object> _decodeError(final List<Uint8List> chunks) async {
  try {
    await _decode(chunks);
  } catch (e) {
    return e;
  }
  fail('the decoder accepted the input');
}

void main() {
  group('Given the frame decoder', () {
    test('when a masked text frame arrives in one piece, '
        'then it comes out unmasked with its opcode and fin', () async {
      final frames = await _decode([_clientFrame(0x1, utf8.encode('Hello'))]);

      expect(frames, hasLength(1));
      expect(frames.single.opcode, WebSocketOpcode.text);
      expect(frames.single.fin, isTrue);
      expect(utf8.decode(frames.single.payload), 'Hello');
    });

    test('when a frame arrives one byte at a time, '
        'then it is reassembled', () async {
      final bytes = _clientFrame(
        0x2,
        List.generate(300, (final i) => i & 0xff),
      );

      final frames = await _decode([
        for (final b in bytes) Uint8List.fromList([b]),
      ]);

      expect(frames.single.opcode, WebSocketOpcode.binary);
      expect(frames.single.payload, List.generate(300, (final i) => i & 0xff));
    });

    test('when two frames share a chunk, then both come out', () async {
      final a = _clientFrame(0x1, utf8.encode('a'));
      final b = _clientFrame(0x9, utf8.encode('ping'));

      final frames = await _decode([
        Uint8List.fromList([...a, ...b]),
      ]);

      expect(frames.map((final f) => f.opcode), [
        WebSocketOpcode.text,
        WebSocketOpcode.ping,
      ]);
    });

    test('when the payload needs a 64-bit length, then it is read', () async {
      final payload = Uint8List(70000);
      final frames = await _decode([_clientFrame(0x2, payload)]);

      expect(frames.single.payload.length, 70000);
    });

    test('when a reserved bit is set, then it fails with 1002', () async {
      final error = await _decodeError([
        _clientFrame(0x1, utf8.encode('x'), rsv: 4),
      ]);

      expect(
        error,
        isA<WebSocketProtocolException>().having(
          (final e) => e.code,
          'code',
          1002,
        ),
      );
    });

    test('when the opcode is unknown, then it fails with 1002', () async {
      final error = await _decodeError([_clientFrame(0x3, const [])]);

      expect(
        error,
        isA<WebSocketProtocolException>().having(
          (final e) => e.code,
          'code',
          1002,
        ),
      );
    });

    test(
      'when a client frame is not masked, then it fails with 1002',
      () async {
        final error = await _decodeError([
          _clientFrame(0x1, utf8.encode('x'), masked: false),
        ]);

        expect(
          error,
          isA<WebSocketProtocolException>().having(
            (final e) => e.code,
            'code',
            1002,
          ),
        );
      },
    );

    test(
      'when a control frame is fragmented, then it fails with 1002',
      () async {
        final error = await _decodeError([
          _clientFrame(0x9, const [], fin: false),
        ]);

        expect(
          error,
          isA<WebSocketProtocolException>().having(
            (final e) => e.code,
            'code',
            1002,
          ),
        );
      },
    );

    test('when a control frame carries over 125 bytes, '
        'then it fails with 1002', () async {
      final error = await _decodeError([_clientFrame(0x9, Uint8List(126))]);

      expect(
        error,
        isA<WebSocketProtocolException>().having(
          (final e) => e.code,
          'code',
          1002,
        ),
      );
    });

    test('when a continuation has nothing to continue, '
        'then it fails with 1002', () async {
      final error = await _decodeError([_clientFrame(0x0, utf8.encode('x'))]);

      expect(
        error,
        isA<WebSocketProtocolException>().having(
          (final e) => e.code,
          'code',
          1002,
        ),
      );
    });

    test('when a new message starts inside a fragmented one, '
        'then it fails with 1002', () async {
      final error = await _decodeError([
        _clientFrame(0x1, utf8.encode('a'), fin: false),
        _clientFrame(0x1, utf8.encode('b')),
      ]);

      expect(
        error,
        isA<WebSocketProtocolException>().having(
          (final e) => e.code,
          'code',
          1002,
        ),
      );
    });

    test(
      'when a ping sits between fragments, then all three come out',
      () async {
        final frames = await _decode([
          _clientFrame(0x1, utf8.encode('a'), fin: false),
          _clientFrame(0x9, const []),
          _clientFrame(0x0, utf8.encode('b')),
        ]);

        expect(frames.map((final f) => f.opcode), [
          WebSocketOpcode.text,
          WebSocketOpcode.ping,
          WebSocketOpcode.continuation,
        ]);
      },
    );

    test('when the 64-bit length has its top bit set, '
        'then it fails with 1002', () async {
      final bytes = Uint8List.fromList([
        0x82,
        0xff,
        0x80,
        0,
        0,
        0,
        0,
        0,
        0,
        1,
        1,
        2,
        3,
        4,
      ]);

      final error = await _decodeError([bytes]);

      expect(
        error,
        isA<WebSocketProtocolException>().having(
          (final e) => e.code,
          'code',
          1002,
        ),
      );
    });

    test(
      'when a frame is over the frame limit, then it fails with 1009',
      () async {
        final error =
            await Stream.fromIterable([_clientFrame(0x2, Uint8List(200))])
                .transform(const WebSocketFrameDecoder(maxFrameSize: 100))
                .toList()
                .then<Object>(
                  (final _) => 'accepted',
                  onError: (final Object e) => e,
                );

        expect(
          error,
          isA<WebSocketProtocolException>().having(
            (final e) => e.code,
            'code',
            1009,
          ),
        );
      },
    );
  });

  group('Given the message assembler', () {
    test('when a text message comes in three fragments, '
        'then one message comes out', () {
      final assembler = WebSocketMessageAssembler();

      expect(
        assembler.add(
          WebSocketFrame(WebSocketOpcode.text, utf8.encode('He'), fin: false),
        ),
        isNull,
      );
      expect(
        assembler.add(
          WebSocketFrame(
            WebSocketOpcode.continuation,
            utf8.encode('ll'),
            fin: false,
          ),
        ),
        isNull,
      );
      final message = assembler.add(
        WebSocketFrame(WebSocketOpcode.continuation, utf8.encode('o')),
      );

      expect(message, isA<WebSocketText>());
      expect((message! as WebSocketText).text, 'Hello');
    });

    test('when a binary message completes, then its bytes come out', () {
      final assembler = WebSocketMessageAssembler();

      final message = assembler.add(
        WebSocketFrame(WebSocketOpcode.binary, Uint8List.fromList([1, 2])),
      );

      expect(message, isA<WebSocketBinary>());
      expect((message! as WebSocketBinary).bytes, [1, 2]);
    });

    test('when a text message is not UTF-8, then it fails with 1007', () {
      final assembler = WebSocketMessageAssembler();

      expect(
        () => assembler.add(
          WebSocketFrame(
            WebSocketOpcode.text,
            Uint8List.fromList([0xff, 0xfe]),
          ),
        ),
        throwsA(
          isA<WebSocketProtocolException>().having(
            (final e) => e.code,
            'code',
            1007,
          ),
        ),
      );
    });

    test('when a message is over the limit, then it fails with 1009', () {
      final assembler = WebSocketMessageAssembler(maxMessageSize: 3);

      expect(
        () =>
            assembler.add(WebSocketFrame(WebSocketOpcode.binary, Uint8List(4))),
        throwsA(
          isA<WebSocketProtocolException>().having(
            (final e) => e.code,
            'code',
            1009,
          ),
        ),
      );
    });

    test('when a control frame arrives mid-message, '
        'then it passes through at once', () {
      final assembler = WebSocketMessageAssembler();
      assembler.add(
        WebSocketFrame(WebSocketOpcode.binary, Uint8List(1), fin: false),
      );

      final ping = assembler.add(
        WebSocketFrame(WebSocketOpcode.ping, Uint8List(0)),
      );

      expect(ping, isA<WebSocketControl>());
      expect((ping! as WebSocketControl).frame.opcode, WebSocketOpcode.ping);
    });
  });

  group('Given the frame encoder', () {
    test('when a short payload is encoded, then the header is two bytes', () {
      final frame = encodeWebSocketFrame(
        WebSocketOpcode.text,
        utf8.encode('Hi'),
      );

      expect(frame, [0x81, 0x02, 0x48, 0x69]);
    });

    test('when the payload is 126 bytes or more, '
        'then the length takes two more bytes', () {
      final frame = encodeWebSocketFrame(
        WebSocketOpcode.binary,
        Uint8List(300),
      );

      expect(frame.sublist(0, 4), [0x82, 126, 0x01, 0x2c]);
      expect(frame.length, 304);
    });

    test('when the payload is over 65535 bytes, '
        'then the length takes eight more bytes', () {
      final frame = encodeWebSocketFrame(
        WebSocketOpcode.binary,
        Uint8List(70000),
      );

      expect(frame.sublist(0, 10), [0x82, 127, 0, 0, 0, 0, 0, 1, 0x11, 0x70]);
      expect(frame.length, 70010);
    });

    test('when a close payload has a code and reason, '
        'then the code leads in network order', () {
      expect(encodeClosePayload(1000, 'bye'), [0x03, 0xe8, 0x62, 0x79, 0x65]);
      expect(encodeClosePayload(null, 'ignored'), isEmpty);
    });

    test('when a server frame is decoded as a client frame, '
        'then the mask check rejects it', () async {
      final frame = encodeWebSocketFrame(
        WebSocketOpcode.text,
        utf8.encode('x'),
      );

      final error = await _decodeError([frame]);

      expect(error, isA<WebSocketProtocolException>());
    });
  });

  group('Given close codes', () {
    test(
      'when checked, then the registered ones pass and the reserved fail',
      () {
        for (final code in [
          1000,
          1001,
          1002,
          1003,
          1007,
          1011,
          1014,
          3000,
          4999,
        ]) {
          expect(isValidCloseCode(code), isTrue, reason: '$code');
        }
        for (final code in [999, 1004, 1005, 1006, 1015, 1016, 2999, 5000]) {
          expect(isValidCloseCode(code), isFalse, reason: '$code');
        }
      },
    );
  });
}
