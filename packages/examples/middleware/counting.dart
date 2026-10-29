import 'package:relic/relic.dart';

// doctag<middleware-counting>
Middleware countRequests() {
  var count = 0;
  return (next) {
    return (req) async {
      count++;
      final result = await next(req);
      if (result is! Response) return result;
      return result.copyWith(
        headers: result.headers.transform(
          (h) => h['X-Request-Count'] = ['$count'],
        ),
      );
    };
  };
}
// end:doctag<middleware-counting>

Response hello(Request req) => Response.ok(body: Body.fromString('Hello!\n'));

Future<void> main() async {
  final app = RelicApp()
    ..use('/', countRequests())
    ..get('/hello', hello);

  await app.serve();
}
