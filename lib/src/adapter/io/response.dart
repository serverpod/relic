import 'dart:io';

import '../../context/result.dart';

import '../../headers/standard_headers_extensions.dart';
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

    // Close connection if requested. A bit weird this is not handled by dart:io
    httpResponse.persistentConnection = !(headers.connection?.isClose ?? false);

    await httpResponse.addStream(body.read());
    await httpResponse.flush();

    await httpResponse.close();
  }
}
