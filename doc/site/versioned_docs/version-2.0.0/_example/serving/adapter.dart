import 'dart:io';

import 'package:relic/relic.dart';

Future<void> main() async {
  final app = RelicApp()
    ..get('/', (req) => Response.ok(body: .fromString('Hello\n')));

  // doctag<serving-run>
  final server = await app.run(
    () => IOAdapter.bind(InternetAddress.loopbackIPv4, port: 0),
  );
  stdout.writeln('Listening on port ${server.port}');
  // end:doctag<serving-run>
}
