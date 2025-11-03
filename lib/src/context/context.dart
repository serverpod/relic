import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../relic.dart';

part 'message.dart';
part 'request.dart';
part 'response.dart';

/// A sealed base class for representing the state of a request as it's
/// processed.
///
/// [Context] holds the original [Request] and a unique [token]
/// that remains constant throughout the request's lifecycle, even as the
/// context itself might transition between different states.
///
/// ## State Transitions
///
///                            ┌──────────────────┐
///                            │ [RequestContext] │ (initial state)
///                            └─────────┬────────┘
///                                      │
///               ┌──────────────────────┼───────────────────────┐
///               │                      │                       │
///          .respond()              .hijack()               .connect()
///               │                      │                       │
///               ▼                      ▼                       ▼
///     ┌───────────────────┐  ┌───────────────────┐  ┌─────────────────────┐
///  ┌─►│ [ResponseContext] │  │ [HijackedContext] │  │ [ConnectionContext] │
///  │  └─────────┬─────────┘  └───────────────────┘  └─────────────────────┘
///  └────────────┘
///   .respond() // update response
///
/// - [RequestContext]: Initial state, can transition to any handled state
/// - [ResponseContext]: A response has been generated (can be updated via `respond()`)
/// - [HijackedContext]: Connection hijacked for low-level I/O (WebSockets, etc.)
/// - [ConnectionContext]: Duplex stream connection established
sealed class Context {
  /// The original request associated with this context.
  Request get request;

  /// A unique token representing the request throughout its lifetime.
  ///
  /// While the [Context] might change (e.g., from [RequestContext] to
  /// [ResponseContext]), this [token] remains constant. This is useful for
  /// associating request-specific state, for example, with [Expando] objects
  /// in middleware.
  Object get token;
}

/// An interface for request contexts that can be transitioned to a state
/// where a response has been provided.
abstract interface class RespondableContext implements Context {
  /// Transitions the context to a state where a response has been associated.
  ///
  /// Takes a [response] and returns a [ResponseContext].
  ResponseContext respond(final Response response);
}

abstract interface class ConnectableContext implements Context {
  /// Transitions this context to a state where a duplex stream (e.g., WebSocket)
  /// connection is established.
  ///
  /// The provided [WebSocketCallback] will be invoked with a
  /// [RelicWebSocket] for managing the bi-directional communication.
  /// Returns a [ConnectionContext].
  ConnectionContext connect(final WebSocketCallback callback) =>
      ConnectionContext._(request, callback);
}

/// An interface for request contexts that allow hijacking the underlying connection.
abstract interface class HijackableContext implements Context {
  /// Takes control of the underlying communication channel (e.g., socket).
  ///
  /// The provided [callback] will be invoked with a [StreamChannel]
  /// allowing direct interaction with the connection. Returns a [HijackedContext].
  HijackedContext hijack(final HijackCallback callback);
}

/// Represents the initial state of a request context before it has been
/// handled (i.e., before a response is generated or the connection is hijacked).
///
/// This context can transition to either a [ResponseContext] via [respond],
/// a [HijackedContext] via [hijack], or a [ConnectionContext] via [connect].
///
/// Every handler receives a [RequestContext] as its starting point:
///
/// ```dart
/// // Simple HTTP handler
/// Future<ResponseContext> apiHandler(RequestContext ctx) async {
///   return ctx.respond(Response.ok(
///     body: Body.fromString('Hello from Relic!'),
///   ));
/// }
///
/// // WebSocket handler
/// ConnectionContext wsHandler(RequestContext ctx) {
///   return ctx.connect((webSocket) async {
///     webSocket.sendText('Welcome!');
///     await for (final event in webSocket.events) {
///       // Handle WebSocket events
///     }
///   });
/// }
/// ```
sealed class RequestContext
    implements RespondableContext, HijackableContext, ConnectableContext {
  /// Creates a new [Context] with a different [Request].
  RequestContext withRequest(final Request req);
}

/// A sealed base class for contexts that represent a handled request.
///
/// A request is considered handled if a response has been formulated
/// ([ResponseContext]), the connection has been hijacked ([HijackedContext]),
/// or a duplex stream connection has been established ([ConnectionContext]).
sealed class HandledContext implements Context {}

/// A [Context] state indicating that a [Response] has been generated.
sealed class ResponseContext implements HandledContext, RespondableContext {
  /// The response associated with this context.
  Response get response;
}

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
final class HijackedContext extends HandledContext {
  /// The callback function provided to handle the hijacked connection.
  final HijackCallback callback;

  @override
  final Request request;

  @override
  Object get token => request;

  HijackedContext._(this.request, this.callback);
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
final class ConnectionContext extends HandledContext {
  /// The callback function provided to handle the duplex stream connection.
  final WebSocketCallback callback;

  @override
  final Request request;

  @override
  Object get token => request;

  ConnectionContext._(this.request, this.callback);
}

/// Internal extension methods for [Request].
@visibleForTesting
extension RequestInternal on Request {
  /// Creates a new [RequestContext] from this [Request].
  ///
  /// This is the initial context state for an incoming request, using the
  /// provided [token] to uniquely identify the request throughout its lifecycle.
  RequestContext toContext(final Object token) => this;
}
