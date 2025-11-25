---
sidebar_position: 2
---

# Context properties

Context properties provide **type-safe, request-scoped data storage** in Relic applications. They replace Shelf's `Map<String, Object>` context with a more robust system that attaches custom data directly to `Request` objects.

**Common use cases:**

- Store request IDs for logging and tracing.
- Cache computed values within a request (like parsed authentication tokens).
- Pass data between middleware and handlers.
- Track request-specific state (like the authenticated user or request timing).

## Creating context properties

Context properties are created as global constants and attached directly to `Request` objects:

```dart
// Define properties (typically as global constants)
final requestIdProperty = ContextProperty<String>('requestId');
final userProperty = ContextProperty<User>('user');
final timingProperty = ContextProperty<Stopwatch>('timing');
```

:::tip Property naming
Use descriptive names for your properties. The string identifier is used internally for storage and debugging.
:::

## Property API

Context properties provide the following methods:

| Method | Description | Returns |
| ------ | ----------- | ------- |
| `property[req] = value` | Set value for request | `T` (non-null) |
| `property[req]` | Read value from request | `T?` (nullable) |
| `property.get(req)` | Read value or throw if missing | `T` (non-null) |

### Adding properties

Set values in middleware or handlers using the `[]` operator:

GITHUB_CODE_BLOCK lang="dart" file="../_example/context/context_property.dart" doctag="context-prop-request-id" title="Add request ID to context"

### Reading properties

Read values with `property[req]` (returns null if missing) or `property.get(req)` (throws if missing):

GITHUB_CODE_BLOCK lang="dart" file="../_example/context/context_property.dart" doctag="context-prop-use-request-id" title="Use request ID from context"

:::info Property lifetime
Context properties exist **only for the duration of the request**. Once the response is sent, they're automatically cleaned up. Values are scoped to each request and do not leak between requests.
:::

## Examples & further reading

### Examples

- **[Context Property Example](https://github.com/serverpod/relic/blob/main/example/context/context_property.dart)** - Shows how to use context properties for request IDs and user authentication.

### API documentation

- [ContextProperty class](https://pub.dev/documentation/relic/latest/relic/ContextProperty-class.html) - Type-safe request-scoped data storage.
- [Request class](https://pub.dev/documentation/relic/latest/relic/Request-class.html) - HTTP request object that holds context properties.
