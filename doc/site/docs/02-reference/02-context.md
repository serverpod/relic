---
sidebar_position: 2
---

# Context Properties

Context properties provide **type-safe, request-scoped data storage** in Relic applications. They replace Shelf's `Map<String, Object>` context with a more robust system that attaches custom data directly to `Request` objects.

**Common use cases:**

- Store request IDs for logging and tracing
- Cache computed values within a request (like parsed authentication tokens)
- Pass data between middleware and handlers
- Track request-specific state (like authenticated user, request timing)

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

Context properties provide three main methods:

| Method | Description | Returns |
|--------|-------------|----------|
| `property.add(req, value)` | Add value to request | New `Request` with property |
| `property.read(req)` | Read value from request | `T?` (nullable) |
| `property.readOrThrow(req)` | Read value or throw | `T` (non-null) |

### Adding properties

Properties are **immutable** - `add()` returns a new `Request` instance:

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/context/context_property_example.dart) doctag="context-prop-request-id" title="context_property_example.dart"

### Reading properties

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/context/context_property_example.dart) doctag="context-prop-use-request-id" title="context_property_example.dart"

:::info Property lifetime
Context properties exist **only for the duration of the request**. Once the response is sent, they're automatically cleaned up. Properties are immutable - each `add()` call returns a new `Request` instance.
:::

## Example

- **[Context Property Example](https://github.com/serverpod/relic/blob/main/example/context/context_property_example.dart)** - Shows how to use context properties for request IDs and user authentication
