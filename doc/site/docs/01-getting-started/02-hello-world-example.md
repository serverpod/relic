---
sidebar_position: 2
---

# Hello, World! Example 🌟

Create `bin/server.dart` and start a basic Relic server:

```dart
import 'dart:io';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

Future<void> main() async {
  final handler = respondWith((request) {
    return Response.ok(body: Body.fromString('Hello, Relic!'));
  });

  await serve(handler, InternetAddress.anyIPv4, 8080);
  print('Server running on http://localhost:8080');
}

```

Run it:

```bash
dart run bin/server.dart
```

Then open `http://127.0.0.1:8080/` in your browser.
