---
sidebar_position: 2
---

# Hello, World! Example 🌟

Create `bin/server.dart` and start a basic Relic server:

```dart
import 'package:relic/relic.dart';

Future<void> main() async {
  final app = Relic()
    ..use(routeWith(
      Router<Handler>()
        ..add(Method.get, '/', (ctx) async => ctx.respondText('Hello, Relic!')),
    ));

  await serve(app, address: '127.0.0.1', port: 8080);
}
```

Run it:

```bash
dart run bin/server.dart
```

Then open `http://127.0.0.1:8080/` in your browser.
