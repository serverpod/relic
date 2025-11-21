import 'dart:async';
import 'dart:convert';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

// Basic handler that returns a simple greeting.
// doctag<handler-foundational>
Response helloHandler(final Request req) {
  return Response.ok(body: Body.fromString('Hello from Relic!'));
}
// end:doctag<handler-foundational>

// Handler that demonstrates custom headers and JSON response.
// doctag<handler-response>
Response apiResponseHandler(final Request req) {
  return Response.ok(
    headers: Headers.build(
      (final MutableHeaders mh) => mh.xPoweredBy = 'Relic',
    ),
    body: Body.fromString('{"status": "success"}'),
  );
}
// end:doctag<handler-response>

// Handler that hijacks the connection for Server-Sent Events (SSE) streaming.
// doctag<handler-hijack-sse>
Hijack sseHandler(final Request req) {
  return Hijack((final channel) async {
    // Send Server-Sent Events.
    channel.sink.add(utf8.encode('data: Connected'));

    // Send periodic updates.
    final timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => channel.sink.add(utf8.encode('data: ${DateTime.now()}')),
    );

    // Wait for client disconnect, then cleanup.
    await channel.sink.done;
    timer.cancel();
  });
}
// end:doctag<handler-hijack-sse>

// Simple synchronous handler that returns immediately.
// doctag<handler-sync>
Response syncHandler(final Request req) {
  return Response.ok(body: Body.fromString('Fast response'));
}
// end:doctag<handler-sync>

// Asynchronous handler that simulates delayed processing.
// doctag<handler-async>
Future<Response> asyncHandler(final Request req) async {
  final data = await Future<String>.delayed(
    const Duration(milliseconds: 250),
    () => 'Hello from Relic!',
  );

  return Response.ok(body: Body.fromString(data));
}
// end:doctag<handler-async>

// Handler that demonstrates accessing request context information.
// doctag<handler-context>
Response contextInfoHandler(final Request req) {
  final method = req.method;
  final url = req.url;
  final userAgent = req.headers.userAgent;

  return Response.ok(
    body: Body.fromString(
      'Method: ${method.name}, Path: ${url.path} User-Agent: ${userAgent ?? 'unknown'}',
    ),
  );
}
// end:doctag<handler-context>

/// Demonstrates different types of request handlers in Relic.
Future<void> main() async {
  final app =
      RelicApp()
        ..get('/hello', helloHandler)
        ..get('/api', apiResponseHandler)
        ..get('/sse', sseHandler)
        ..get('/sync', syncHandler)
        ..get('/async', asyncHandler)
        ..get('/context', contextInfoHandler)
        ..fallback = respondWith(
          (final req) => Response.notFound(body: Body.fromString('Not Found')),
        );

  await app.serve();
}
