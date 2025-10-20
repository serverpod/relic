---
sidebar_position: 2
sidebar_label: 🌟 Hello, World! Example
---

# Hello, World! Example

Let's get your first Relic server up and running! This guide walks you through creating a minimal "Hello, World!" API to demonstrate just how easy it is to get started with Relic.

This example will show you how to:

- Initialize a simple Relic server
- Define your first route
- Start the server and handle web requests

### Create the App File

Create a file at `bin/hello_world.dart` with the following content:

```dart file="hello_world.dart"
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

Future<void> main() async {
  // Create a simple handler that responds to every request
  final app = RelicApp()
    ..get(
      '/**', (final ctx) => ctx.respond(
        Response.ok(
          body: Body.fromString('Hello, Relic!'),
        ),
      ),
    );

  // Start the server on port 8080
  await app.serve(port: 8080);
}
```

**What this code does:**

1. **Router**: `RelicApp()` is used to configure routing for the server.
2. **Route**: `.get('/', ...)` handles GET requests to `/` and responds with "Hello, Relic!".
3. **Server**: `app.serve()` binds the router (as a handler) to port 8080 on all network interfaces.
4. **Logging**: The server logs to the console when started.

The result is a server that responds with "Hello, Relic!" when you send a GET request to `http://localhost:8080/`.

### Running Locally

First, make sure you have Relic installed by following the [installation guide](/getting-started/installation).

Start your server with:

```bash
dart run bin/hello_world.dart
```

Then, open your browser and visit `http://localhost:8080/`, or use curl:

```bash
curl http://localhost:8080/
```

You should see:

``` bash
Hello, Relic!
```

Congratulations! You just ran your first Relic server.
