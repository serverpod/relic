---
sidebar_position: 9
---

# Static files

Static file serving is essential for web applications that need to deliver assets like images, CSS, JavaScript, documents, or other resources. Relic provides a powerful `StaticHandler` that automatically handles MIME types, caching headers, security, and advanced features like cache busting.

## Basic directory serving

To serve static files from a directory, use `StaticHandler.directory()`:

```dart
import 'dart:io';
import 'package:relic/relic.dart';

final app = RelicApp()
  ..anyOf(
    {Method.get, Method.head},
    '/static/**',
    StaticHandler.directory(
      Directory('static_files'),
      cacheControl: (ctx, fileInfo) => CacheControlHeader(maxAge: 86400),
    ).asHandler);
```

This serves all files from the `static_files` directory under `/static/` URLs with 1-day caching. For example:

- `static_files/hello.txt` → `http://localhost:8080/static/hello.txt`
- `static_files/logo.svg` → `http://localhost:8080/static/logo.svg`

## Single file serving

For serving individual files, use `StaticHandler.file()`:

```dart
final app = RelicApp()
  ..get('/logo.svg', StaticHandler.file(
    File('static_files/logo.svg'),
    cacheControl: (ctx, fileInfo) => CacheControlHeader(maxAge: 3600),
  ).asHandler);
```

This is useful for specific files like logos, favicons, robots.txt, or other well-known resources.

## Cache control strategies

Effective caching is crucial for static file performance. Relic provides flexible cache control options:

### Short-term caching

For files that might change frequently:

```dart
StaticHandler.directory(
  Directory('static_files'),
  cacheControl: (ctx, fileInfo) => CacheControlHeader(
    maxAge: 3600,        // 1 hour
    publicCache: true,   // Allow CDN caching
  ),
)
```

### Long-term caching with immutable assets

For assets that never change (like versioned files):

```dart
StaticHandler.directory(
  Directory('static_files'),
  cacheControl: (ctx, fileInfo) => CacheControlHeader(
    maxAge: 31536000,    // 1 year
    publicCache: true,
    immutable: true,     // Browser won't revalidate
  ),
)
```

## Cache busting

Cache busting ensures browsers fetch updated files when your assets change. Relic provides built-in cache busting support:

```dart
final staticDir = Directory('static_files');

// Configure cache busting
final buster = CacheBustingConfig(
  mountPrefix: '/static',
  fileSystemRoot: staticDir,
);

final app = RelicApp()
  // Serve static files with cache busting
  ..anyOf(
    {Method.get, Method.head},
    '/static/**',
    StaticHandler.directory(
      staticDir,
      cacheControl: (ctx, fileInfo) => CacheControlHeader(
        maxAge: 31536000,  // 1 year - safe with cache busting
        publicCache: true,
        immutable: true,
      ),
      cacheBustingConfig: buster,
    ).asHandler,
  );
```

**How cache busting works:**

1. `CacheBustingConfig` generates unique URLs based on file content hashes
2. `buster.assetPath('/static/hello.txt')` returns something like `/static/hello.txt?v=abc123`
3. When the file changes, the hash changes, forcing browsers to fetch the new version
4. You can use aggressive caching (1 year) because the URL changes when content changes

## Security considerations

`StaticHandler` includes built-in security features:

- **Path traversal protection**: Prevents access to files outside the specified directory
- **Hidden file protection**: Blocks access to files starting with `.` (like `.env`, `.git`)
- **Symbolic link handling**: Safely resolves symbolic links within the allowed directory

### Custom security rules

You can add additional security checks:

```dart
StaticHandler.directory(
  Directory('static_files'),
  // Custom file filter for additional security
  fileFilter: (file) {
    final name = file.path.split('/').last;
    
    // Block backup files and sensitive extensions
    if (name.endsWith('.bak') || 
        name.endsWith('.tmp') || 
        name.endsWith('.env')) {
      return false;
    }
    
    return true;
  },
)
```

:::tip Directory paths
When serving static files from a directory, always use a tail matching path pattern (`/**`) to capture all files and subdirectories. The tail portion (`/**`) is used to determine the file path within the directory. Without it, the handler won't know which file to serve.

For single file serving with `StaticHandler.file()`, you don't need the tail pattern, but it can be useful for SPAs or other routing scenarios.
:::

## Examples

- **[Static Files Example](https://github.com/serverpod/relic/blob/main/example/static_files_example.dart)** - Complete example with cache busting
