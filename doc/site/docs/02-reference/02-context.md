---
sidebar_position: 2
---

# Context properties

Context properties provide **type-safe, request-scoped data storage** in Relic applications. Where Shelf keeps such data in a `Map<String, Object>` on the request, Relic attaches it to the `Request` through typed properties.

**Common use cases:**

- Store request IDs for logging and tracing.
- Cache computed values within a request (like parsed authentication tokens).
- Pass data between middleware and handlers.
- Track request-specific state (like the authenticated user or request timing).

## Creating context properties

Create each context property once, as a top-level or static `final`. It then attaches values to `Request` objects:

```dart
// Define each property once, as a global.
final requestIdProperty = ContextProperty<String>('requestId');
final userProperty = ContextProperty<User>('user');
final timingProperty = ContextProperty<Stopwatch>('timing');
```

:::warning Create properties once
Each `ContextProperty` holds a slot for the life of the isolate. Never create one per request or per handler. Debug builds assert after 1024 properties.
:::

:::tip Property naming
The optional name only appears in the error `get` throws when no value is set, so pick one that says what is missing.
:::

## Property API

Context properties provide the following methods:

| Method | Description | Returns |
| ------ | ----------- | ------- |
| `property[req] = value` | Set value for request, or clear it with `null` | `void` |
| `property[req]` | Read value from request | `T?` (nullable) |
| `property.get(req)` | Read value or throw if missing | `T` (non-null) |

### Adding properties

Set values in middleware or handlers using the `[]` operator:

GITHUB_CODE_BLOCK lang="dart" file="../_example/context/context_property.dart" doctag="context-prop-request-id" title="Add request ID to context"

### Reading properties

Read values with `property[req]` (returns null if missing) or `property.get(req)` (throws if missing):

GITHUB_CODE_BLOCK lang="dart" file="../_example/context/context_property.dart" doctag="context-prop-use-request-id" title="Use request ID from context"

:::info Property lifetime
Context properties exist **only for the duration of the request**. Once the response is sent, they're automatically cleaned up. Values are scoped to each request and do not leak between requests. A copy made with `copyWith` shares its properties with the original, so a value set on either shows on both.
:::

## Built-in context properties

Relic uses context properties internally to expose routing data on `Request` objects. These work exactly like user-defined properties. The routing middleware sets the raw path parameters, the router and the matched path, and the typed parameter accessors are built on first read:

- **`request.rawPathParameters`** - Path parameters extracted from the matched route (e.g., `:id`), as strings.
- **`request.pathParameters`** - Typed path parameter accessors over `rawPathParameters`.
- **`request.queryParameters`** - Typed query parameter accessors over the URL's query.
- **`request.router`** - The `RelicRouter` that routed the request (used by `forwardTo`).
- **`request.matchedPath`** / **`request.remainingPath`** - The portions of the path consumed and remaining after route matching.

This demonstrates the power of context properties: they provide a consistent, type-safe mechanism for attaching request-scoped data, whether from the framework or your own middleware.

## Examples & further reading

### Examples

- **[Context Property Example](https://github.com/serverpod/relic/blob/main/packages/examples/context/context_property.dart)** - Shows how to use context properties for request IDs and user authentication.

### API documentation

- [ContextProperty class](https://pub.dev/documentation/relic/latest/relic/ContextProperty-class.html) - Type-safe request-scoped data storage.
- [Request class](https://pub.dev/documentation/relic/latest/relic/Request-class.html) - HTTP request object that holds context properties.
