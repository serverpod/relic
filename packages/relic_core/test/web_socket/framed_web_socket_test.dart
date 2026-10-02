import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';

/// A framed socket over in-memory pipes, with the peer's side as raw
/// bytes: [toServer] is what the peer sends, [fromServer] what it gets.
final class _Harness {
  final toServer = StreamController<Uint8List>();
  final fromServer = StreamController<Uint8List>();
  late final FramedWebSocket socket;
  final _frames = <WebSocketFrame>[];
  final _waiting = <Completer<WebSocketFrame>>[];

  /// With [flushes] false, the peer's connection never flushes. The sink
  /// takes bytes and its close never completes, as a hijacked channel to a
  /// peer that stopped reading behaves.
  _Harness({
    final bool flushes = true,
    final int maxMessageSize = FramedWebSocket.defaultMaxMessageSize,
  }) {
    socket = FramedWebSocket(
      StreamChannel<Uint8List>(
        toServer.stream,
        flushes ? fromServer.sink : _StuckSink(fromServer.sink),
      ),
      maxMessageSize: maxMessageSize,
    );
    // An eager listener. A StreamQueue would pause the subscription
    // between requests, and the sink's close then never finishes.
    fromServer.stream.transform(const _ServerFrameDecoder()).listen((
      final frame,
    ) {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete(frame);
      } else {
        _frames.add(frame);
      }
    });
  }

  /// The next frame the peer received.
  Future<WebSocketFrame> get next {
    if (_frames.isNotEmpty) return Future.value(_frames.removeAt(0));
    final waiter = Completer<WebSocketFrame>();
    _waiting.add(waiter);
    return waiter.future;
  }

  /// A frame as the client sends it: masked with zeros, so the payload
  /// bytes are unchanged on the wire.
  void send(
    final WebSocketOpcode opcode,
    final List<int> payload, {
    final bool fin = true,
  }) {
    final out = BytesBuilder();
    out.addByte((fin ? 0x80 : 0) | opcode.code);
    if (payload.length < 126) {
      out.addByte(0x80 | payload.length);
    } else {
      out.addByte(0x80 | 126);
      out.add([payload.length >> 8, payload.length & 0xff]);
    }
    out.add([0, 0, 0, 0]);
    out.add(payload);
    toServer.add(out.takeBytes());
  }
}

/// A sink that forwards what is added and never finishes closing.
final class _StuckSink implements StreamSink<Uint8List> {
  final StreamSink<Uint8List> _inner;
  final _never = Completer<void>();

  _StuckSink(this._inner);

  @override
  void add(final Uint8List event) => _inner.add(event);

  @override
  void addError(final Object error, [final StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future<void> addStream(final Stream<Uint8List> stream) => stream.forEach(add);

  @override
  Future<void> close() => _never.future;

  @override
  Future<void> get done => _never.future;
}

/// Decodes server frames, which are never masked, into [WebSocketFrame]s.
final class _ServerFrameDecoder
    extends StreamTransformerBase<Uint8List, WebSocketFrame> {
  const _ServerFrameDecoder();

  @override
  Stream<WebSocketFrame> bind(final Stream<Uint8List> stream) async* {
    final buffer = BytesBuilder();
    await for (final chunk in stream) {
      buffer.add(chunk);
      while (true) {
        final bytes = buffer.toBytes();
        if (bytes.length < 2) break;
        var length = bytes[1] & 0x7f;
        var offset = 2;
        if (length == 126) {
          if (bytes.length < 4) break;
          length = (bytes[2] << 8) | bytes[3];
          offset = 4;
        } else if (length == 127) {
          if (bytes.length < 10) break;
          length = 0;
          for (var i = 2; i < 10; i++) {
            length = (length << 8) | bytes[i];
          }
          offset = 10;
        }
        if (bytes.length < offset + length) break;
        yield WebSocketFrame(
          WebSocketOpcode.fromCode(bytes[0] & 0x0f)!,
          Uint8List.sublistView(bytes, offset, offset + length),
          fin: bytes[0] & 0x80 != 0,
        );
        buffer
          ..clear()
          ..add(bytes.sublist(offset + length));
      }
    }
  }
}

void main() {
  late _Harness h;

  setUp(() => h = _Harness());

  test('Given a framed socket, when the peer sends text, '
      'then the handler gets a TextDataReceived', () async {
    h.send(WebSocketOpcode.text, utf8.encode('tick'));

    await expectLater(h.socket.events, emits(TextDataReceived('tick')));
  });

  test('Given a framed socket, when the handler sends text and bytes, '
      'then the peer gets unmasked frames', () async {
    h.socket.sendText('tock');
    h.socket.sendBytes(Uint8List.fromList([1, 2, 3]));

    final text = await h.next;
    final bytes = await h.next;
    expect(text.opcode, WebSocketOpcode.text);
    expect(utf8.decode(text.payload), 'tock');
    expect(bytes.opcode, WebSocketOpcode.binary);
    expect(bytes.payload, [1, 2, 3]);
  });

  test('Given a framed socket, when the peer pings, '
      'then a pong with the same payload goes back', () async {
    h.send(WebSocketOpcode.ping, utf8.encode('hi'));

    final pong = await h.next;
    expect(pong.opcode, WebSocketOpcode.pong);
    expect(utf8.decode(pong.payload), 'hi');
  });

  test(
    'Given a framed socket, when the peer closes with 1000, '
    'then the close is echoed, the events end with it and the sink closes',
    () async {
      h.send(WebSocketOpcode.close, encodeClosePayload(1000, 'bye'));

      await expectLater(
        h.socket.events,
        emitsInOrder([CloseReceived(1000, 'bye'), emitsDone]),
      );
      final echo = await h.next;
      expect(echo.opcode, WebSocketOpcode.close);
      expect(echo.payload, [0x03, 0xe8]);
      await expectLater(h.socket.done, completes);
      expect(h.socket.isClosed, isTrue);
    },
  );

  test('Given a framed socket, when the peer closes without a code, '
      'then the handler sees 1005', () async {
    h.send(WebSocketOpcode.close, const []);

    await expectLater(h.socket.events, emits(CloseReceived(1005, '')));
  });

  test(
    'Given a framed socket, when the handler closes with 3001, '
    'then the peer gets the close and the handshake completes on its answer',
    () async {
      final closed = h.socket.close(3001, 'done');

      final close = await h.next;
      expect(close.opcode, WebSocketOpcode.close);
      expect(close.payload.sublist(0, 2), [0x0b, 0xb9]);
      expect(utf8.decode(close.payload.sublist(2)), 'done');
      h.send(WebSocketOpcode.close, encodeClosePayload(3001, ''));

      await closed;
      await expectLater(h.socket.done, completes);
      expect(h.socket.isClosed, isTrue);
    },
  );

  test('Given a closed socket, when the handler sends or closes again, '
      'then it throws WebSocketConnectionClosed', () async {
    await h.socket.close();

    expect(
      () => h.socket.sendText('x'),
      throwsA(isA<WebSocketConnectionClosed>()),
    );
    expect(h.socket.trySendText('x'), isFalse);
    await expectLater(
      h.socket.close(),
      throwsA(isA<WebSocketConnectionClosed>()),
    );
    expect(await h.socket.tryClose(), isFalse);
  });

  test('Given a framed socket, '
      'when close gets a code outside 1000 and 3000-4999, '
      'then it is an ArgumentError', () {
    expect(() => h.socket.close(1001), throwsArgumentError);
    expect(() => h.socket.close(1000, 'x' * 124), throwsArgumentError);
  });

  test('Given a framed socket, when the peer breaks the protocol, '
      'then the handler gets an error, a 1002 close and the end', () async {
    final clock = Stopwatch()..start();
    h.toServer.add(Uint8List.fromList([0x81, 0x01, 0x41])); // unmasked

    await expectLater(
      h.socket.events,
      emitsInOrder([
        emitsError(isA<WebSocketException>()),
        CloseReceived(1002, 'A client frame must be masked'),
        emitsDone,
      ]),
    );
    final close = await h.next;
    expect(close.opcode, WebSocketOpcode.close);
    expect(close.payload.sublist(0, 2), [0x03, 0xea]);
    await h.socket.done;
    expect(
      clock.elapsed,
      lessThan(FramedWebSocket.closeTimeout),
      reason: 'The frame stream is over, so nothing can answer the close',
    );
  });

  test('Given a framed socket, when the peer sends text that is not UTF-8, '
      'then it closes with 1007', () async {
    h.send(WebSocketOpcode.text, [0xff, 0xfe]);

    await expectLater(
      h.socket.events,
      emitsInOrder([
        emitsError(anything),
        CloseReceived(1007, 'Text is not valid UTF-8'),
      ]),
    );
  });

  test('Given a framed socket, when the channel ends without a close frame, '
      'then the handler sees 1006', () async {
    await h.toServer.close();

    await expectLater(
      h.socket.events,
      emitsInOrder([CloseReceived(1006, ''), emitsDone]),
    );
  });

  test('Given a ping interval, when the peer never answers, '
      'then the socket closes with 1001', () async {
    h.socket.pingInterval = const Duration(milliseconds: 10);

    final ping = await h.next;
    expect(ping.opcode, WebSocketOpcode.ping);
    await expectLater(
      h.socket.events,
      emitsInOrder([CloseReceived(1001, ''), emitsDone]),
    );
    final close = await h.next;
    expect(close.opcode, WebSocketOpcode.close);
    expect(close.payload.sublist(0, 2), [0x03, 0xe9]);
  });

  test('Given a ping interval, when the peer answers every ping, '
      'then the socket stays open', () async {
    h.socket.pingInterval = const Duration(milliseconds: 10);
    for (var i = 0; i < 3; i++) {
      final ping = await h.next;
      expect(ping.opcode, WebSocketOpcode.ping);
      h.send(WebSocketOpcode.pong, const []);
    }

    expect(h.socket.isClosed, isFalse);
    h.socket.pingInterval = null;
  });

  test(
    'Given a framed socket with a ping interval, '
    'when the peer answers no ping, '
    'then it gets 1001 and done completes without the close timeout',
    () async {
      final clock = Stopwatch()..start();
      h.socket.pingInterval = const Duration(milliseconds: 10);

      await h.socket.done;

      expect(clock.elapsed, lessThan(FramedWebSocket.closeTimeout));
      expect(h.socket.isClosed, isTrue);
    },
  );

  test(
    'Given a framed socket, when the server goes away, '
    'then the peer gets 1001 and done completes without its answer',
    () async {
      final gone = h.socket.closeGoingAway();

      final close = await h.next;
      expect(close.opcode, WebSocketOpcode.close);
      expect(close.payload.sublist(0, 2), [0x03, 0xe9]);
      expect(h.socket.isClosed, isTrue);
      await expectLater(
        gone.timeout(FramedWebSocket.closeTimeout * 2),
        completes,
      );
    },
  );

  test('Given a peer whose connection never flushes, '
      'when the server goes away and the peer answers the close, '
      'then done still completes', () async {
    h = _Harness(flushes: false);
    final gone = h.socket.closeGoingAway();
    final close = await h.next;
    expect(close.opcode, WebSocketOpcode.close);

    h.send(WebSocketOpcode.close, [0x03, 0xe9]);

    await expectLater(
      gone.timeout(FramedWebSocket.closeTimeout * 2),
      completes,
    );
  });

  test('Given a framed socket, '
      'when the peer announces a frame larger than the message limit, '
      'then it is closed with 1009 before the payload', () async {
    // FIN + binary, masked, a 64-bit length of 64 MiB, and the mask.
    h.toServer.add(
      Uint8List.fromList([
        0x82, 0x80 | 127, 0, 0, 0, 0, 0x04, 0, 0, 0, 0, 0, 0, 0, //
      ]),
    );

    final close = await h.next.timeout(const Duration(seconds: 2));
    expect(close.opcode, WebSocketOpcode.close);
    expect(close.payload.sublist(0, 2), [0x03, 0xf1]);
    expect(h.socket.isClosed, isTrue);
  });

  test('Given a message limit, when fragments add up past it, '
      'then the socket is closed with 1009', () async {
    h = _Harness(maxMessageSize: 16);
    h.send(WebSocketOpcode.text, utf8.encode('0123456789'), fin: false);
    h.send(WebSocketOpcode.continuation, utf8.encode('0123456789'));

    final close = await h.next.timeout(const Duration(seconds: 2));
    expect(close.opcode, WebSocketOpcode.close);
    expect(close.payload.sublist(0, 2), [0x03, 0xf1]);
    expect(h.socket.isClosed, isTrue);
  });
}
