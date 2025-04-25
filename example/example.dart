import 'dart:io';

import 'package:relic/relic.dart';

Future<void> main() async {
  /// Setup a handler.
  ///
  /// A [Handler] is function consuming and producing [RequestContext]s,
  /// but if you are mostly concerned with converting [Request]s to [Response]s
  /// (known as a [Responder] in relic parlor) you can use [] to
  /// wrap a [Responder] into a [Handler]
  final handler = respondWith(hello);

  /// Start the server with the handler
  ///
  /// [serve] is just short-hand for
  /// ```dart
  /// RelicServer(IOAdator(HttpServer.bind(InternetAddress.anyIPv4, 8080)))
  /// ```
  await serve(handler, InternetAddress.anyIPv4, 8080);

  /// Check the _example_ directory for other examples.
}

/// A very simple [Handler].
Response hello(final Request request) =>
    Response.ok(body: Body.fromString('Hello World'));
