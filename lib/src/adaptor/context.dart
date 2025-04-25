import '../../relic.dart';
import '../message/request.dart';

abstract interface class _RequestContextInterface {
  /// The original incoming request associated with this context.
  Request get request;
}

sealed class RequestContext implements _RequestContextInterface {
  /// The original incoming request associated with this context.
  @override
  final Request request;
  RequestContext._(this.request);
}

abstract interface class RespondableContext
    implements _RequestContextInterface {
  /// Transitions the context to a state where a response has been associated.
  ///
  /// Takes a [Response] object [r] and returns a [ResponseContext].
  ResponseContext withResponse(final Response r);
}

abstract interface class HijackableContext implements _RequestContextInterface {
  /// Takes control of the underlying socket.
  ///
  /// [callback] is called with a [StreamChannel<List<int>>] that provides
  /// access to the underlying socket.
  /// Takes control of the underlying communication channel (e.g., socket).
  ///
  /// The provided [callback] [c] will be invoked with a [StreamChannel]
  /// allowing direct interaction with the connection. Returns a [HijackContext].
  HijackContext hijack(final HijackCallback c);
}

/// Represents the initial state of a request context before it has been
/// handled (i.e., before a response is generated or the connection is hijacked).
///
/// This context can transition to either a [ResponseContext] via [withResponse]
/// or a [HijackContext] via [hijack].
final class NewContext extends RequestContext
    implements RespondableContext, HijackableContext {
  NewContext._(super.request) : super._();

  @override
  HijackContext hijack(final HijackCallback c) => HijackContext._(request, c);

  @override
  ResponseContext withResponse(final Response r) =>
      ResponseContext._(request, r);
}

/// Marker interface for contexts that represent a handled request,
/// either by providing a response ([ResponseContext]) or by hijacking
/// the connection ([HijackContext]).
abstract class HandledContext implements _RequestContextInterface {}

final class ResponseContext extends RequestContext
    implements RespondableContext, HandledContext {
  /// The response associated with this context.
  final Response response;
  ResponseContext._(super.request, this.response) : super._();

  @override
  ResponseContext withResponse(final Response r) =>
      ResponseContext._(request, r);
}

final class HijackContext extends RequestContext implements HandledContext {
  /// The callback function provided to handle the hijacked connection.
  final HijackCallback callback;
  HijackContext._(super.request, this.callback) : super._();
}

extension RequestInternal on Request {
  /// Creates a new [NewContext] from this [Request].
  NewContext toContext() => NewContext._(this);
}
