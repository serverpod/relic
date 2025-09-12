import 'dart:convert';
import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// Example demonstrating secure error handling
Future<void> main() async {
  // Setup router with JSON parsing endpoint
  final router = Router<Handler>()
    ..post('/api/json', handleJsonPost)
    ..get('/user/:name/age/:age', hello);

  // Setup secure handler pipeline
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(routeWith(router))
      .addHandler(respondWith((final _) => Response.notFound(
          body: Body.fromString("Sorry, that doesn't compute"))));

  // Start the server with sanitized error messages enabled for production
  await serve(
    handler, 
    InternetAddress.anyIPv4, 
    8080,
    sanitizeErrorMessages: true, // Enable secure error handling
  );

  print('Serving at http://localhost:8080');
  print('Try POST /api/json with invalid JSON to see sanitized error handling');
  print('Example: curl -X POST http://localhost:8080/api/json -d "invalid json"');
}

ResponseContext hello(final NewContext ctx) {
  final name = ctx.pathParameters[#name];
  final age = int.parse(ctx.pathParameters[#age]!);

  return ctx.respond(Response.ok(
      body: Body.fromString('Hello $name! To think you are $age years old.')));
}

/// Handler that parses JSON and might throw detailed error messages
Future<ResponseContext> handleJsonPost(final NewContext ctx) async {
  try {
    // Read the request body
    final bodyBytes = await ctx.request.body.read().toList();
    final bodyString = utf8.decode(bodyBytes.expand((element) => element).toList());
    
    // Attempt to parse JSON - this will throw with user input on failure
    final jsonData = jsonDecode(bodyString);
    
    return ctx.respond(Response.ok(
      body: Body.fromString('Received JSON: $jsonData'),
    ));
  } on FormatException catch (e) {
    // This error message would normally contain the malformed input
    throw Exception('Invalid JSON in body: ${e.source}');
  }
}