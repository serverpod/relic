import '../../relic.dart';
import '../message/request.dart';

abstract interface class _RequestContextInterface {
  Request get request;
}

sealed class RequestContext implements _RequestContextInterface {
  @override
  final Request request;
  RequestContext._(this.request);
}

abstract interface class RespondableContext
    implements _RequestContextInterface {
  ResponseContext withResponse(final Response r);
}

abstract interface class HijackableContext implements _RequestContextInterface {
  /// Takes control of the underlying socket.
  ///
  /// [callback] is called with a [StreamChannel<List<int>>] that provides
  /// access to the underlying socket.
  HijackContext hijack(final HijackCallback c);
}

final class NewContext extends RequestContext
    implements RespondableContext, HijackableContext {
  NewContext._(super.request) : super._();

  @override
  HijackContext hijack(final HijackCallback c) => HijackContext._(request, c);

  @override
  ResponseContext withResponse(final Response r) =>
      ResponseContext._(request, r);
}

abstract class HandledContext implements _RequestContextInterface {}

final class ResponseContext extends RequestContext
    implements RespondableContext, HandledContext {
  final Response response;
  ResponseContext._(super.request, this.response) : super._();

  @override
  ResponseContext withResponse(final Response r) =>
      ResponseContext._(request, r);
}

final class HijackContext extends RequestContext implements HandledContext {
  final HijackCallback callback;
  HijackContext._(super.request, this.callback) : super._();
}

extension RequestInternal on Request {
  NewContext toContext() => NewContext._(this);
}
