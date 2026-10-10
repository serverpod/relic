import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket/web_socket.dart';

import '../adapter/relic_web_socket.dart';
import 'relic_web_socket_base.dart';
import 'web_socket_frame.dart';

/// A [RelicWebSocket] framed in Dart over a raw byte channel, for an
/// adapter that can hand a connection over but has no framer of its own.
///
/// The opening handshake is done before this is created. Whoever closes
/// first sends a close frame and waits up to [closeTimeout] for the other
/// side's, then closes the channel's sink, which ends the connection.
/// Pings go out every [pingInterval] when one is set. A peer that does not
/// answer one before the next is due is gone, and the socket closes with
/// 1001.
final class FramedWebSocket extends RelicWebSocketBase {
  /// How long a close waits for the peer's close frame, and then for the
  /// channel to flush.
  static const closeTimeout = Duration(seconds: 2);

  /// The largest message a peer may send unless the socket is given another
  /// limit.
  ///
  /// A frame or a message over it closes the socket with 1009. The peer
  /// names the size before the bytes arrive, so without a limit it would
  /// name the allocation too.
  static const defaultMaxMessageSize = 16 << 20;

  final StreamChannel<Uint8List> _channel;
  final WebSocketMessageAssembler _assembler;
  late final StreamSubscription<WebSocketFrame> _frames;
  var _sinkClosed = false;
  Timer? _closeTimer;

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
  void sendFrame(final WebSocketOpcode opcode, final Uint8List payload) {
    if (_sinkClosed) return;
    try {
      _channel.sink.add(encodeWebSocketFrame(opcode, payload));
    } catch (_) {
      // The channel is gone. Its stream reports that.
    }
  }

  @override
  void onCloseSent() => _closeTimer = Timer(closeTimeout, _closeSink);

  /// A peer that let a ping go unanswered will not answer the close frame
  /// either, so the channel closes behind it at once rather than after
  /// [closeTimeout].
  @override
  void onPeerUnresponsive() => _closeSink();

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
        addEvent(TextDataReceived(text));
      case WebSocketBinary(:final bytes):
        addEvent(BinaryDataReceived(bytes));
      case WebSocketControl(:final frame):
        switch (frame.opcode) {
          case WebSocketOpcode.ping:
            sendFrame(WebSocketOpcode.pong, frame.payload);
          case WebSocketOpcode.pong:
            pongReceived();
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
    if (closeSent) {
      // The peer answered our close. The handshake is complete.
      _closeSink();
      return;
    }
    // The peer closes first. Echo its code, then it is over.
    markCloseSent();
    sendFrame(WebSocketOpcode.close, encodeClosePayload(code, ''));
    closeEvents(CloseReceived(code ?? 1005, reason));
    _closeSink();
  }

  /// Closes with the code [e] calls for, and the handler hears why.
  void _fail(final WebSocketProtocolException e) {
    addError(WebSocketException(e.message));
    goAway(e.code, e.message);
  }

  void _onError(final Object error, final StackTrace stackTrace) {
    if (error is WebSocketProtocolException) {
      _fail(error);
      // The decoder ended the frame stream, so the peer's answer to the
      // close frame can never be read and nothing waits for it.
      _closeSink();
      return;
    }
    addError(WebSocketException(error.toString()), stackTrace);
    _dropped();
  }

  void _onDone() => _dropped();

  /// Ends the socket after the connection dropped without a close
  /// handshake.
  void _dropped() {
    closeEvents(CloseReceived(1006, ''));
    _closeSink();
  }

  void _closeSink() {
    if (_sinkClosed) return;
    _sinkClosed = true;
    _closeTimer?.cancel();
    unawaited(_frames.cancel());
    closeEvents();
    // A peer that stopped reading never lets the close flush. Past the
    // deadline the socket is done with the channel, and the adapter drops
    // the connection at its own.
    unawaited(
      _channel.sink
          .close()
          .timeout(closeTimeout)
          .catchError((_) {})
          .whenComplete(completeDone),
    );
  }
}
