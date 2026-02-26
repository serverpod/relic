---
name: relic-app-setup
description: Bootstrap a Relic web server, configure RelicApp, start serving, and enable hot reload. Use when creating a new Relic project, setting up a server, or configuring the development workflow.
---

# Relic App Setup

Relic is a Dart web server framework. Requires Dart SDK 3.7+. Single import: `package:relic/relic.dart`.

## Installation

```bash
dart create -t console-full my_server
cd my_server
dart pub add relic
```

## Minimal server

```dart
import 'package:relic/relic.dart';

Future<void> main() async {
  final app = RelicApp()
    ..get('/hello/:name', (Request req) {
      final name = req.rawPathParameters[#name];
      return Response.ok(
        body: Body.fromString('Hello, $name!'),
      );
    })
    ..use('/', logRequests())
    ..fallback = respondWith(
      (_) => Response.notFound(
        body: Body.fromString('Not found'),
      ),
    );

  await app.serve();
}
```

## Serve options

```dart
await app.serve(); // defaults to 0.0.0.0:8080

await app.serve(
  address: InternetAddress.loopbackIPv4,
  port: 3000,
);
```

## Fallback handler

The fallback handles requests that don't match any route. Default is 404 with an empty body.

```dart
app.fallback = respondWith(
  (_) => Response.notFound(
    body: Body.fromString('Page not found'),
  ),
);
```

## Hot reload

Relic supports hot reload of route handlers without server restart.

**IDE:** Start the server in Debug mode. Enable "Hot Reload On Save" in your Dart plugin settings (typically set it to `manual`).

**CLI:**

```bash
dart run --enable-vm-service bin/main.dart
```

When a hot reload is triggered, `RelicApp` automatically reconfigures its internal router with the latest route definitions. Changes to server state or global variables may still require a full restart.
