import 'dart:io';

import 'package:relic_core/relic_core.dart';

import 'http_response_extension.dart';

extension ResponseExIo on Response {
  /// Writes the response to an [HttpResponse].
  ///
  /// This method sets the status code, headers, and body on the [httpResponse]
  /// and returns a [Future] that completes when the body has been written.
  Future<void> writeHttpResponse(HttpResponse httpResponse) async {
    // Set the status code.
    httpResponse.statusCode = statusCode;

    // Apply all headers to the response.
    httpResponse.applyHeaders(headers, body);

    // Date is the server's job, not the handler's (RFC 9110 6.6.1).
    if (!headers.contains(HeaderName.date)) {
      httpResponse.headers.date = DateTime.now();
    }

    // Close connection if requested. A bit weird this is not handled by dart:io
    httpResponse.persistentConnection = !(headers.connection?.isClose ?? false);

    final bytes = body.bytes;
    if (bytes != null) {
      body.read(); // a body is read once, buffered or not
      httpResponse.add(bytes);
    } else {
      await httpResponse.addStream(body.read());
    }
    await httpResponse.flush();

    await httpResponse.close();
  }
}
