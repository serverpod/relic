import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../relic_core.dart';

part 'message.dart';
part 'request.dart';
part 'response.dart';

/// A sealed base class representing the result of handling a request.
///
/// A handler returns a [Result] which is either a [Response], a [Hijack],
/// or a [WebSocketUpgrade].
sealed class Result {}

/// A [Result] indicating that the underlying connection has been
/// hijacked.
///
/// When a connection is hijacked, the handler takes full control of the
/// underlying socket connection, bypassing the normal HTTP response cycle.
/// This is useful for implementing custom protocols or handling raw socket
/// communication.
///
/// Read the request body to its end before returning a [Hijack] if the
/// client may send it chunked. An adapter cannot hand back the raw bytes of
/// a body it decoded off the wire, so it refuses the hijack. [callback] then
/// never runs, and the client gets a 500. Every adapter refuses an unread
/// chunked body, and an adapter may refuse other streamed bodies too. The
/// native adapter refuses one over its inline limit. An unread body that the
/// adapter accepts comes first on the channel's stream.
///
/// The server cannot strip a body from bytes written to the channel, so
/// a HEAD request served by a GET route gets 405 instead of the hijack.
/// Register a HEAD route to answer HEAD, and write only the response
/// head when `request.method` is HEAD.
///
/// ```dart
/// Hijack customProtocolHandler(Request req) {
///   return Hijack((channel) {
///     log('Connection hijacked for custom protocol');
///
///     // Send a custom HTTP response manually
///     const response = 'HTTP/1.1 200 OK\r\n'
///         'Content-Type: text/plain\r\n'
///         'Connection: close\r\n'
///         '\r\n'
///         'Custom protocol response from Relic!';
///
///     channel.sink.add(utf8.encode(response));
///     channel.sink.close();
///   });
/// }
/// ```
final class Hijack extends Result {
  /// The callback function provided to handle the hijacked connection.
  final HijackCallback callback;

  Hijack(this.callback);
}

/// A [Result] indicating that a duplex stream connection
/// (e.g., WebSocket) has been established.
///
/// ```dart
/// WebSocketUpgrade chatHandler(Request req) {
///   return WebSocketUpgrade((webSocket) async {
///     // The WebSocket is now active
///     webSocket.sendText('Welcome to chat!');
///
///     await for (final event in webSocket.events) {
///       if (event is TextDataReceived) {
///         // Broadcast message to all connected clients
///         broadcastMessage(event.text);
///       }
///     }
///   });
/// }
/// ```
final class WebSocketUpgrade extends Result {
  /// The callback function provided to handle the duplex stream connection.
  final WebSocketCallback callback;

  /// Whether to accept the upgrade whatever `Origin` the client sends.
  ///
  /// By default an upgrade whose `Origin` names a different host is refused
  /// with 403. Browsers do not apply CORS to WebSockets and do attach cookies
  /// to them, so accepting any origin lets any page open an authenticated
  /// socket on a visitor's session.
  ///
  /// A request with no `Origin` is always accepted: non-browser clients do not
  /// send one, and they are not subject to this attack.
  ///
  /// Set this only for an endpoint that is genuinely meant to be opened by
  /// other sites, and that does not rely on cookies to authenticate.
  final bool allowAnyOrigin;

  WebSocketUpgrade(this.callback, {this.allowAnyOrigin = false});
}
