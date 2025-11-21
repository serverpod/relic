import 'dart:io';

import '../../context/result.dart';

import 'http_response_extension.dart';

extension ResponseExIo on Response {
  /// Writes the response to an [HttpResponse].
  ///
  /// This method sets the status code, headers, and body on the [httpResponse]
  /// and returns a [Future] that completes when the body has been written.
  Future<void> writeHttpResponse(final HttpResponse httpResponse) async {
    // Set the status code.
    httpResponse.statusCode = statusCode;

    // Apply all headers to the response.
    httpResponse.applyHeaders(headers, body);

    return httpResponse
        .addStream(body.read())
        .then((_) => httpResponse.close());
  }
}
