---
sidebar_position: 2
---

# Context properties

The [Middleware](./08-middleware.md) page has an API key check that answers 401 to callers it doesn't know. Once a middleware like that has decided who is calling, the handler usually wants to know too. But a handler receives nothing except the `Request`, so whatever the middleware learned has to travel on the request. A context property is a typed slot on every request, made for exactly that.

## A property for the current user

Define the property once, at the top level, with the type of the value it holds:

GITHUB_CODE_BLOCK lang="dart" file="../_example/context/context_property.dart" doctag="context-prop-define" title="A property that holds a User"

The middleware looks up the API key, and when it knows the caller, it stores a `User` in the property:

GITHUB_CODE_BLOCK lang="dart" file="../_example/context/context_property.dart" doctag="context-prop-set" title="Setting the property"

`userProperty[req] = User(name)` sets the value for this request alone. The handler reads it back with `get`:

GITHUB_CODE_BLOCK lang="dart" file="../_example/context/context_property.dart" doctag="context-prop-get" title="Reading the property"

`get` returns a `User`, not a `User?` or an `Object`. The type of the property carries through, so the handler needs no cast and no null check. The program puts the middleware on `/api`:

GITHUB_CODE_BLOCK lang="dart" file="../_example/context/context_property.dart" doctag="context-prop-app" title="The routes"

Two keys get two answers:

```bash
curl -H 'X-API-Key: key-alice' http://localhost:8080/api/me
curl -H 'X-API-Key: key-bob' http://localhost:8080/api/me
```

```text
You are Alice
You are Bob
```

Requests can be in flight at the same time, and each one sees its own user. That is why the value lives on the request rather than in a global variable, which a second request could overwrite before the first one had read it.

## When no value was set

The program also registers `whoAmI` on `/me`, outside `/api`, where the middleware does not run. Nothing sets the property for that request, and `get` throws:

```bash
curl -i http://localhost:8080/me
```

```text
HTTP/1.1 500 Internal Server Error
content-type: text/plain; charset=utf-8
date: Fri, 23 Oct 2026 11:54:45 GMT
content-length: 21

Internal Server Error
```

The server log names the property that was missing:

```text
Bad state: ContextProperty value not found. Property: user. Ensure middleware has set this value for the request.
```

That name is the string passed when the property was created. Without one, the message names the type instead, `User`, which says just as much until two properties hold the same type.

When a missing value is normal, read the property with the index operator, which returns null instead of throwing. A small extension on `Request` makes such reads look like any other request field:

GITHUB_CODE_BLOCK lang="dart" file="../_example/context/context_property.dart" doctag="context-prop-extension" title="An optional user"

`/hello` is outside `/api` too, and gets the default:

```text
Hello, stranger
```

## Rules for properties

Create each property once, as a top-level or static `final`, as `userProperty` is here. A property claims a slot on every request for the life of the isolate. One created inside a handler would claim a new slot on every request, and debug builds stop that with an assertion after 1024 properties.

A value lives as long as its request. Assigning `null` removes it. A copy of the request made with `copyWith` shares its properties with the original, so a value set on either one is visible on both.

## Properties that Relic sets

Relic uses the same mechanism for what routing learns about a request. The routing middleware sets the raw path parameters, the router and the matched path, and the typed parameter accessors are built from them on first read:

- `request.rawPathParameters` - the path parameters of the matched route, as strings.
- `request.pathParameters` - typed accessors over `rawPathParameters`.
- `request.queryParameters` - typed accessors over the query of the URL.
- `request.router` - the `RelicRouter` that routed the request, which `forwardTo` uses.
- `request.matchedPath` and `request.remainingPath` - the part of the path the route matched, and the rest.

## Examples & further reading

### Examples

- **[Context property example](https://github.com/serverpod/relic/blob/main/packages/examples/context/context_property.dart)** - The program behind this page.

### API documentation

- [ContextProperty class](https://pub.dev/documentation/relic/latest/relic/ContextProperty-class.html) - Typed request-scoped data.
- [Request class](https://pub.dev/documentation/relic/latest/relic/Request-class.html) - HTTP request object that holds context properties.
