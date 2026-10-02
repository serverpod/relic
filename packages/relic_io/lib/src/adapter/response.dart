import 'dart:io';

import 'package:relic_core/relic_core.dart';

import 'http_response_extension.dart';

extension ResponseExIo on Response {
  /// Writes the response to an [HttpResponse].
  ///
  /// This method sets the status code, headers, and body on the [httpResponse]
  /// and returns a [Future] that completes when the body has been written.
  Future<void> writeHttpResponse(
    HttpResponse httpResponse, {
    required bool head,
    required HttpProtocol protocol,
    required bool keepAlive,
  }) async {
    final framing = ResponseFraming.of(
      this,
      head: head,
      protocol: protocol,
      keepAlive: keepAlive,
    );
    httpResponse.statusCode = statusCode;
    httpResponse.applyFraming(headers, framing);
    httpResponse.persistentConnection = !framing.closeAfter;

    final bytes = body.bytes;
    if (!framing.sendBody) {
      body.consume(); // a body is read once, sent or not
    } else if (bytes != null) {
      body.consume();
      httpResponse.add(bytes);
    } else {
      await httpResponse.addStream(body.read());
    }
    await httpResponse.flush();

    await httpResponse.close();
  }
}
