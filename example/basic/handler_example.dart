import 'dart:async';
import 'dart:convert';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

// Foundational Handler: Request -> Response (hello world)
// doctag<handler-foundational>
Response helloHandler(final Request req) {
  return Response.ok(body: Body.fromString('Hello from Relic!'));
}
// end:doctag<handler-foundational>

// Responder example adapted to a Handler using respondWith
// doctag<handler-responder>
final Handler simpleResponderHandler = respondWith((final Request request) {
  return Response.ok(body: Body.fromString('Hello, ${request.url.path}!'));
});
// end:doctag<handler-responder>

// Response-focused handler (standard API endpoint)
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

// Hijack handler: SSE-style streaming over a hijacked connection
// doctag<handler-hijack-sse>
Hijack sseHandler(final Request req) {
  return Hijack((final channel) async {
    // Send Server-Sent Events
    channel.sink.add(utf8.encode('data: Connected'));

    // Send periodic updates
    final timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => channel.sink.add(utf8.encode('data: ${DateTime.now()}')),
    );

    // Wait for client disconnect, then cleanup
    await channel.sink.done;
    timer.cancel();
  });
}
// end:doctag<handler-hijack-sse>

// Synchronous handler example
// doctag<handler-sync>
Response syncHandler(final Request req) {
  return Response.ok(body: Body.fromString('Fast response'));
}
// end:doctag<handler-sync>

// Asynchronous handler example
// doctag<handler-async>
Future<Response> asyncHandler(final Request req) async {
  final data = await Future<String>.delayed(
    const Duration(milliseconds: 250),
    () => 'Hello from Relic!',
  );

  return Response.ok(body: Body.fromString(data));
}
// end:doctag<handler-async>

// Using context data (method, url, headers)
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

Future<void> main() async {
  final app =
      RelicApp()
        ..get('/hello', helloHandler)
        ..get('/responder', simpleResponderHandler)
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
