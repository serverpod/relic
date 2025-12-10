import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:web_socket/web_socket.dart';
import 'package:relic_core/relic_core.dart';

/// A `dart-io`-based [RelicWebSocket] implementation.
class IORelicWebSocket implements RelicWebSocket {
  final io.WebSocket _webSocket;
  final _events = StreamController<WebSocketEvent>();

  /// Create a new RelicWebSocket connection using dart:io WebSocket.
  ///
  /// The URL supplied in [url] must use the scheme ws or wss.
  ///
  /// If provided, the [protocols] argument indicates that subprotocols that
  /// the peer is able to select. See
  /// [RFC-6455 1.9](https://datatracker.ietf.org/doc/html/rfc6455#section-1.9).
  static Future<IORelicWebSocket> connect(
    final Uri url, {
    final Iterable<String>? protocols,
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
    final io.HttpRequest request,
  ) async => IORelicWebSocket._(await io.WebSocketTransformer.upgrade(request));

  // Create an `IORelicWebSocket` from an existing `dart:io` `WebSocket`
  // that has been correctly established using either io.WebSocket.connect, or
  // io.WebSocketTransformer.upgrade.
  IORelicWebSocket._(this._webSocket) {
    _webSocket.listen(
      (final event) {
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
      onError: (final Object e, final StackTrace st) {
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
  void sendBytes(final Uint8List b) => _send(b);

  @override
  void sendText(final String s) => _send(s);

  void _send(final dynamic stuff) {
    if (!_trySend(stuff)) throw WebSocketConnectionClosed();
  }

  @override
  Future<void> close([final int? code, final String? reason]) async {
    if (!await tryClose(code, reason)) {
      throw WebSocketConnectionClosed();
    }
  }

  @override
  Future<bool> tryClose([final int? code, final String? reason]) async {
    if (isClosed) return false;

    _checkCloseCode(code);
    _checkCloseReason(reason);

    unawaited(_events.close());
    try {
      await _webSocket.close(code, reason);
      return true;
    } on io.WebSocketException catch (e) {
      throw WebSocketException(e.message);
    }
  }

  @override
  bool trySendBytes(final Uint8List b) => _trySend(b);

  @override
  bool trySendText(final String s) => _trySend(s);

  bool _trySend(final dynamic stuff) {
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
  set pingInterval(final Duration? value) => _webSocket.pingInterval = value;

  @override
  bool get isClosed => _events.isClosed;
}

/// Throw if the given close code is not valid.
void _checkCloseCode(final int? code) {
  if (code != null && code != 1000 && !(code >= 3000 && code <= 4999)) {
    throw ArgumentError(
      'Invalid argument: $code, close code must be 1000 or '
      'in the range 3000-4999',
    );
  }
}

/// Throw if the given close reason is not valid.
void _checkCloseReason(final String? reason) {
  if (reason != null && utf8.encode(reason).length > 123) {
    throw ArgumentError.value(
      reason,
      'reason',
      'reason must be <= 123 bytes long when encoded as UTF-8',
    );
  }
}
