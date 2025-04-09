import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relic/relic.dart';
import 'package:test/test.dart';

/// Thrown when the server returns a 400 status code.
class BadRequestException implements Exception {
  final String message;

  BadRequestException(
    this.message,
  );
}

extension RelicServerTestEx on RelicServer {
  static final Expando<Uri> _serverUrls = Expando();

  /// Fake [url] property for the [RelicServer] for testing purposes.
  Uri get url => _serverUrls[this] ??= _inferUrl();
  set url(final Uri value) => _serverUrls[this] = value;

  /// Infer a probable URL for the server.
  ///
  /// In general a server cannot know what URL it is being accessed by before an
  /// actual request arrives, but for testing purposes we can infer a URL based
  /// on the server's address.
  Uri _inferUrl() {
    if (server.address.isLoopback) {
      return Uri(scheme: 'http', host: 'localhost', port: server.port);
    }

    if (server.address.type == InternetAddressType.IPv6) {
      return Uri(
        scheme: 'http',
        host: '[${server.address.address}]',
        port: server.port,
      );
    }

    return Uri(
      scheme: 'http',
      host: server.address.address,
      port: server.port,
    );
  }
}

/// Creates a [RelicServer] that listens on the loopback IPv6 address.
/// If the IPv6 address is not available, it will listen on the loopback IPv4
/// address.
Future<RelicServer> createServer({
  required final bool strictHeaders,
}) async {
  try {
    return await RelicServer.createServer(
      InternetAddress.loopbackIPv6,
      0,
      strictHeaders: strictHeaders,
    );
  } on SocketException catch (_) {
    return await RelicServer.createServer(
      InternetAddress.loopbackIPv4,
      0,
      strictHeaders: strictHeaders,
    );
  }
}

/// Returns the headers from the server request if the server returns a 200
/// status code. Otherwise, throws an exception.
Future<Headers> getServerRequestHeaders({
  required final RelicServer server,
  required final Map<String, String> headers,
  required final void Function(Headers) touchHeaders,
}) async {
  var requestHeaders = Headers.empty();

  server.mountAndStart(
    (final Request request) {
      requestHeaders = request.headers;
      touchHeaders(requestHeaders);
      return Response.ok();
    },
  );

  final response = await http.get(server.url, headers: headers);

  final statusCode = response.statusCode;

  if (statusCode == 400) {
    throw BadRequestException(
      response.body,
    );
  }

  if (statusCode != 200) {
    throw StateError(
      'Unexpected response from server: Status:${response.statusCode}: Response: ${response.body}',
    );
  }

  return requestHeaders;
}

Matcher throwsInvalidHeader = throwsA(isA<InvalidHeaderException>());
Matcher throwsMissingHeader = throwsA(isA<MissingHeaderException>());
