import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket/web_socket.dart';

import '../adapter/relic_web_socket.dart';
import 'web_socket_frame.dart';

/// A [RelicWebSocket] framed in Dart over a raw byte channel, for an
/// adapter that can hand a connection over but has no framer of its own.
/// The opening handshake is done before this is created.
///
/// The close handshake: whoever closes first sends a close frame and
/// waits up to [closeTimeout] for the other side's, then the channel's
/// sink is closed, which ends the connection. Pings go out every
/// [pingInterval] when one is set, and a peer that does not answer one
/// before the next is due is gone: the socket closes with 1001.
final class FramedWebSocket implements RelicWebSocket {
  /// How long a close waits for the peer's close frame, and then for the
  /// channel to flush.
  static const closeTimeout = Duration(seconds: 2);

  /// The message size a peer may send unless the socket is given another:
  /// a frame or a message over it closes the socket with 1009. The peer
  /// names the size before the bytes arrive, so without a limit it would
  /// name the allocation too.
  static const defaultMaxMessageSize = 16 << 20;

  final StreamChannel<Uint8List> _channel;
  final _events = StreamController<WebSocketEvent>();
  final _done = Completer<void>();
  final WebSocketMessageAssembler _assembler;
  late final StreamSubscription<WebSocketFrame> _frames;
  var _closeSent = false;
  var _sinkClosed = false;
  Timer? _closeTimer;
  Timer? _pingTimer;
  Duration? _pingInterval;
  var _pongPending = false;

  FramedWebSocket(
    this._channel, {
    final int maxMessageSize = defaultMaxMessageSize,
  }) : _assembler = WebSocketMessageAssembler(maxMessageSize: maxMessageSize) {
    _frames = _channel.stream
        .transform(WebSocketFrameDecoder(maxFrameSize: maxMessageSize))
        .listen(
          _onFrame,
          onError: _onError,
          onDone: _onDone,
          cancelOnError: true,
        );
  }

  @override
  Future<void> get done => _done.future;

  @override
  Stream<WebSocketEvent> get events => _events.stream;

  @override
  bool get isClosed => _events.isClosed;

  @override
  String get protocol => '';

  @override
  Duration? get pingInterval => _pingInterval;

  @override
  set pingInterval(final Duration? value) {
    _pingInterval = value;
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongPending = false;
    if (value == null || _closeSent) return;
    _pingTimer = Timer.periodic(value, (_) {
      if (_pongPending) {
        // A peer that let a ping go unanswered will not answer the close
        // frame either, so the channel closes behind it at once rather
        // than after closeTimeout.
        _goAway(1001, '');
        _closeSink();
        return;
      }
      _pongPending = true;
      _send(WebSocketOpcode.ping, const []);
    });
  }

  @override
  void sendBytes(final Uint8List b) {
    if (!trySendBytes(b)) throw WebSocketConnectionClosed();
  }

  @override
  void sendText(final String s) {
    if (!trySendText(s)) throw WebSocketConnectionClosed();
  }

  @override
  bool trySendBytes(final Uint8List b) {
    if (isClosed) return false;
    _send(WebSocketOpcode.binary, b);
    return true;
  }

  @override
  bool trySendText(final String s) {
    if (isClosed) return false;
    _send(WebSocketOpcode.text, utf8.encode(s));
    return true;
  }

  @override
  Future<void> close([final int? code, final String? reason]) async {
    if (!await tryClose(code, reason)) throw WebSocketConnectionClosed();
  }

  @override
  Future<bool> tryClose([final int? code, final String? reason]) async {
    if (isClosed) return false;
    checkCloseCode(code);
    checkCloseReason(reason);
    _closeEvents();
    _sendClose(code, reason ?? '');
    return true;
  }

  /// Waits for the peer's close frame, [closeTimeout] at most, then for
  /// the channel to flush, as long again.
  @override
  Future<void> closeGoingAway() {
    if (!isClosed) {
      _closeEvents();
      _sendClose(1001, 'Server shutting down');
    }
    return _done.future;
  }

  void _onFrame(final WebSocketFrame raw) {
    final WebSocketInbound? inbound;
    try {
      inbound = _assembler.add(raw);
    } on WebSocketProtocolException catch (e) {
      _fail(e);
      return;
    }
    switch (inbound) {
      case null:
        return;
      case WebSocketText(:final text):
        if (!_events.isClosed) _events.add(TextDataReceived(text));
      case WebSocketBinary(:final bytes):
        if (!_events.isClosed) _events.add(BinaryDataReceived(bytes));
      case WebSocketControl(:final frame):
        switch (frame.opcode) {
          case WebSocketOpcode.ping:
            _send(WebSocketOpcode.pong, frame.payload);
          case WebSocketOpcode.pong:
            _pongPending = false;
          case WebSocketOpcode.close:
            _onCloseFrame(frame.payload);
          case WebSocketOpcode.continuation:
          case WebSocketOpcode.text:
          case WebSocketOpcode.binary:
            // Not control frames. The assembler never hands these out here.
            break;
        }
    }
  }

  void _onCloseFrame(final Uint8List payload) {
    int? code;
    var reason = '';
    if (payload.length == 1) {
      _fail(WebSocketProtocolException(1002, 'A close code is two bytes'));
      return;
    }
    if (payload.length >= 2) {
      code = (payload[0] << 8) | payload[1];
      if (!isValidCloseCode(code)) {
        _fail(WebSocketProtocolException(1002, 'Close code $code'));
        return;
      }
      try {
        reason = utf8.decode(payload.sublist(2));
      } on FormatException {
        _fail(
          WebSocketProtocolException(1007, 'Close reason is not valid UTF-8'),
        );
        return;
      }
    }
    if (_closeSent) {
      // The peer answered our close. The handshake is complete.
      _closeSink();
      return;
    }
    // The peer closes first: echo its code, then it is over.
    _closeSent = true;
    _send(WebSocketOpcode.close, encodeClosePayload(code, ''));
    _closeEvents(CloseReceived(code ?? 1005, reason));
    _closeSink();
  }

  /// A frame the peer should not have sent. The connection closes with
  /// the code the violation calls for, and the handler hears why.
  void _fail(final WebSocketProtocolException e) {
    if (!_events.isClosed) _events.addError(WebSocketException(e.message));
    _goAway(e.code, e.message);
  }

  void _onError(final Object error, final StackTrace stackTrace) {
    if (error is WebSocketProtocolException) {
      _fail(error);
      // The decoder ended the frame stream, so the peer's answer to the
      // close frame can never be read and nothing waits for it.
      _closeSink();
      return;
    }
    if (!_events.isClosed) {
      _events.addError(WebSocketException(error.toString()), stackTrace);
    }
    _dropped();
  }

  void _onDone() => _dropped();

  /// The connection ended without a close handshake.
  void _dropped() {
    _closeEvents(CloseReceived(1006, ''));
    _closeSink();
  }

  /// Closes from our side with [code], and the handler sees that close.
  void _goAway(final int code, final String reason) {
    _closeEvents(CloseReceived(code, reason));
    _sendClose(code, reason);
  }

  /// Ends the handler's events, after [close] when it should hear how the
  /// connection closed. Nothing happens on events that already ended.
  void _closeEvents([final CloseReceived? close]) {
    if (_events.isClosed) return;
    if (close != null) _events.add(close);
    unawaited(_events.close());
  }

  void _sendClose(final int? code, final String reason) {
    if (_closeSent) return;
    _closeSent = true;
    _pingTimer?.cancel();
    _pingTimer = null;
    _send(WebSocketOpcode.close, encodeClosePayload(code, reason));
    _closeTimer = Timer(closeTimeout, _closeSink);
  }

  void _send(final WebSocketOpcode opcode, final List<int> payload) {
    if (_sinkClosed) return;
    try {
      _channel.sink.add(encodeWebSocketFrame(opcode, payload));
    } catch (_) {
      // The channel is gone. Its stream reports that.
    }
  }

  void _closeSink() {
    if (_sinkClosed) return;
    _sinkClosed = true;
    _closeTimer?.cancel();
    _pingTimer?.cancel();
    unawaited(_frames.cancel());
    _closeEvents();
    // A peer that stopped reading never lets the close flush. Past the
    // deadline the socket is done with the channel, and the adapter drops
    // the connection at its own.
    unawaited(
      _channel.sink
          .close()
          .timeout(closeTimeout)
          .catchError((_) {})
          .whenComplete(() {
            if (!_done.isCompleted) _done.complete();
          }),
    );
  }
}
