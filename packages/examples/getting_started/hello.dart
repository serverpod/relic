// doctag<hello-step-1>
import 'package:relic/relic.dart';

Future<void> main() async {
  final app = RelicApp()
    ..get('/', (req) => Response.ok(body: Body.fromString('Hello, world!\n')));

  await app.serve();
}

// end:doctag<hello-step-1>
