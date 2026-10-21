import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:web_socket/web_socket.dart';

/// A `dart-io`-based [RelicWebSocket] implementation.
class IORelicWebSocket implements RelicWebSocket {
  final io.WebSocket _webSocket;
  final _events = StreamController<WebSocketEvent>();
  final _done = Completer<void>();

  /// Create a new RelicWebSocket connection using dart:io WebSocket.
  ///
  /// The URL supplied in [url] must use the scheme ws or wss.
  ///
  /// If provided, the [protocols] argument indicates that subprotocols that
  /// the peer is able to select. See
  /// [RFC-6455 1.9](https://datatracker.ietf.org/doc/html/rfc6455#section-1.9).
  static Future<IORelicWebSocket> connect(
    Uri url, {
    Iterable<String>? protocols,
  }) async {
    final io.WebSocket webSocket;
    try {
      webSocket = await io.WebSocket.connect(
        url.toString(),
        protocols: protocols,
      );
    } on io.WebSocketException catch (e) {
      throw WebSocketException(e.message);
    }

    if (webSocket.protocol != null &&
        !(protocols ?? []).contains(webSocket.protocol)) {
      // dart:io WebSocket does not correctly validate the returned protocol.
      // See https://github.com/dart-lang/sdk/issues/55106
      await webSocket.close(1002); // protocol error
      throw WebSocketException(
        'unexpected protocol selected by peer: ${webSocket.protocol}',
      );
    }
    return IORelicWebSocket._(webSocket);
  }

  static Future<IORelicWebSocket> fromHttpRequest(
    io.HttpRequest request,
  ) async => IORelicWebSocket._(await io.WebSocketTransformer.upgrade(request));

  // Create an `IORelicWebSocket` from an existing `dart:io` `WebSocket`
  // that has been correctly established using either io.WebSocket.connect, or
  // io.WebSocketTransformer.upgrade.
  IORelicWebSocket._(this._webSocket) {
    _webSocket.listen(
      (event) {
        if (_events.isClosed) return;
        switch (event) {
          case String():
            _events.add(TextDataReceived(event));
          case Uint8List():
            _events.add(BinaryDataReceived(event));
          default:
            _events.addError(UnsupportedError('$event not supported'));
        }
      },
      onError: (Object e, StackTrace st) {
        if (_events.isClosed) return;
        final wse = switch (e) {
          io.WebSocketException(message: final message) => WebSocketException(
            message,
          ),
          _ => WebSocketException(e.toString()),
        };
        _events.addError(wse, st);
      },
      onDone: () {
        _done.complete();
        if (_events.isClosed) return;
        _events
          ..add(
            CloseReceived(_webSocket.closeCode, _webSocket.closeReason ?? ''),
          )
          ..close();
      },
    );
  }

  @override
  void sendBytes(Uint8List b) => _send(b);

  @override
  void sendText(String s) => _send(s);

  void _send(dynamic stuff) {
    if (!_trySend(stuff)) throw WebSocketConnectionClosed();
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (!await tryClose(code, reason)) {
      throw WebSocketConnectionClosed();
    }
  }

  @override
  Future<bool> tryClose([int? code, String? reason]) async {
    if (isClosed) return false;

    checkCloseCode(code);
    checkCloseReason(reason);

    unawaited(_events.close());
    try {
      await _webSocket.close(code, reason);
      return true;
    } on io.WebSocketException catch (e) {
      throw WebSocketException(e.message);
    }
  }

  /// Sends a going-away close (RFC 6455 1001) and waits for the handshake.
  ///
  /// [tryClose] cannot send it. It follows `package:web_socket`'s
  /// application close-code restriction (1000 or 3000-4999), which excludes
  /// the protocol-level 1001 a shutting-down server should send.
  ///
  /// dart:io exposes no hard teardown for an upgraded socket, but bounds
  /// internally how long a peer can stall the handshake. This swallows
  /// close errors, since teardown must not throw, least of all into an
  /// unawaited future.
  @override
  Future<void> closeGoingAway() async {
    if (isClosed) return;
    unawaited(_events.close());
    try {
      await _webSocket.close(1001, 'Server shutting down');
    } catch (_) {
      // Nothing to salvage during teardown.
    }
  }

  @override
  bool trySendBytes(Uint8List b) => _trySend(b);

  @override
  bool trySendText(String s) => _trySend(s);

  bool _trySend(dynamic stuff) {
    try {
      if (isClosed) return false;
      _webSocket.add(stuff);
      return true;
    } on io.WebSocketException catch (e) {
      throw WebSocketException(e.message);
    }
  }

  @override
  Stream<WebSocketEvent> get events => _events.stream;

  @override
  String get protocol => _webSocket.protocol ?? '';

  @override
  Duration? get pingInterval => _webSocket.pingInterval;

  @override
  set pingInterval(Duration? value) => _webSocket.pingInterval = value;

  @override
  bool get isClosed => _events.isClosed;

  @override
  Future<void> get done => _done.future;
}
