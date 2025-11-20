---
sidebar_position: 99
sidebar_label: Pipeline (legacy)
---

# Pipeline (legacy)

:::warning Legacy Feature
Pipeline is a legacy pattern for composing middleware. For modern Relic applications, use the `router.use()` approach described in the [Middleware](./middleware) documentation.
:::

Pipeline is a legacy pattern for composing middleware, see [Middleware](./middleware) for the modern approach. It's included to ease the transition from Shelf to Relic.

## Overview

The `Pipeline` class is a helper that makes it easy to compose a set of [Middleware] and a [Handler]. It provides a fluent API for building middleware chains that process requests and responses in a specific order.

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/middleware/pipeline_example.dart) doctag="pipeline-usage" title="Pipeline usage"

## How Pipeline works

The Pipeline class uses a recursive composition pattern where each middleware wraps the next one in the chain:

1. **Request Flow**: Middleware processes requests from outermost to innermost.
2. **Response Flow**: Middleware processes responses from innermost to outermost.

When you call `addMiddleware()`, it creates a new `Pipeline` instance that stores the current middleware and a reference to the parent composition. When `addHandler()` is finally called, it recursively builds the middleware chain by wrapping each handler with its middleware.

This creates a nested structure where each middleware wraps the next, forming a Russian doll pattern of function composition.

### Migration from Pipeline to `router.use()`

**Old Pipeline approach:**

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/middleware/pipeline_example.dart) doctag="pipeline-usage" title="Pipeline usage"

**New router.use() approach:**

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/middleware/pipeline_example.dart) doctag="router-usage" title="router.use() usage"

The new approach is more concise, provides better path-specific middleware control, and integrates more naturally with Relic's routing system.

## Examples

Check out these examples to see pipeline in action:

- **[Pipeline Example](https://github.com/serverpod/relic/blob/main/example/middleware/pipeline_example.dart)** - Pipeline vs Router comparison
- [API Reference](https://pub.dev/documentation/relic/latest/relic/Pipeline-class.html)
