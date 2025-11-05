---
sidebar_position: 9
---

# Static files

Static file serving is essential for web applications that need to deliver assets like images, CSS, JavaScript, documents, or other resources. Relic provides a powerful `StaticHandler` that automatically handles MIME types, caching headers, security, and advanced features like cache busting.

## Basic directory serving

To serve static files from a directory, use `StaticHandler.directory()`:

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/advanced/static_files_example.dart) doctag="static-files-dir-serve" title="static_files_example.dart"

**What this code does:**

1. **HTTP Methods**: `anyOf({Method.get, Method.head}, ...)` handles both GET and HEAD requests, which is standard for static file serving.
2. **Path Pattern**: `/basic/**` uses a tail matching pattern where `**` captures the remaining path segments to determine which file to serve.
3. **Static Handler**: `StaticHandler.directory()` creates a handler that serves files from the specified directory with automatic MIME type detection.
4. **Cache Control**: Sets a cache duration of 86400 seconds (1 day), instructing browsers and CDNs to cache the files.

This serves all files from the `static_files` directory under `/basic/` URLs with 1-day caching. For example:

- `static_files/hello.txt` → `http://localhost:8080/basic/hello.txt`
- `static_files/logo.svg` → `http://localhost:8080/basic/logo.svg`

## Single file serving

For serving individual files, use `StaticHandler.file()`:

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/advanced/static_files_example.dart) doctag="static-files-single-file" title="static_files_example.dart"

This is useful for specific files like logos, favicons, robots.txt, or other well-known resources.

## Cache control strategies

Effective caching is crucial for static file performance. Relic provides flexible cache control options:

### Short-term caching

For files that might change frequently:

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/advanced/static_files_example.dart) doctag="static-files-cache-short" title="static_files_example.dart"

### Long-term caching with immutable assets

For assets that never change (like versioned files):

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/advanced/static_files_example.dart) doctag="static-files-cache-long-immutable" title="static_files_example.dart"

## Cache busting

Cache busting ensures browsers fetch updated files when your assets change. Relic provides built-in cache busting support:

GITHUB_CODE_BLOCK lang="dart" [src](https://raw.githubusercontent.com/serverpod/relic/main/example/advanced/static_files_example.dart) doctag="static-files-cache-busting" title="static_files_example.dart"

**How cache busting works:**

1. **Configure cache busting** (see the `CacheBustingConfig` instantiation): `CacheBustingConfig` generates unique URLs based on file content hashes.
2. **Generate cache-busted URLs** (see usage of `buster.assetPath(...)`): `buster.assetPath('/static/hello.txt')` returns something like `/static/hello@6cb65f8d93fd9c4afe283092b9c3f74cafc04e33.txt`.
3. **Serve with aggressive caching** (see cache control settings for cache busted serving): Use long cache durations (1 year) with `immutable: true` because the URL changes when content changes.
4. When the file changes, the hash changes, forcing browsers to fetch the new version.

## Security considerations

`StaticHandler` includes built-in security features:

- **Path traversal protection**: Prevents access to files outside the specified directory
- **Hidden file protection**: Blocks access to files starting with `.` (like `.env`, `.git`)
- **Symbolic link handling**: Safely resolves symbolic links within the allowed directory

These protections are automatically applied and ensure that your static file handler only serves files from the intended directory.

:::tip Directory paths
When serving static files from a directory, always use a tail matching path pattern (`/**`) to capture all files and subdirectories. The tail portion (`/**`) is used to determine the file path within the directory. Without it, the handler won't know which file to serve.

For single file serving with `StaticHandler.file()`, you don't need the tail pattern, but it can be useful for SPAs or other routing scenarios.
:::

## Examples

- **[`static_files_example.dart`](https://github.com/serverpod/relic/blob/main/example/advanced/static_files_example.dart)** - Complete example with cache busting
