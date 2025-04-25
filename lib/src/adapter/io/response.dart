import 'dart:io';

import '../../message/response.dart';

import 'http_response_extension.dart';

extension ResponseExIo on Response {
  /// Writes the response to an [HttpResponse].
  ///
  /// This method sets the status code, headers, and body on the [httpResponse]
  /// and returns a [Future] that completes when the body has been written.
  Future<void> writeHttpResponse(
    final HttpResponse httpResponse,
  ) async {
    if (context.containsKey('relic_server.buffer_output')) {
      httpResponse.bufferOutput = context['relic_server.buffer_output'] as bool;
    }

    // Set the status code.
    httpResponse.statusCode = statusCode;

    // Apply all headers to the response.
    httpResponse.applyHeaders(headers, body);

    return httpResponse
        .addStream(body.read())
        .then((final _) => httpResponse.close());
  }
}
