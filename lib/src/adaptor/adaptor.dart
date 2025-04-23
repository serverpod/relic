import 'dart:async';

import '../message/request.dart';
import '../message/response.dart';

abstract class AdaptorRequest {
  Request toRequest();
}

abstract class Adaptor {
  Stream<AdaptorRequest> get requests;
  Future<void> respond(final AdaptorRequest request, final Response response);
  Future<void> hijack(
      final AdaptorRequest request, final HijackCallback callback);

  /// Gracefully close this [Adaptor].
  Future<void> close();
}
