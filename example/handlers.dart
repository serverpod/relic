// ignore_for_file: prefer_final_parameters

import 'dart:async';
import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:stream_channel/stream_channel.dart';

// A handler that returns a response with a fixed string
Handler helloHandler = (final NewContext context) {
  return context.respond(Response.ok(
    body: Body.fromString('Hello from Relic!'),
  ));
};

// A simple responder that returns a response with the path of the request
Responder simpleResponder = (final Request request) {
  return Response.ok(
    body: Body.fromString('Hello, ${request.url.path}!'),
  );
};

// A handler that uses the simple responder
final responder = respondWith(simpleResponder);

// A ResponseHandler that returns a response with a custom header
ResponseHandler apiHandler = (final RespondableContext context) {
  return context.respond(
    Response.ok(
      headers: Headers.build(
        (final MutableHeaders mh) => mh.xPoweredBy = 'Relic',
      ),
      body: Body.fromString('{"status": "success"}'),
    ),
  );
};

// A HijackHandler that returns a response with a custom header
HijackHandler sseHandler = (final HijackableContext ctx) {
  return ctx.hijack((final StreamChannel<List<int>> channel) async {
    // Send Server-Sent Events
    channel.sink.add(utf8.encode('data: Connected\n\n'));

    // Send periodic updates
    final timer = Timer.periodic(const Duration(seconds: 1), (_) {
      channel.sink.add(utf8.encode('data: ${DateTime.now()}\n\n'));
    });

    // Wait for client disconnect, then cleanup
    await channel.sink.done;
    timer.cancel();
  });
};

// An asynchronous handler that simulates a delay (e.g., database or network I/O)
// and then responds with a greeting message.
Future<ResponseContext> asyncHandler(final RespondableContext ctx) async {
  final data = await Future.delayed(
    const Duration(seconds: 1),
    () => 'Hello from Relic!',
  );

  return ctx.respond(Response.ok(
    body: Body.fromString(data),
  ));
}

// A synchronous handler for simple, fast operations
ResponseContext syncHandler(final RespondableContext ctx) {
  return ctx.respond(Response.ok(
    body: Body.fromString('Fast response'),
  ));
}

// A handler that demonstrates accessing context data from the request
ResponseContext contextHandler(final NewContext ctx) {
  // Access the request
  final request = ctx.request;

  // HTTP method
  final method = request.method; // 'GET', 'POST', etc.

  // Request URL
  final url = request.url;

  // Headers
  final userAgent = request.headers.userAgent;

  return ctx.respond(Response.ok(
    body: Body.fromString(
        'Method: $method, Path: ${url.path}, User-Agent: $userAgent'),
  ));
}