---
sidebar_position: 2
---

# Hello, World! Example 🌟

Create `bin/hello_world.dart` and start a basic Relic server:

```dart
import 'dart:io';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

Future<void> main() async {
  // Create a simple handler that responds to every request
  final handler = respondWith(
    (final request) => Response.ok(
      body: Body.fromString('Hello, Relic!'),
    ),
  );

  // Start the server on all network interfaces, port 8080
  await serve(handler, InternetAddress.anyIPv4, 8080);
  print('Server running on http://localhost:8080');
}
```

**What this code does:**

1. **Handler** `respondWith()` wraps a simple function that takes any `Request` and returns a `Response`
2. **Response** `Response.ok()` creates an HTTP 200 response with the body "Hello, Relic!"
3. **Server** `serve()` binds the handler to port 8080 on all network interfaces

The result is a server that responds to every HTTP request with the same "Hello, Relic!" message, regardless of the URL path or HTTP method used.

### Running Locally
First ensure you have Relic installed as per the [installation guide](/getting-started/installation).

Run the app with the following command:

```bash
dart run bin/hello_world.dart
```

Then, load `http://localhost:8080/` in a browser to see the output.