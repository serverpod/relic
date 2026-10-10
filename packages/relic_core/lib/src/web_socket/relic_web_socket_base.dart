import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:web_socket/web_socket.dart';

import '../adapter/relic_web_socket.dart';
import 'web_socket_frame.dart';

/// What every [RelicWebSocket] over a framing transport shares: the events
/// the handler reads, the send and close guards, the going-away close and
/// the ping timer.
///
/// A transport provides [sendFrame] and reports what it received through
/// [addEvent], [pongReceived], [closeEvents] and [completeDone].
abstract base class RelicWebSocketBase implements RelicWebSocket {
  final _events = StreamController<WebSocketEvent>();
  final _done = Completer<void>();
  Timer? _pingTimer;
  Duration? _pingInterval;
  var _closeSent = false;
  var _pongPending = false;

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
      if (!pingAnswered()) {
        goAway(1001, '');
        onPeerUnresponsive();
        return;
      }
      _pongPending = true;
      onPing();
      sendFrame(WebSocketOpcode.ping, Uint8List(0));
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
    sendFrame(WebSocketOpcode.binary, b);
    return true;
  }

  @override
  bool trySendText(final String s) {
    if (isClosed) return false;
    sendFrame(WebSocketOpcode.text, utf8.encode(s));
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
    closeEvents();
    sendClose(code, reason ?? '');
    return true;
  }

  @override
  Future<void> closeGoingAway() {
    if (!isClosed) {
      closeEvents();
      sendClose(1001, 'Server shutting down');
    }
    return _done.future;
  }

  /// Sends one frame to the peer.
  ///
  /// Does nothing on a transport that is gone.
  @protected
  void sendFrame(final WebSocketOpcode opcode, final Uint8List payload);

  /// Called once a close frame of this side's went out.
  @protected
  void onCloseSent() {}

  /// Called when a ping goes out.
  @protected
  void onPing() {}

  /// Whether the peer answered the last ping, asked when the next is due.
  ///
  /// The default is what [pongReceived] saw. A transport that counts pongs
  /// elsewhere overrides it.
  @protected
  bool pingAnswered() => !_pongPending;

  /// Called after the socket closed with 1001 on a peer that let a ping
  /// go unanswered, which will not answer the close frame either.
  @protected
  void onPeerUnresponsive() {}

  /// Whether a close frame of this side's is on its way or went out.
  @protected
  bool get closeSent => _closeSent;

  /// Records a close the transport sent on this side's behalf, such as
  /// the echo of the peer's close frame.
  @protected
  void markCloseSent() {
    _closeSent = true;
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Records that the peer answered a ping.
  @protected
  void pongReceived() => _pongPending = false;

  /// Closes from this side with [code], and the handler sees that close.
  @protected
  void goAway(final int code, final String reason) {
    closeEvents(CloseReceived(code, reason));
    sendClose(code, reason);
  }

  /// Sends a close frame once.
  ///
  /// Later calls do nothing.
  @protected
  void sendClose(final int? code, final String reason) {
    if (_closeSent) return;
    markCloseSent();
    sendFrame(WebSocketOpcode.close, encodeClosePayload(code, reason));
    onCloseSent();
  }

  /// Hands the handler an event, unless its events ended.
  @protected
  void addEvent(final WebSocketEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  /// Hands the handler an error, unless its events ended.
  @protected
  void addError(final Object error, [final StackTrace? stackTrace]) {
    if (!_events.isClosed) _events.addError(error, stackTrace);
  }

  /// Ends the handler's events, after [close] when it should hear how the
  /// connection closed.
  ///
  /// Does nothing on events that already ended.
  @protected
  void closeEvents([final CloseReceived? close]) {
    if (_events.isClosed) return;
    if (close != null) _events.add(close);
    unawaited(_events.close());
  }

  /// Completes [done] and stops the ping timer, once the connection is over.
  @protected
  void completeDone() {
    _pingTimer?.cancel();
    _pingTimer = null;
    if (!_done.isCompleted) _done.complete();
  }
}
