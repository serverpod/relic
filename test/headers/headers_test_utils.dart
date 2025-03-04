import 'dart:async';
import 'dart:io';

import 'package:relic/relic.dart';
import 'package:http/http.dart' as http;

/// Thrown when the server returns a 400 status code.
class BadRequestException implements Exception {
  final String message;

  BadRequestException(
    this.message,
  );
}

/// Creates a [RelicServer] that listens on the loopback IPv6 address.
/// If the IPv6 address is not available, it will listen on the loopback IPv4
/// address.
Future<RelicServer> createServer({
  required bool strictHeaders,
}) async {
  try {
    return RelicServer.createServer(
      InternetAddress.loopbackIPv6,
      0,
      strictHeaders: strictHeaders,
    );
  } on SocketException catch (_) {
    return RelicServer.createServer(
      InternetAddress.loopbackIPv4,
      0,
      strictHeaders: strictHeaders,
    );
  }
}

/// Returns the headers from the server request if the server returns a 200
/// status code. Otherwise, throws an exception.
Future<Headers> getServerRequestHeaders({
  required RelicServer server,
  required Map<String, String> headers,
  // Whether to parse all headers.
  bool parseAllHeaders = true,
}) async {
  Headers? parsedHeaders;

  server.mountAndStart(
    (Request request) {
      parsedHeaders = request.headers;

      if (parseAllHeaders) {
        parsedHeaders?.toMap();
      }

      return Response.ok();
    },
  );

  final response = await http.get(server.url, headers: headers);

  var statusCode = response.statusCode;

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

  if (parsedHeaders == null) {
    throw StateError(
      'No headers were parsed from the request',
    );
  }

  return parsedHeaders!;
}
