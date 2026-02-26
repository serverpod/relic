---
name: relic-middleware
description: Create and apply middleware for auth, CORS, logging, and other cross-cutting concerns. Use context properties for type-safe request-scoped data. Use when adding middleware, request/response transformations, or passing data between middleware and handlers.
---

# Relic Middleware

A `Middleware` wraps a handler with additional logic. It can inspect/modify requests, transform responses, short-circuit with an early response, or handle errors.

```dart
typedef Middleware = Handler Function(Handler innerHandler);
```

## Basic pattern

```dart
Middleware myMiddleware() {
  return (Handler innerHandler) {
    return (Request req) async {
      // Before: inspect or modify the request

      final result = await innerHandler(req);

      // After: inspect or transform the response

      return result;
    };
  };
}
```

## Applying middleware

Use `router.use(path, middleware)`. Middleware only runs on requests that match a registered route -- unmatched requests (404s) go directly to the fallback.

```dart
final app = RelicApp()
  // Global -- applies to all matched routes
  ..use('/', logRequests())
  ..use('/', corsMiddleware())

  // Scoped -- only /api routes
  ..use('/api', authMiddleware())

  // Routes
  ..get('/', homeHandler)           // logRequests + cors
  ..get('/api/users', usersHandler) // logRequests + cors + auth
```

## Execution order

Path hierarchy first, then registration order within the same path scope:

```dart
final app = RelicApp()
  ..use('/api', middlewareC)    // specific to /api
  ..use('/', middlewareA)       // all paths
  ..use('/', middlewareB)       // all paths
  ..get('/api/foo', fooHandler);
```

For `GET /api/foo`, execution order is: `middlewareA` → `middlewareB` → `middlewareC` → `fooHandler` (and response flows back in reverse).

## Example: Auth middleware

```dart
Middleware authMiddleware() {
  return (Handler next) {
    return (Request req) async {
      final apiKey = req.headers['X-API-Key']?.first;
      if (apiKey != 'secret123') {
        return Response.unauthorized(body: Body.fromString('Invalid API key'));
      }
      return await next(req);
    };
  };
}

final app = RelicApp()
  ..get('/public', publicHandler)
  ..use('/protected', authMiddleware())
  ..get('/protected', protectedHandler);
```

## Example: CORS middleware

```dart
Middleware corsMiddleware() {
  return (Handler next) {
    return (Request req) async {
      if (req.method == Method.options) {
        return Response.ok(
          headers: Headers.build((mh) {
            mh['Access-Control-Allow-Origin'] = ['*'];
            mh['Access-Control-Allow-Methods'] = ['GET, POST, OPTIONS'];
            mh['Access-Control-Allow-Headers'] = ['Content-Type'];
          }),
        );
      }

      final result = await next(req);

      if (result is Response) {
        return result.copyWith(
          headers: result.headers.transform(
            (mh) => mh['Access-Control-Allow-Origin'] = ['*'],
          ),
        );
      }
      return result;
    };
  };
}
```

## Example: Error handling

```dart
Middleware errorHandlingMiddleware() {
  return (Handler next) {
    return (Request req) async {
      try {
        return await next(req);
      } catch (error) {
        return Response.internalServerError(
          body: Body.fromString('Something went wrong'),
        );
      }
    };
  };
}
```

## Example: Add response header

```dart
Middleware addHeaderMiddleware() {
  return (Handler next) {
    return (Request req) async {
      final result = await next(req);
      if (result is Response) {
        return result.copyWith(
          headers: result.headers.transform(
            (mh) => mh['X-Custom-Header'] = ['Hello from middleware!'],
          ),
        );
      }
      return result;
    };
  };
}
```

## Context properties

`ContextProperty<T>` provides type-safe, request-scoped storage. Values exist only for the duration of the request and do not leak between requests.

```dart
final requestIdProperty = ContextProperty<String>('requestId');

// Set in middleware
requestIdProperty[req] = 'req_${DateTime.now().millisecondsSinceEpoch}';

// Read in handler
final id = requestIdProperty[req];    // String? -- null if not set
final id = requestIdProperty.get(req); // String -- throws if missing
```

### Extension pattern for clean access

```dart
final _userProperty = ContextProperty<User>('user');
final _sessionProperty = ContextProperty<Session>('session');

extension AuthContext on Request {
  User get currentUser => _userProperty.get(this);
  Session get session => _sessionProperty.get(this);
}

// In middleware: set values
_userProperty[req] = authenticatedUser;

// In handler: read values
final user = req.currentUser;
```

### Complete example

```dart
extension on Request {
  String get requestId => _requestIdProperty.get(this);
}

final _requestIdProperty = ContextProperty<String>('requestId');

Handler requestIdMiddleware(Handler next) {
  return (req) async {
    _requestIdProperty[req] = 'req_${DateTime.now().millisecondsSinceEpoch}';
    return await next(req);
  };
}

Future<Response> handler(Request req) async {
  return Response.ok(body: Body.fromString('Request ID: ${req.requestId}'));
}

final app = RelicApp()
  ..use('/', requestIdMiddleware)
  ..get('/', handler);
```

### Built-in context properties

Relic sets these automatically during routing:

- `request.pathParameters` -- path params from matched route
- `request.queryParameters` -- typed query param accessors
- `request.router` -- the `RelicRouter` that routed the request
- `request.matchedPath` / `request.remainingPath` -- consumed and remaining path portions

## Pipeline (legacy)

`Pipeline` is a legacy composition pattern from Shelf. Prefer `router.use()` for new code. `Pipeline` runs middleware on all requests including 404s, while `router.use()` only runs on matched routes.
