---
name: relic-request-response
description: Handle HTTP requests and create responses with Body, headers, and status codes in Relic. Use when reading request data, parsing JSON, building API responses, working with headers, or streaming content.
---

# Relic Requests & Responses

## Request object

Every handler receives a `Request` with these key properties:

- `method` -- `Method` enum (`Method.get`, `Method.post`, etc.)
- `url` -- full original URI
- `headers` -- type-safe header access
- `body` -- `Body` wrapper (single-read stream)
- `pathParameters` -- route parameters set by routing
- `queryParameters` -- query string parameters

`Request.headers` is immutable. `Request.body` is mutable (middleware may replace it), but the underlying stream can only be read once.

## Query parameters

### Raw access

```dart
app.get('/search', (req) {
  final query = req.queryParameters.raw['query'];
  final page = req.queryParameters.raw['page'];
  return Response.ok(body: Body.fromString('Search: $query, page: $page'));
});
```

### Typed query parameters

```dart
const pageParam = IntQueryParam('page');
const limitParam = IntQueryParam('limit');
const priceParam = DoubleQueryParam('price');

app.get('/products', (req) {
  final page = req.queryParameters.get(pageParam);    // int (throws if missing)
  final limit = req.queryParameters.get(limitParam);   // int
  final maxPrice = req.queryParameters.get(priceParam); // double
  return Response.ok(body: Body.fromString('page=$page limit=$limit price=$maxPrice'));
});
```

Nullable variant:

```dart
final page = req.queryParameters(pageParam); // int? -- null if missing
```

Built-in: `IntQueryParam`, `DoubleQueryParam`, `NumQueryParam`. Custom:

```dart
const sortParam = QueryParam<SortOrder>('sort', SortOrder.parse);
const fromParam = QueryParam<DateTime>('from', DateTime.parse);
```

Reusable specialization:

```dart
final class DateTimeQueryParam extends QueryParam<DateTime> {
  const DateTimeQueryParam(String key) : super(key, DateTime.parse);
}
```

### Multiple values

```dart
app.get('/filter', (req) {
  final tags = req.url.queryParametersAll['tag'] ?? []; // List<String>
  return Response.ok(body: Body.fromString('Tags: $tags'));
});
// GET /filter?tag=dart&tag=server → Tags: [dart, server]
```

## Reading headers

```dart
app.get('/info', (req) {
  final userAgent = req.headers.userAgent;        // String?
  final contentLength = req.headers.contentLength; // int?
  final mimeType = req.mimeType;                   // MimeType?
  // ...
});
```

### Authorization

```dart
app.get('/protected', (req) {
  final auth = req.headers.authorization;

  if (auth is BearerAuthorizationHeader) {
    final token = auth.token;
    return Response.ok(body: Body.fromString('Token: $token'));
  } else if (auth is BasicAuthorizationHeader) {
    final username = auth.username;
    return Response.ok(body: Body.fromString('User: $username'));
  }
  return Response.unauthorized();
});
```

## Reading the request body

The body can only be read once. A second read throws `StateError`.

### As string

```dart
app.post('/submit', (req) async {
  final text = await req.readAsString();
  return Response.ok(body: Body.fromString('Received: $text'));
});
```

### JSON parsing

```dart
app.post('/api/users', (req) async {
  try {
    final body = await req.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final name = data['name'] as String?;
    final email = data['email'] as String?;
    if (name == null || email == null) {
      return Response.badRequest(
        body: Body.fromString(
          jsonEncode({'error': 'Name and email are required'}),
          mimeType: MimeType.json,
        ),
      );
    }

    return Response.ok(
      body: Body.fromString(
        jsonEncode({'message': 'User created', 'name': name}),
        mimeType: MimeType.json,
      ),
    );
  } catch (e) {
    return Response.badRequest(
      body: Body.fromString(jsonEncode({'error': 'Invalid JSON: $e'}), mimeType: MimeType.json),
    );
  }
});
```

### Byte stream

```dart
app.post('/upload', (req) async {
  if (req.isEmpty) {
    return Response.badRequest(body: Body.fromString('Body required'));
  }

  final stream = req.read(); // Stream<Uint8List>
  int totalBytes = 0;
  await for (final chunk in stream) {
    totalBytes += chunk.length;
  }
  return Response.ok(body: Body.fromString('Received $totalBytes bytes'));
});
```

### Size-limited reads

```dart
const maxFileSize = 10 * 1024 * 1024; // 10 MB

final sink = file.openWrite();
try {
  await sink.addStream(req.read(maxLength: maxFileSize));
} on MaxBodySizeExceeded {
  return Response.badRequest(body: Body.fromString('File too large'));
} finally {
  await sink.close();
}
```

## Creating responses

### Status code constructors

```dart
Response.ok(body: Body.fromString('Success'))           // 200
Response.noContent()                                     // 204
Response.badRequest(body: Body.fromString('Bad input'))  // 400
Response.unauthorized()                                  // 401
Response.notFound()                                      // 404
Response.internalServerError()                           // 500
Response(418, body: Body.fromString('I am a teapot'))   // custom
```

### Body types

```dart
// Text (auto-detects MIME: JSON, HTML, XML, or plain text)
Body.fromString('Hello')                                    // text/plain
Body.fromString('{"key": "value"}')                         // application/json
Body.fromString('<!DOCTYPE html><html>...</html>')          // text/html

// Explicit MIME type
Body.fromString('<html>...</html>', mimeType: MimeType.html)
Body.fromString(jsonEncode(data), mimeType: MimeType.json)

// Binary (auto-detects PNG, JPEG, PDF, etc.)
Body.fromData(imageBytes)                                    // image/png, etc.
Body.fromData(data, mimeType: MimeType.octetStream)         // explicit

// Streaming (for large payloads)
Body.fromDataStream(fileStream, contentLength: fileSize)    // known size
Body.fromDataStream(dynamicStream)                          // chunked encoding

// Empty
Body.empty()
```

Encoding defaults to UTF-8. Override with:

```dart
Body.fromString('Café', mimeType: MimeType.plainText, encoding: latin1)
```

### Response headers

```dart
app.get('/api/data', (req) {
  final headers = Headers.build((h) {
    h.cacheControl = CacheControlHeader(maxAge: 3600, publicCache: true);
    h['X-Custom-Header'] = ['value'];
  });

  return Response.ok(
    headers: headers,
    body: Body.fromString(jsonEncode({'status': 'ok'}), mimeType: MimeType.json),
  );
});
```

### HTML response

```dart
app.get('/page', (req) {
  final html = '<!DOCTYPE html><html><body><h1>Welcome</h1></body></html>';
  return Response.ok(body: Body.fromString(html, mimeType: MimeType.html));
});
```

### Streaming response

```dart
app.get('/stream', (req) async {
  Stream<Uint8List> generate() async* {
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(Duration(milliseconds: 50));
      yield utf8.encode('{"item": $i}\n');
    }
  }

  return Response.ok(
    body: Body.fromDataStream(generate(), mimeType: MimeType.json),
  );
});
```

## Modifying requests

`Request` is immutable. Use `copyWith` to create a modified copy:

```dart
final rewritten = request.copyWith(
  url: request.url.replace(path: '/new-path'),
);

final modified = request.copyWith(
  url: request.url.replace(path: '/other'),
  headers: Headers.build((h) => h['X-Custom'] = ['value']),
);
```
