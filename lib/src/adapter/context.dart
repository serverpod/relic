import '../../relic.dart';

/// An internal interface defining the base contract for request contexts.
///
/// It ensures that any request context provides access to the original
/// [Request].
abstract interface class _RequestContextInterface {
  /// The original incoming request associated with this context.
  Request get request;
}

/// A sealed base class for representing the state of a request as it's
/// processed.
///
/// [RequestContext] holds the original [Request] and a unique [token]
/// that remains constant throughout the request's lifecycle, even as the
/// context itself might transition between different states (e.g., from
/// [NewContext] to [ResponseContext]).
sealed class RequestContext implements _RequestContextInterface {
  /// The request associated with this context.
  @override
  final Request request;

  /// A unique token representing the request throughout its lifetime.
  ///
  /// While the [RequestContext] might change (e.g., from [NewContext] to
  /// [ResponseContext]), this [token] remains constant. This is useful for
  /// associating request-specific state, for example, with [Expando] objects
  /// in middleware.
  final Object token;
  RequestContext._(this.request, this.token);
}

/// An interface for request contexts that can be transitioned to a state
/// where a response has been provided.
abstract interface class RespondableContext
    implements _RequestContextInterface {
  /// Transitions the context to a state where a response has been associated.
  ///
  /// Takes a [Response] object [r] and returns a [ResponseContext].
  ResponseContext respond(final Response r);
}

/// An interface for request contexts that allow hijacking the underlying connection.
abstract interface class HijackableContext implements _RequestContextInterface {
  /// Takes control of the underlying communication channel (e.g., socket).
  ///
  /// The provided [callback] [c] will be invoked with a [StreamChannel]
  /// allowing direct interaction with the connection. Returns a [HijackContext].
  HijackContext hijack(final HijackCallback c);
}

/// Represents the initial state of a request context before it has been
/// handled (i.e., before a response is generated or the connection is hijacked).
///
/// This context can transition to either a [ResponseContext] via [respond],
/// a [HijackContext] via [hijack], or a [ConnectContext] via [connect].
final class NewContext extends RequestContext
    implements RespondableContext, HijackableContext {
  NewContext._(super.request, super.token) : super._();

  @override
  HijackContext hijack(final HijackCallback c) =>
      HijackContext._(request, token, c);

  /// Transitions this context to a state where a duplex stream (e.g., WebSocket)
  /// connection is established.
  ///
  /// The provided [DuplexStreamCallback] [c] will be invoked with a
  /// [RelicWebSocket] for managing the bi-directional communication.
  /// Returns a [ConnectContext].
  ConnectContext connect(final WebSocketCallback c) =>
      ConnectContext._(request, token, c);

  @override
  ResponseContext respond(final Response r) =>
      ResponseContext._(request, token, r);

  /// Creates a new [NewContext] with a different [Request] while preserving
  /// the same [token].
  ///
  /// This is a convenience method for middleware that needs to rewrite a
  /// request before passing it to the inner handler. Instead of the low-level
  /// pattern:
  /// ```dart
  /// final rewrittenRequest = req.copyWith(requestedUri: newRequested);
  /// return await inner(rewrittenRequest.toContext(ctx.token));
  /// ```
  ///
  /// You can use the more readable pattern:
  /// ```dart
  /// final rewrittenRequest = req.copyWith(requestedUri: newRequested);
  /// return await inner(ctx.withRequest(rewrittenRequest));
  /// ```
  NewContext withRequest(final Request req) => NewContext._(req, token);
}

/// A sealed base class for contexts that represent a handled request.
///
/// A request is considered handled if a response has been formulated
/// ([ResponseContext]), the connection has been hijacked ([HijackContext]),
/// or a duplex stream connection has been established ([ConnectContext]).
sealed class HandledContext extends RequestContext {
  HandledContext._(super.request, super.token) : super._();
}

/// A [RequestContext] state indicating that a [Response] has been generated.
final class ResponseContext extends HandledContext
    implements RespondableContext {
  /// The response associated with this context.
  final Response response;
  ResponseContext._(super.request, super.token, this.response) : super._();

  @override
  ResponseContext respond(final Response r) =>
      ResponseContext._(request, token, r);
}

/// A [RequestContext] state indicating that the underlying connection has been
/// hijacked.
final class HijackContext extends HandledContext {
  /// The callback function provided to handle the hijacked connection.
  final HijackCallback callback;
  HijackContext._(super.request, super.token, this.callback) : super._();
}

/// A [RequestContext] state indicating that a duplex stream connection
/// (e.g., WebSocket) has been established.
final class ConnectContext extends HandledContext {
  /// The callback function provided to handle the duplex stream connection.
  final WebSocketCallback callback;
  ConnectContext._(super.request, super.token, this.callback) : super._();
}

/// Internal extension methods for [Request].
extension RequestInternal on Request {
  /// Creates a new [NewContext] from this [Request].
  ///
  /// This is the initial context state for an incoming request, using the
  /// provided [token] to uniquely identify the request throughout its lifecycle.
  NewContext toContext(final Object token) => NewContext._(this, token);
}
