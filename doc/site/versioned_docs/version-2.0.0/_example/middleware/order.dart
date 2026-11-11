import 'dart:io';

import 'package:relic/relic.dart';

// doctag<middleware-order-trace>
Middleware trace(String name) {
  return (next) {
    return (req) async {
      stdout.writeln('$name: before');
      final result = await next(req);
      stdout.writeln('$name: after');
      return result;
    };
  };
}
// end:doctag<middleware-order-trace>

Future<void> main() async {
  // doctag<middleware-order-app>
  final app = RelicApp()
    ..use('/api', trace('C'))
    ..use('/', trace('A'))
    ..use('/', trace('B'))
    ..get('/api/users', (req) {
      stdout.writeln('handler');
      return Response.ok();
    });
  // end:doctag<middleware-order-app>

  await app.serve();
}
