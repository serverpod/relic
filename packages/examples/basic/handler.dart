import 'dart:async';
import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:web_socket/web_socket.dart';

// Basic handler that returns a simple greeting.
// doctag<handler-foundational>
Response myHelloWorldHandler(Request req) {
  return Response.ok(body: Body.fromString('Hello from Relic!'));
}
// end:doctag<handler-foundational>

// Handler that hijacks the connection for Server-Sent Events (SSE) streaming.
// doctag<handler-hijack-sse>
Hijack mySseHandler(Request req) {
  return Hijack((channel) async {
    channel.sink.add(
      utf8.encode(
        'HTTP/1.1 200 OK\r\n'
        'Content-Type: text/event-stream\r\n'
        'Cache-Control: no-cache\r\n'
        'Connection: close\r\n'
        '\r\n',
      ),
    );
    // The HEAD route below lands here too, and gets the head alone.
    if (req.method == Method.head) {
      await channel.sink.close();
      return;
    }

    // Send Server-Sent Events, each ended by a blank line.
    channel.sink.add(utf8.encode('data: Connected\n\n'));

    // Send periodic updates.
    final timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => channel.sink.add(utf8.encode('data: ${DateTime.now()}\n\n')),
    );

    // Wait for client disconnect, then cleanup.
    await channel.sink.done;
    timer.cancel();
  });
}
// end:doctag<handler-hijack-sse>

// doctag<handler-websocket-echo>
WebSocketUpgrade webSocketHandler(Request req) {
  return WebSocketUpgrade((webSocket) async {
    webSocket.sendText('Welcome to Relic WebSocket!');

    await for (final event in webSocket.events) {
      if (event is TextDataReceived) {
        webSocket.sendText('Echo: ${event.text}');
      }
    }
  });
}
// end:doctag<handler-websocket-echo>

// Asynchronous handler that simulates delayed processing.
// doctag<handler-async>
Future<Response> myAsyncHandler(Request req) async {
  final data = await Future<String>.delayed(
    const Duration(milliseconds: 250),
    () => 'Hello from Relic!',
  );

  return Response.ok(body: Body.fromString(data));
}
// end:doctag<handler-async>

// Handler that demonstrates accessing request context information.
// doctag<handler-context>
Response myContextInfoHandler(Request req) {
  final method = req.method;
  final url = req.url;
  final userAgent = req.headers.userAgent;

  return Response.ok(
    body: Body.fromString(
      'Method: ${method.name}, Path: ${url.path}, '
      'User-Agent: ${userAgent ?? 'unknown'}\n',
    ),
  );
}
// end:doctag<handler-context>

Future<void> main() async {
  // doctag<handler-routes>
  final app = RelicApp()
    ..get('/hello', myHelloWorldHandler)
    ..get('/sse', mySseHandler)
    ..head('/sse', mySseHandler)
    ..get('/async', myAsyncHandler)
    ..get('/context', myContextInfoHandler)
    ..get('/ws', webSocketHandler);
  // end:doctag<handler-routes>

  await app.serve();
}
