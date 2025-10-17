---
sidebar_position: 2
sidebar_label: 👋 Hello world
---

# Hello world

Once you have Dart installed, it only takes a few lines of code to set up your Relic server. These are the steps you need to take to get a simple "Hello world" server up and running.

## Create a Dart package

First, you need to create a new Dart package for your Relic server.

```bash
dart create -t console-full hello_world
```

## Add the Relic dependency

Next, add the `relic` package as a dependency to your `pubspec.yaml` file.

```bash
cd hello_world
dart pub add relic
```

## Edit the main file

Edit the `bin/hello_world.dart`:

```dart
import 'dart:io';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

Future<void> main() async {
  // Create a simple handler that responds to every request
  final handler = respondWith(
    (final request) => Response.ok(
      body: Body.fromString('Hello world!'),
    ),
  );

  // Start the server on all network interfaces, port 8080
  await serve(handler, InternetAddress.anyIPv4, 8080);
  print('Server running on http://localhost:8080');
}
```

**What this code does:**

1. **Handler** `respondWith()` wraps a simple function that takes any `Request` and returns a `Response`
2. **Response** `Response.ok()` creates an HTTP 200 response with the body "Hello world!"
3. **Server** `serve()` binds the handler to port 8080 on all network interfaces

The result is a server that responds to every HTTP request with the same "Hello world!" message, regardless of the URL path or HTTP method used.

## Running locally

Run the app with the following command:

```bash
dart run bin/hello_world.dart
```

Then, load `http://localhost:8080/` in a browser to see the output.
