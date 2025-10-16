---
sidebar_position: 7
sidebar_label: Pipeline (Legacy)
---

# Pipeline (Legacy Pattern)

Pipeline is a legacy pattern for composing middleware, see [Middleware](./middleware) for the modern approach.

## Overview

The `Pipeline` class is a helper that makes it easy to compose a set of [Middleware] and a [Handler]. It provides a fluent API for building middleware chains that process requests and responses in a specific order.

```dart
import 'package:relic/relic.dart';

final handler = const Pipeline()
  .addMiddleware(logRequests())
  .addMiddleware(corsMiddleware())
  .addMiddleware(authMiddleware())
  .addHandler(myHandler);
```

## How Pipeline Works

The Pipeline class uses a recursive composition pattern where each middleware wraps the next one in the chain:

1. **Request Flow**: Middleware processes requests from outermost to innermost
2. **Response Flow**: Middleware processes responses from innermost to outermost

When you call `addMiddleware()`, it creates a new `Pipeline` instance that stores the current middleware and a reference to the parent composition. When `addHandler()` is finally called, it recursively builds the middleware chain by wrapping each handler with its middleware.

This creates a nested structure where each middleware wraps the next, forming a Russian doll pattern of function composition.

### Migration from Pipeline to `router.use()`

**Old Pipeline approach:**

```dart
final router = Router<Handler>()
  ..get('/users', usersHandler)
  ..get('/posts', postsHandler);

final handler = const Pipeline()
  .addMiddleware(logRequests())
  .addMiddleware(authMiddleware())
  .addMiddleware(routeWith(router))
  .addHandler(respondWith((_) => Response.notFound()));
```

**New router.use() approach:**

```dart
final router = RelicRouter()
  ..use('/', logRequests())
  ..use('/', authMiddleware())
  ..get('/users', usersHandler)
  ..get('/posts', postsHandler)
  ..fallback = respondWith((_) => Response.notFound());

final handler = router.asHandler;
```

The new approach is more concise, provides better path-specific middleware control, and integrates more naturally with Relic's routing system.

## Summary

Pipeline is a legacy pattern for composing middleware, see [Middleware](./middleware) for the modern approach.

## Examples

Check out these examples to see pipeline in action:

- **[Pipeline Example](https://github.com/serverpod/relic/blob/main/example/middleware/pipeline_example.dart)** - Pipeline vs Router comparison
- [API Reference](https://pub.dev/documentation/relic/latest/relic/Pipeline-class.html)
