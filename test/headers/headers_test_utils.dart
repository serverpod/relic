import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';
import 'package:test/test.dart';

/// Thrown when the server returns a 400 status code.
class BadRequestException implements Exception {
  final String message;

  BadRequestException(this.message);
}

/// Extension methods for RelicServer
extension RelicServerTestEx on RelicServer {
  /// Fake [url] property for the [RelicServer] for testing purposes.
  ///
  /// In general a server cannot know what URL it is being accessed by before an
  /// actual request arrives, but for testing purposes we can infer a local URL
  /// based on the server's port.
  Uri get url => Uri.http('localhost:$port');
}

/// Creates a [RelicServer] that listens on the loopback IPv4 address.
Future<RelicServer> createServer() async {
  return RelicServer(
    () => IOAdapter.bind(InternetAddress.loopbackIPv4, shared: true),
    noOfIsolates: 2,
  );
}

/// Returns the headers from the server request if the server returns a 200
/// status code. Otherwise, throws an exception.
Future<Headers> getServerRequestHeaders({
  required final RelicServer server,
  required final Map<String, String> headers,
  required final void Function(Headers) touchHeaders,
}) async {
  final recv = ReceivePort();
  final sendPort = recv.sendPort;

  await server.mountAndStart(
    respondWith((final Request request) {
      sendPort.send(request.headers);
      touchHeaders(request.headers);
      return Response.ok();
    }),
  );

  final response = await http.get(server.url, headers: headers);
  final statusCode = response.statusCode;

  if (statusCode == 400) {
    throw BadRequestException(response.body);
  }

  if (statusCode != 200) {
    throw StateError(
      'Unexpected response from server: Status:${response.statusCode}: Response: ${response.body}',
    );
  }

  final requestHeaders = await recv.first as Headers;
  recv.close();
  return requestHeaders;
}

Matcher throwsInvalidHeader = throwsA(isA<InvalidHeaderException>());
Matcher throwsMissingHeader = throwsA(isA<MissingHeaderException>());
