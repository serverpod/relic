import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

void main() async {
    // This is your handler - it receives a NewContext and returns a ResponseContext
  Future<ResponseContext> handler(final NewContext ctx) async {
    return ctx.respond(
      Response.ok(body: Body.fromString('Hello, World!')),
    );
  }


  final app = RelicApp()
    ..get('/**', handler);

  // Start the server
  await app.serve();
}
