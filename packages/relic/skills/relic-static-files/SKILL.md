---
name: relic-static-files
description: Serve static files and directories with caching and cache busting in Relic. Use when serving assets, images, CSS, JS, favicons, or configuring HTTP cache control headers.
---

# Relic Static Files

`StaticHandler` serves files with automatic MIME type detection, cache headers, and built-in security (path traversal protection, hidden file blocking, symlink safety).

## Serve a directory

Use a tail pattern (`/**`) so the handler knows which file to serve:

```dart
app.anyOf(
  {Method.get, Method.head},
  '/static/**',
  StaticHandler.directory(
    Directory('public'),
    cacheControl: (req, fileInfo) => CacheControlHeader(maxAge: 86400),
  ).asHandler,
);
// public/style.css → http://localhost:8080/static/style.css
```

## Serve a single file

```dart
app.get(
  '/logo.svg',
  StaticHandler.file(
    File('assets/logo.svg'),
    cacheControl: (req, fileInfo) => CacheControlHeader(maxAge: 3600),
  ).asHandler,
);
```

## Cache control strategies

### Short-term (frequently updated content)

```dart
StaticHandler.directory(
  dir,
  cacheControl: (req, fileInfo) => CacheControlHeader(
    maxAge: 3600,        // 1 hour
    publicCache: true,   // allow CDN/proxy caching
  ),
).asHandler
```

### Long-term immutable (versioned assets)

```dart
StaticHandler.directory(
  dir,
  cacheControl: (req, fileInfo) => CacheControlHeader(
    maxAge: 31536000,    // 1 year
    publicCache: true,
    immutable: true,     // browsers never revalidate
  ),
).asHandler
```

## Cache busting

Generates unique URLs based on file content hashes. When file content changes, the hash changes, forcing browsers to fetch the new version.

```dart
final buster = CacheBustingConfig(
  mountPrefix: '/static',
  fileSystemRoot: Directory('public'),
);

// Generate cache-busted URLs (e.g., /static/hello@6cb65f8d.txt)
app.get('/', respondWith((req) async {
  final cssUrl = await buster.assetPath('/static/style.css');
  final html = '<link rel="stylesheet" href="$cssUrl">';
  return Response.ok(body: Body.fromString(html, mimeType: MimeType.html));
}));

// Serve with aggressive caching (safe because URL changes on content change)
app.anyOf(
  {Method.get, Method.head},
  '/static/**',
  StaticHandler.directory(
    Directory('public'),
    cacheControl: (req, fileInfo) => CacheControlHeader(
      maxAge: 31536000,
      publicCache: true,
      immutable: true,
    ),
    cacheBustingConfig: buster,
  ).asHandler,
);
```

## Security

These protections are applied automatically:

- **Path traversal** -- blocks `../` attempts to escape the served directory.
- **Hidden files** -- blocks files starting with `.` (e.g., `.env`, `.git`).
- **Symbolic links** -- safely resolved within the allowed directory.
