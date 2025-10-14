# Relic Documentation Structure Outline

## Introduction & Overview

### Welcome / What is Relic?

- Brief introduction and value proposition
- Modern, type-safe HTTP server for Dart
- Comparison elevator pitch vs Shelf
- Key benefits summary

### Why Relic?

- Modern Dart features (null safety, sealed classes, type safety)
- Performance optimizations (trie-based routing, LRU caching)
- Better developer experience
- Built-in WebSocket support

### Quick Start

- Installation instructions
- "Hello World" example
- First route and handler
- Running the server

## Core Concepts

### Handlers

- What is a Handler?
- Handler signature and context types
- Writing your first handler
- Responder pattern (Request → Response)

### Request Context State Machine

- Overview of the context lifecycle
- `NewContext` → `HandledContext` flow
- `ResponseContext` (standard HTTP)
- `HijackContext` (low-level socket control)
- `ConnectContext` (WebSocket/duplex)
- Why no exceptions for control flow

### Requests

- Request structure
- Accessing request data (headers, body, query params)
- Path parameters
- Reading request bodies

### Responses

- Creating responses
- Status codes
- Setting headers
- Response bodies (string, data, streams)

### Body Architecture

- The `Body` class
- Body types and encoding
- Content-Length handling
- Stream-based bodies

## Routing

### Router Basics

- Creating a router
- HTTP methods (GET, POST, PUT, DELETE, etc.)
- Route registration

### Path Parameters

- Dynamic segments (`:id`)
- Symbol-based parameter access
- Type conversion and validation

### Advanced Routing Patterns

- Wildcard segments (`/*`)
- Tail segments (`/**`)
- Route priority and matching

### Router Composition

- Sub-routers with `attach()`
- Inline groups with `group()`
- Nested routing
- Modular route organization

### Router Internals (Optional/Advanced)

- Trie-based data structure
- O(segments) vs O(routes) performance
- PathMiss vs MethodMiss
- LRU path normalization cache

## Middleware

### What is Middleware?

- Middleware concept and pattern
- Handler wrapping
- Request/response transformation

### Using Middleware with Router

- `router.use()` for applying middleware
- Global middleware vs route-specific middleware
- Middleware on groups and sub-routers
- Built-in middleware (logging, CORS, etc.)
- Middleware execution order

### Writing Custom Middleware

- Middleware signature
- Before/after request handling
- Conditional middleware
- Error handling in middleware

### Common Middleware Patterns

- Authentication
- CORS
- Compression
- Rate limiting
- Static file serving

### Pipeline (Legacy Pattern)

- Understanding the Pipeline approach
- When you might still use it
- Migration from Pipeline to router.use()

## Headers

### Type-Safe Headers

- Philosophy: typed vs string-based
- Built-in header types
- Header validation

### Common Headers

- Content-Type
- Authorization (Basic, Bearer)
- Cache-Control
- Cookies
- Host
- Forwarded/X-Forwarded-*

### Custom Headers

- Creating custom header types
- `HeaderCodec` interface
- `HeaderAccessor` pattern
- Extension methods on `Headers`

### Header Transformation

- Immutable by default
- `transform()` method (will likely be renamed soon)
- Adding, updating, removing headers

## WebSockets

### WebSocket Basics

- Built-in WebSocket support
- Upgrading from HTTP to WebSocket
- `ConnectContext` integration

### Working with RelicWebSocket

- Event-based API
- Sending text/binary data
- Receiving messages
- Connection lifecycle

### Error Handling

- Try-variants (`trySendText`, `trySendData`)
- Checking `isClosed`
- Graceful connection closure
- Error recovery patterns

## State Management

### ContextProperty

- Type-safe request-scoped state
- Why not a Map<String, Object>?
- Creating context properties
- Privacy and encapsulation

### Extension Methods Pattern

- Adding typed accessors
- Extension on `RequestContext`
- Discoverability and autocomplete

### Common Use Cases

- User authentication state
- Request-scoped dependencies
- Transaction contexts
- Trace IDs and logging context

## Static Files & Assets

### Serving Static Files

- Static file handler
- Directory structure
- Index files

### Configuration

- Custom cache control
- MIME types
- File listing (security)

### Performance

- Efficient file serving
- Caching strategies
- ETags and conditional requests

## Adapters

### Server Adapters

- What is an adapter?
- `serve()` with dart:io
- `bindHttpServer()`

### Custom Adapters

- Adapter requirements
- Request creation
- Response handling
- Error handling contract

### Platform-Specific Considerations

- Native (dart:io)
- Web (future consideration)
- Testing adapters

## Testing

### Testing Handlers

- Creating test requests
- Mocking context
- Asserting responses

### Testing Middleware

- Testing transformation
- Verifying handler calls
- Pipeline testing

### Testing Routers

- Route matching verification
- Parameter extraction testing
- PathMiss/MethodMiss scenarios

### Integration Testing

- Full server testing
- HTTP client testing
- WebSocket testing

## Performance & Best Practices

### Performance Features

- Built-in optimizations overview
- Uint8List vs List<int>
- Path normalization caching
- Trie-based routing efficiency

### Best Practices

- Efficient middleware ordering
- Avoiding blocking operations
- Stream handling best practices
- Memory management

### Benchmarking

- Measuring performance
- Comparing to Shelf
- Profiling your application

## Migration from Shelf

### Should You Migrate?

- Benefits of migration
- Breaking changes overview
- Effort estimation

### Step-by-Step Migration Guide

- Handler signature changes
- Context vs Request
- Header API migration
- Router migration
- Middleware updates
- WebSocket migration

### Common Migration Patterns

- Request.change() → copyWith()
- Context bag → ContextProperty
- shelf_router → Relic Router
- shelf_web_socket → built-in WebSockets

### Migration Checklist

- Dependencies
- Type safety updates
- Testing verification
- Performance validation

## Advanced Topics

### Error Handling Patterns

- Global error handlers
- Error middleware
- Error responses
- Logging and monitoring

### Security

- HTTPS/TLS
- CORS configuration
- Security headers
- Input validation
- Rate limiting

### Deployment

- Production considerations
- Reverse proxies
- Load balancing
- Monitoring and logging

### Extending Relic

- Plugin architecture
- Custom middleware ecosystem
- Contributing extensions

## API Reference

### Core Types

- Handler, Middleware, Pipeline
- Request, Response, Body
- RequestContext and subtypes

### Router API

- Router class
- Route registration methods
- LookupResult types

### Headers API

- Headers class
- Built-in header types
- HeaderCodec interface

### WebSocket API

- RelicWebSocket
- WebSocket events
- Connection management

## Examples & Recipes

### Common Patterns

- REST API server
- GraphQL server integration
- File upload handling
- Server-sent events
- Authentication flows

### Complete Examples

- Blog API
- Real-time chat (WebSocket)
- Microservice template
- API gateway pattern

## Community & Support

### Getting Help

- GitHub issues
- Discussions
- Stack Overflow tags

### Contributing

- Code of Conduct
- Contribution guidelines
- Testing requirements (BDD/Given-When-Then)
- PR process

### Changelog

- Version history
- Migration notes per version
- Breaking changes

## Appendices

### History & Philosophy

- "A Relic on a Shelf" (origin story)
- Design decisions
- Relationship to Serverpod

### Comparison Matrix

- Relic vs Shelf feature comparison
- Performance benchmarks
- API differences table

### Glossary

- Terms and definitions
- HTTP concepts
- Relic-specific terminology

### Troubleshooting

- Common issues
- FAQ
- Debug strategies

---

# Documentation Organization Notes

## Navigation Structure

- Getting Started: New users, quick wins
- Guides: Learning core features
- Advanced: Deeper topics
- Reference: API documentation
- Resources: Examples, community, appendices

## Progressive Disclosure

- Start simple (Quick Start)
- Build concepts progressively
- Advanced topics separated but linked
- Cross-references throughout

## Documentation Tone

- Clear, concise, practical
- Code examples for every concept
- "Why" alongside "How"
- Compare to Shelf where helpful for migration

## Maintenance Considerations

- Versioned documentation (using Docusaurus versions)
- Redirects for moved pages
- Changelog integration
- API docs auto-generated from source

## Interactive Elements

- Live code examples (where possible)
- Interactive router testing
- Copy-paste ready snippets
- Troubleshooting decision trees

## Search Optimization

- Clear headings
- Consistent terminology
- Keywords in first paragraph
- Cross-linking related topics
