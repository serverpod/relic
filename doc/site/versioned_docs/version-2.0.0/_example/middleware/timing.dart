import 'dart:io';

import 'package:relic/relic.dart';

// doctag<middleware-timed>
Handler timed(Handler inner) {
  return (req) async {
    final stopwatch = Stopwatch()..start();
    final result = await inner(req);
    stdout.writeln(
      '${req.method.value} ${req.url.path}: '
      '${stopwatch.elapsedMicroseconds} us',
    );
    return result;
  };
}
// end:doctag<middleware-timed>

Response hello(Request req) => Response.ok(body: Body.fromString('Hello!\n'));

Future<void> main() async {
  // doctag<middleware-timed-use>
  final app = RelicApp()
    ..use('/', timed)
    ..get('/hello', hello);
  // end:doctag<middleware-timed-use>

  await app.serve();
}
