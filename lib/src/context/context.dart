import 'dart:convert';
import 'dart:typed_data';

import '../../relic.dart';

part 'message.dart';
part 'request.dart';
part 'response.dart';

/// A sealed base class for contexts that represent a handled request.
///
/// A request is considered handled if a response has been formulated
/// ([Response]), the connection has been hijacked ([HijackedContext]),
/// or a duplex stream connection has been established ([ConnectionContext]).
sealed class Result {}

/// A [Context] state indicating that the underlying connection has been
/// hijacked.
///
/// When a connection is hijacked, the handler takes full control of the
/// underlying socket connection, bypassing the normal HTTP response cycle.
/// This is useful for implementing custom protocols or handling raw socket
/// communication.
///
/// ```dart
/// HijackedContext customProtocolHandler(RequestContext ctx) {
///   return ctx.hijack((channel) {
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
final class HijackedContext extends Result {
  /// The callback function provided to handle the hijacked connection.
  final HijackCallback callback;

  HijackedContext(this.callback);
}

/// A [Context] state indicating that a duplex stream connection
/// (e.g., WebSocket) has been established.
///
/// ```dart
/// ConnectionContext chatHandler(RequestContext ctx) {
///   return ctx.connect((webSocket) async {
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
final class ConnectionContext extends Result {
  /// The callback function provided to handle the duplex stream connection.
  final WebSocketCallback callback;

  ConnectionContext(this.callback);
}
