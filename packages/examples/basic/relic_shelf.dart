import 'dart:developer';

// doctag<complete-relic>
import 'dart:io';

import 'package:relic/relic.dart';

Future<void> main() async {
  final app = RelicApp()
    ..use('/', logRequests())
    ..get('/users/:id', (Request request) {
      final id = request.rawPathParameters[#id];
      final name = request.url.queryParameters['name'] ?? 'Unknown';
      return Response.ok(body: Body.fromString('User $id: $name'));
    });

  await app.serve(address: InternetAddress.loopbackIPv4, port: 8080);
}
// end:doctag<complete-relic>

/// Handles WebSocket connections with event logging.
// doctag<websocket-relic>
WebSocketUpgrade websocketHandler(Request request) {
  return WebSocketUpgrade((ws) async {
    ws.events.listen((event) {
      log('Received: $event');
    });

    ws.sendText('Hello!');
  });
}

// end:doctag<websocket-relic>

// doctag<shelf-relic-handler>
Response handler(Request request) {
  return Response.ok(body: Body.fromString('Hello from Relic!'));
}
// end:doctag<shelf-relic-handler>

// doctag<shelf-relic-routing>
final router = RelicApp()
  ..get('/users/:id', (request) {
    final id = request.pathParameters.raw[#id];
    return Response.ok(body: Body.fromString('User $id'));
  });
// end:doctag<shelf-relic-routing>

List<Response> responses() {
  // doctag<shelf-relic-responses>
  // Relic - an explicit Body object is required.
  final textResponse = Response.ok(body: Body.fromString('Hello, World!'));

  // Content-Length is calculated, and Content-Type and encoding are part of
  // the Body.
  final htmlResponse = Response.ok(
    body: Body.fromString('<html>...</html>', mimeType: MimeType.html),
  );
  // end:doctag<shelf-relic-responses>
  return [textResponse, htmlResponse];
}

List<Object?> readHeaders(Request request) {
  // doctag<shelf-relic-headers>
  final contentType = request.headers.contentType; // ContentTypeHeader?
  final cookies = request.headers.cookie; // CookieHeader?
  final date = request.headers.date; // DateTime?
  // end:doctag<shelf-relic-headers>
  return [contentType, cookies, date];
}

Handler authenticate(Handler next) => next;

// doctag<shelf-relic-middleware>
final app = RelicApp()
  ..use('/', logRequests())
  ..use('/api', authenticate)
  ..get('/api/users', (request) {
    return Response.ok(body: Body.fromString('User data'));
  });
// end:doctag<shelf-relic-middleware>

class User {
  final String name;
  const User(this.name);
}

class Session {
  final DateTime started;
  Session(this.started);
}

// doctag<shelf-relic-context>
// Create each property once, as a global.
final userProperty = ContextProperty<User>('user');
final sessionProperty = ContextProperty<Session>('session');

// An extension for convenient access.
extension AuthContext on Request {
  User get currentUser => userProperty.get(this);
  Session get session => sessionProperty.get(this);
}

// Set the values in a middleware, for example after a login check.
Handler loadSession(Handler next) {
  return (request) {
    userProperty[request] = const User('Nova');
    sessionProperty[request] = Session(DateTime.now());
    return next(request);
  };
}

// Read them in a handler further down.
Response profile(Request request) {
  final user = request.currentUser;
  final session = request.session;
  return Response.ok(
    body: Body.fromString('${user.name}, since ${session.started}'),
  );
}

// end:doctag<shelf-relic-context>
