![Relic web server banner](https://github.com/serverpod/relic/raw/main/misc/images/github-banner.jpg)

<p align="center">
<a href="https://github.com/serverpod/relic/actions"><img src="https://github.com/serverpod/relic/workflows/Relic CI/badge.svg" alt="build"></a>
<a href="https://codecov.io/gh/serverpod/relic"><img src="https://codecov.io/gh/serverpod/relic/branch/main/graph/badge.svg" alt="codecov"></a>
<a href="https://github.com/serverpod/relic"><img src="https://img.shields.io/github/stars/serverpod/relic.svg?style=flat&logo=github&colorB=deeppink&label=stars" alt="Stars on Github"></a>
<a href="https://opensource.org/license/bsd-3-clause"><img src="https://img.shields.io/badge/license/bsd-3-clause.svg" alt="License: BSD-3-Clause"></a>
</p>

# Relic web server

Relic is a modern, high-performance web server framework inspired by [Shelf](https://pub.dev/packages/shelf) and built by the [Serverpod](https://serverpod.dev) team to meet the demanding requirements of modern web applications. Relic provides a robust, type-safe, and efficient foundation for building scalable web services.

👉 **[Full documentation available here](https://docs.dartrelic.dev/)** 📚

## Why Relic?

While Shelf has been a solid foundation for Dart web applications, several areas for improvement were identified. Rather than work around these limitations, Relic was created as a next-generation framework that maintains Shelf's familiar structure while delivering significant enhancements. These are some of the improvements:

- Strongly typed APIs with validated HTTP headers.
- Simplified interface for setting up routing and middleware.
- Unified encoding model for HTTP bodies.
- Built-in trie-based router, which improves performance.
- Static file handling with support for cache busting and etags.
- Built-in support for WebSockets.
- Improvements in hot reload and running with multiple isolates.

## Quick start

1. Install Dart 3.7 or newer and verify with `dart --version`.
2. Add Relic: `dart pub add relic`
3. Create a new console app and drop in the hello world server below.

```bash
dart create -t console-full hello_world
cd hello_world
dart pub add relic
```

### Run your first Relic server

Place this file in `bin/hello_world.dart` (runnable example is also under [`example/example.dart`](https://github.com/serverpod/relic/blob/main/example/example.dart)):

```dart
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// A simple 'Hello World' server demonstrating basic Relic usage.
Future<void> main() async {
  // Setup the app.
  final app =
      RelicApp()
        // Route with parameters (:name & :age).
        ..get('/user/:name/age/:age', helloHandler)
        // Middleware on all paths below '/'.
        ..use('/', logRequests())
        // Custom fallback - optional (default is 404 Not Found).
        ..fallback = respondWith(
          (_) => Response.notFound(
            body: Body.fromString("Sorry, that doesn't compute.\n"),
          ),
        );

  // Start the server (defaults to using port 8080).
  await app.serve();
}

/// Handles requests to the hello endpoint with path parameters.
Response helloHandler(final Request req) {
  final name = req.pathParameters[#name];
  final age = int.parse(req.pathParameters[#age]!);

  return Response.ok(
    body: Body.fromString('Hello, $name! To think you are $age years old.\n'),
  );
}
```

Run it with `dart run bin/hello_world.dart` and visit `http://localhost:8080/user/Nova/age/27`.

## Additional examples

Relic comes with an extensive set of examples. To run them, clone the Relic repository from GitHub and navigate to the `example` directory.

```bash
git clone https://github.com/serverpod/relic.git
cd relic/example
dart example.dart
```

## Migrating from Shelf

Are you on Shelf? Moving over is straightforward. Relic's APIs are very similar while giving you typed requests, built-in routing, and WebSockets out of the box. Follow the step-by-step guide at [docs.dartrelic.dev/getting-started/shelf-migration](https://docs.dartrelic.dev/getting-started/shelf-migration) to upgrade your project in minutes.
