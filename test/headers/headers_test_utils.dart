import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:relic/relic.dart';
import 'package:relic/src/adaptor/io/bind_http_server.dart';
import 'package:relic/src/adaptor/io/io_adaptor.dart';
import 'package:test/test.dart';

/// Thrown when the server returns a 400 status code.
class BadRequestException implements Exception {
  final String message;

  BadRequestException(
    this.message,
  );
}

/// Extension methods for RelicServer
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
    if (adaptor.address.isLoopback) {
      return Uri(scheme: 'http', host: 'localhost', port: adaptor.port);
    }

    if (adaptor.address.isIpV6) {
      return Uri(
        scheme: 'http',
        host: '[${adaptor.address.address}]',
        port: adaptor.port,
      );
    }

    return Uri(
      scheme: 'http',
      host: adaptor.address.address,
      port: adaptor.port,
    );
  }
}

/// Creates a [RelicServer] that listens on the loopback IPv6 address.
/// If the IPv6 address is not available, it will listen on the loopback IPv4
/// address.
Future<RelicServer> createServer({
  required final bool strictHeaders,
}) async {
  for (final address in [
    InternetAddress.loopbackIPv6,
    InternetAddress.loopbackIPv4
  ]) {
    try {
      final adaptor = IOAdaptor(await bindHttpServer(address));
      return RelicServer(adaptor, strictHeaders: strictHeaders);
    } on SocketException catch (_) {
      continue;
    }
  }
  throw ArgumentError('Failed to load');
}

/// Returns the headers from the server request if the server returns a 200
/// status code. Otherwise, throws an exception.
Future<Headers> getServerRequestHeaders({
  required final RelicServer server,
  required final Map<String, String> headers,
  required final void Function(Headers) touchHeaders,
}) async {
  var requestHeaders = Headers.empty();

  await server.mountAndStart(
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
