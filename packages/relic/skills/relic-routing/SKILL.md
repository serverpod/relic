---
name: relic-routing
description: Define routes with path parameters, wildcards, tail segments, and typed params in Relic. Use when adding endpoints, handling dynamic URLs, setting up URL patterns, or forwarding requests.
---

# Relic Routing

Routes map incoming requests to handlers based on path and HTTP method. Register routes on `RelicApp` (which implements `RelicRouter`).

## Handler signature

```dart
typedef Handler = FutureOr<Result> Function(Request req);
```

A handler returns a `Result`: either a `Response`, `WebSocketUpgrade`, or `Hijack`.

## Registering routes

```dart
final app = RelicApp()
  ..get('/', (req) => Response.ok(body: Body.fromString('Hello World!')))
  ..post('/', (req) => Response.ok(body: Body.fromString('Got POST')))
  ..put('/user', (req) => Response.ok(body: Body.fromString('PUT /user')))
  ..delete('/user', (req) => Response.ok(body: Body.fromString('DELETE /user')));
```

### Core `add` method

The convenience methods call `add()` internally:

```dart
app.add(Method.patch, '/api', (req) {
  return Response.ok(body: Body.fromString('PATCH /api'));
});
```

### Multiple methods

```dart
app.anyOf({Method.get, Method.post}, '/admin', (req) {
  return Response.ok(body: Body.fromString('Admin - ${req.method.name}'));
});

app.any('/wildcard', handler); // all HTTP methods
```

## Path parameters

Use `:name` to capture a segment. Access with `Symbol`-based key:

```dart
app.get('/users/:id', (Request req) {
  final userId = req.pathParameters.raw[#id];
  return Response.ok(body: Body.fromString('User $userId'));
});
```

### Typed path parameters

Define typed accessors for automatic parsing:

```dart
const idParam = IntPathParam(#id);
const latParam = DoublePathParam(#lat);
const lonParam = DoublePathParam(#lon);

app.get('/users/:id', (Request req) {
  final userId = req.pathParameters.get(idParam); // int
  return Response.ok(body: Body.fromString('User $userId'));
});

app.get('/location/:lat/:lon', (Request req) {
  final lat = req.pathParameters.get(latParam); // double
  final lon = req.pathParameters.get(lonParam); // double
  return Response.ok(body: Body.fromString('Location: $lat, $lon'));
});
```

Nullable variant (returns `null` if missing):

```dart
final userId = req.pathParameters(idParam); // int?
```

Built-in accessors: `IntPathParam`, `DoublePathParam`, `NumPathParam`.

### Custom path parameter type

```dart
const statusParam = PathParam<Status>(#status, Status.parse);
const dateParam = PathParam<DateTime>(#date, DateTime.parse);
```

Reusable specialization:

```dart
final class DateTimePathParam extends PathParam<DateTime> {
  const DateTimePathParam(Symbol key) : super(key, DateTime.parse);
}

const dateParam = DateTimePathParam(#date);
```

## Wildcards

`*` matches any single segment without capturing:

```dart
app.get('/files/*/download', (req) {
  return Response.ok(body: Body.fromString('Downloading...'));
});
```

## Tail segments

`/**` captures the entire remaining path, exposed via `request.remainingPath`:

```dart
app.get('/static/**', (req) {
  final path = req.remainingPath.toString();
  return Response.ok(body: Body.fromString('Serve $path'));
});
```

Required when serving directories so the handler knows which file was requested.

## Route priority

1. Literal segments take priority over dynamic segments.
2. Backtracking ensures the best match if a literal leads to a dead end.
3. Registration order does not affect matching.

```dart
app.get('/:entity/:id', entityHandler);
app.get('/users/:id/profile', profileHandler);
```

Request for `/users/789`: tries literal `users` path first (Route 2), needs third segment `/profile` but path ends -- backtracks to `:entity` parameter (Route 1) with `entity=users`, `id=789`.

Tail segments with specific routes:

```dart
app.get('/files/**', catchAllHandler);
app.get('/files/special/report', reportHandler);
```

`/files/special/report` matches the exact route; `/files/special/other` falls back to catch-all.

## Request forwarding

Re-route a request through the same router with `copyWith` + `forwardTo`:

```dart
app.get('/v1/users', (req) {
  final newReq = req.copyWith(url: req.url.replace(path: '/v2/users'));
  return req.forwardTo(newReq);
});

app.get('/v2/users', (req) {
  return Response.ok(body: Body.fromString('Users list'));
});
```

`forwardTo` sends the new request through the full routing pipeline including middleware. It throws `StateError` if the request was not routed through a `RelicRouter`.
