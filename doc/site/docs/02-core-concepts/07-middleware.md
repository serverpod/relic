---
sidebar_position: 7
---

# Middleware

Middlewares are the backbone of Relic's request processing pipeline. It provides a powerful pattern for composing functionality around your handlers, enabling you to add cross-cutting concerns like logging, authentication, CORS, and more in a clean, reusable way.

They work by wrapping handlers with additional functionality. Think of it as a series of layers around your core handler, each layer can inspect and modify requests before they reach your handler, and responses after they leave your handler.

## What is Middleware?

A `Middleware` is a function that takes a handler and returns a new handler with enhanced functionality. This pattern allows you to compose multiple pieces of functionality together, creating a processing pipeline where each middleware layer adds its own behavior.

```dart
typedef Middleware = Handler Function(Handler innerHandler);
```

### Handler Wrapping

Every middleware function receives an inner handler and returns a new handler that wraps the original. This wrapper can:

- **Inspect requests** before passing them to the inner handler
- **Modify requests** by creating new request objects
- **Short-circuit processing** by returning a response without calling the inner handler
- **Transform responses** after the inner handler completes
- **Handle errors** that occur in the inner handler

Here's a simple example:

```dart title="middleware_example.dart"
import 'package:relic/relic.dart';

// A middleware that adds a custom header
Middleware addHeaderMiddleware() {
  return (Handler innerHandler) {
    return (NewContext ctx) async {
      // Call the inner handler
      final result = await innerHandler(ctx);
      
      // Add custom header to response
      if (result is ResponseContext) {
        final newResponse = result.response.copyWith(
          headers: result.response.headers.transform(
            (mh) => mh['X-Custom-Header'] = ['Hello from middleware!'],
          ),
        );
        return result.respond(newResponse);
      }
      
      return result;
    };
  };
}
```

## Using Middlewares with Router

### `router.use()` for Applying Middleware

Relic's `RelicApp` provides a convenient `use()` method for applying middleware to specific path patterns. This is the preferred way to add middleware in modern Relic applications.

```dart
import 'package:relic/relic.dart';

final router = RelicApp()
  // Apply logging to all routes
  ..use('/', logRequests())
  
  // Apply authentication to API routes
  ..use('/api', authMiddleware())
  
  // Define your routes
  ..get('/api/users', usersHandler)
  ..post('/api/users', createUserHandler);
```

### Global vs Route-Specific Middlewares

There are two types of categories of middlewares: global and route-specific. Global middlewares apply to all routes in your application, while route-specific middlewares apply only to routes under a specific path.

**Global Middleware:** applies to all routes in your application:

```dart
final app = RelicApp()
  // Global middleware - applies to ALL routes
  ..use('/', logRequests())
  ..use('/', corsMiddleware())
  
  // Your routes
  ..get('/users', usersHandler)
  ..get('/posts', postsHandler);
```

:::tip Middleware path matching
Any middleware setup with router.use will only run on a match. Never on 404 or 405

This means that when you use `router.use('/', middleware)`, the middleware applies to all matched routes at or below `/`. However, it won't run for requests that don't match any route in your router. If you need middleware to run for all requests (including 404s), you need to use a pipeline to make it truly global, or if it only needs to run on fallback, compose the fallback handler directly.
:::

**Route-Specific Middleware:** applies only to routes under a specific path:

```dart
final app = RelicApp()
  // Global logging
  ..use('/', logRequests())
  
  // Authentication only for API routes
  ..use('/api', authMiddleware())
  
  // Routes
  ..get('/', homeHandler)           // Only logging
  ..get('/api/users', usersHandler) // Logging + auth
```

:::info Built-in Logging
Relic provides a built-in middleware function for logging request details including method, path, status code, and response time:

```dart
final router = RelicApp()..use('/', logRequests());
```

:::

### Execution Order and PathHierarchy

One of Relic's most powerful features is its hierarchical middleware application system. Middleware is applied based on path hierarchy first, with registration order only mattering within the same path scope. This allows you to create scoped middleware that only applies to certain sub-trees of your route structure.

- Path Hierarchy is the order in which middlewares are applied to a request. This hierarchical scoping enables powerful patterns like applying authentication only to API routes while keeping logging global, or adding specialized middleware for admin sections.

:::tip Path Hierarchy
One important thing to note is that path hierarchy takes precedence over registration order.
:::

This means that within the same path scope, middlewares are applied in the order they are registered, creating nested layers.

```dart
final app = RelicApp()
  ..use('/api', middlewareC)    // Registered first, but specific to /api
  ..use('/', middlewareA)       // Registered second and applicable to all paths below /
  ..use('/', middlewareB)       // Registered last and applicable to all paths below /
  ..get('/api/foo', fooHandler);
```

Since `middlewareC` was added with `use('/api', middlewareC)` it won't impact requests towards other paths .. but will be used specifically for `/api/foo`. Whereas `middlewareA` and `middlewareB` are both applicable for all paths below `/`.

Lets look at an example of how middlewares will work in same path scope:

```dart
final app = RelicApp()
  ..use('/api', middleware1)  // MW1 - outermost (registered first)
  ..use('/api', middleware2)  // MW2 - middle
  ..use('/api', middleware3)  // MW3 - innermost (registered last)
  ..get('/api/users', usersHandler);  // H - handler
```

The request flows from the outermost middleware to the innermost handler, and the response flows back out in reverse. The diagram below shows execution for a request to `/api/users` with three middleware layers registered at the same path.

```mermaid
sequenceDiagram
  autonumber
  participant Client
  participant MW1 as middleware1
  participant MW2 as middleware2
  participant MW3 as middleware3
  participant H as usersHandler

  Client->>MW1: Request
  MW1->>MW2: next()
  MW2->>MW3: next()
  MW3->>H: next()
  H-->>MW3: Response
  MW3-->>MW2: transform(response)
  MW2-->>MW1: transform(response)
  MW1-->>Client: Response
```

Middleware layers wrap each other like an onion. Each layer may:

- Short-circuit and return a response early (e.g., auth returning 401) without calling `next()`.
- Rewrite parts of the request before calling `next()` using `ctx.withRequest(newRequest)`.
- Prefer attaching derived/computed data to the context via `ContextProperty` rather than rewriting the request.

```dart
// Early return (short-circuit)
Middleware authMiddleware() {
  return (Handler next) {
    return (NewContext ctx) async {
      final apiKey = ctx.request.headers['X-API-Key']?.first;
      if (apiKey != 'secret123') {
        return ctx.respond(Response.unauthorized(
          body: Body.fromString('Invalid API key'),
        )); // short-circuit: no next()
      }
      return await next(ctx);
    };
  };
}
```

:::warning Avoid rewriting request.path in router.use middleware
When middleware is attached with `router.use(...)`, the request has already been routed. Changing `request.url.path` at this point will not re-route the request and will not update `ctx.pathParameters` or related routing metadata.
:::

## Writing Custom Middleware

This is the signature that all middleware functions follow:

```dart title="middleware.dart"
Middleware myMiddleware() {
  return (Handler innerHandler) {
    return (NewContext ctx) async {
      // Before request processing
      
      final result = await innerHandler(ctx);
      
      // After request processing
      
      return result;
    };
  };
}
```

With middleware, you can perform actions both before and after the inner handler executes: For example, you can log the request and response, add headers to a response, or even catch and handle errors from inner handlers:

### CORS (Cross-Origin Resource Sharing)

CORS is a security feature that allows web applications to make requests to resources from different origins. It is a mechanism that uses additional HTTP headers to tell browsers to let web applications running in one origin have permission to access resources from a different origin. [Learn more](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS).

In Relic you can create a CORS middleware that handles preflight requests and adds CORS headers to the response:

```dart title="cors_example.dart"
Middleware corsMiddleware() {
  return (Handler innerHandler) {
    return (NewContext ctx) async {
      // Handle preflight requests
      if (ctx.request.method == Method.options) {
        return ctx.respond(Response.ok(
          headers: Headers.build((mh) {
            mh['Access-Control-Allow-Origin'] = ['*'];
            mh['Access-Control-Allow-Methods'] = ['GET, POST, OPTIONS'];
          }),
        ));
      }
      
      // Process normal request and add CORS headers
      final result = await innerHandler(ctx);
      
      if (result is ResponseContext) {
        final newResponse = result.response.copyWith(
          headers: result.response.headers.transform(
            (mh) => mh['Access-Control-Allow-Origin'] = ['*'],
          ),
        );
        return result.respond(newResponse);
      }
      
      return result;
    };
  };
}
```

## Pipeline (Legacy Pattern)

The `Pipeline` class provides a legacy approach to composing middleware. While `router.use()` is now preferred for most applications, `Pipeline` is still useful in certain scenarios.
Read more about [Pipeline](./pipeline) for more details.

### Best Practices

- ✅ **Keep middleware focused:** Each middleware should have a single responsibility.
- ✅ **Order matters:** Apply middleware in logical order: logging first, then authentication, then authorization, then business logic.
- ✅ **Handle errors gracefully:** Always include error handling in your middleware to prevent unhandled exceptions.
- ✅ **Test middleware independently:** Write unit tests for your middleware functions to ensure they work correctly in isolation.

## Summary

Middleware is a powerful pattern that enables you to compose functionality around your handlers in a clean, reusable way. Relic provides excellent middleware support through both the modern `router.use()` approach and the legacy `Pipeline` class.

Key takeaways:

- Use `router.use()` for path-specific middleware in modern Relic applications
- Write focused middleware that does one thing well
- Handle errors gracefully and provide meaningful error responses
- Test your middleware thoroughly to ensure correct behavior

With these patterns and examples, you can build robust, maintainable web applications that handle cross-cutting concerns elegantly through middleware composition.

## Examples

Check out these examples to see middleware in action:

- **[Middleware Example](https://github.com/serverpod/relic/blob/main/example/middleware/middleware_example.dart)** - Basic middleware patterns
- **[Auth Example](https://github.com/serverpod/relic/blob/main/example/middleware/auth_example.dart)** - Authentication middleware  
- **[CORS Example](https://github.com/serverpod/relic/blob/main/example/middleware/cors_example.dart)** - CORS handling
- **[Pipeline Example](https://github.com/serverpod/relic/blob/main/example/middleware/pipeline_example.dart)** - Pipeline vs Router comparison
- [Read more about CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS).
