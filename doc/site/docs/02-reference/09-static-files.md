---
sidebar_position: 9
---

# Static files

Most web apps send some files exactly as they are on disk: images, style sheets, scripts, a favicon. A handler could read each file and wrap it in a `Body`, but then it would also have to choose the content type, answer HEAD, support caching, and make sure that a request for `../../etc/passwd` cannot leave the directory. `StaticHandler` does all of that. Point it at a directory, and route a tail segment to it:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/static_files.dart" doctag="static-files-dir-serve" title="Serving a directory"

The tail segment `/basic/**` matches any path below `/basic`, and the handler looks up the rest of the path, its `remainingPath`, in the directory. A GET route is enough, since it answers HEAD requests too. The example directory, `_static_files`, holds a text file and an image, so `/basic/hello.txt` and `/basic/logo.svg` both exist. Ask for the text file:

```bash
curl -i http://localhost:8080/basic/hello.txt
```

```text
HTTP/1.1 200 OK
last-modified: Sat, 07 Feb 2026 13:51:21 GMT
cache-control: max-age=86400
accept-ranges: bytes
date: Fri, 23 Oct 2026 12:10:39 GMT
content-length: 9
etag: "6cb65f8d93fd9c4afe283092b9c3f74cafc04e33"
content-type: text/plain; charset=utf-8

Hello! :)
```

The handler wrote most of those headers. `content-type` comes from the file's name, `.txt` here, and its first bytes, which the handler checks against known file signatures. `cache-control` is what the example's `cacheControl` function returned, and it lets a browser keep the file for a day, 86400 seconds, before it asks again. `last-modified` is the file's modification time, and `etag` is a fingerprint of its content, a SHA-1 hash. `accept-ranges` announces that a client may ask for part of the file.

## Caching and ranges

The `etag` is what makes revalidation cheap. A browser that has the file sends the tag back in an `If-None-Match` header, and when the file has not changed, the handler answers without a body:

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'If-None-Match: "6cb65f8d93fd9c4afe283092b9c3f74cafc04e33"' \
  http://localhost:8080/basic/hello.txt
```

```text
304
```

A 304, Not Modified, tells the browser to use the copy it has. The handler also accepts `If-Modified-Since` with a date, which works the same way with `last-modified`.

A client can ask for a range of bytes, as a download manager resuming a large file does. curl's `-r` option sends a `Range` header:

```bash
curl -i -r 0-4 http://localhost:8080/basic/hello.txt
```

```text
HTTP/1.1 206 Partial Content
last-modified: Sat, 07 Feb 2026 13:51:21 GMT
cache-control: max-age=86400
accept-ranges: bytes
date: Fri, 23 Oct 2026 12:10:39 GMT
content-length: 5
etag: "6cb65f8d93fd9c4afe283092b9c3f74cafc04e33"
content-type: text/plain; charset=utf-8
content-range: bytes 0-4/9

Hello
```

The answer is 206, Partial Content, with the first five bytes, and `content-range` says which part of the nine bytes they are.

## A single file

For one file at a fixed path, such as a logo or `robots.txt`, use `StaticHandler.file`, which needs no tail segment:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/static_files.dart" doctag="static-files-single-file" title="Serving a single file"

Its `cacheControl` function gives this file an hour, and its type is found the same way:

```text
cache-control: max-age=3600
content-type: image/svg+xml
```

## How long to cache

The `cacheControl` function decides the `cache-control` header for each file it serves. The example mounts the same directory three times, with three policies. The first is the one-day policy above. The second caches for an hour, and marks the file as public:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/static_files.dart" doctag="static-files-cache-short" title="An hour, in public caches too"

```text
cache-control: public, max-age=3600
```

`public` allows shared caches, such as a CDN or a proxy, to keep the file as well as the browser. The third caches for a year, and adds `immutable`:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/static_files.dart" doctag="static-files-cache-long-immutable" title="A year, never revalidated"

```text
cache-control: immutable, public, max-age=31536000
```

`immutable` tells the browser not to revalidate the file at all while it is fresh, not even when the user reloads the page. That is only safe for a file whose content never changes under the same URL, which is where cache busting comes in.

## Cache busting

Cache busting puts a fingerprint of a file's content into its URL. When the file changes, so does the URL, and a browser that cached the old file for a year simply asks for the new URL. `CacheBustingConfig` makes such URLs, and the handler that is given the same config serves them:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/static_files.dart" doctag="static-files-cache-busting" title="Cache-busted URLs"

`buster.assetPath('/static/hello.txt')` returns the path with the fingerprint added before the extension. The index page of the example shows both:

```bash
curl http://localhost:8080/
```

```text
<html><body><h1>Static files with cache busting</h1><ul><li><a href="/static/hello@6cb65f8d93fd9c4afe283092b9c3f74cafc04e33.txt">hello.txt</a></li><li><img src="/static/logo@d20043bb7e6aa8463405c910e034b7c31a612ff2.svg" alt="logo" height="64" /></li></ul></body></html>
```

The fingerprint after the `@` is the same SHA-1 hash as the file's `etag`. A request for that URL gets the file with the one-year, immutable policy. Edit `hello.txt`, and the next page lists a new URL.

## What the handler will serve

A request that tries to climb out with `..` never reaches the handler. The router normalizes the path before it routes, whether the dots are written out or encoded as `%2e%2e`, so this request is routed as `/static_files.dart`, which matches no route:

```bash
curl -i --path-as-is http://localhost:8080/basic/../static_files.dart
```

```text
HTTP/1.1 404 Not Found
```

`StaticHandler` guards the directory on its own too. It resolves the file it is about to serve, symbolic links included, and answers 404 when the file is outside its directory, so a link inside the directory that points out of it serves nothing. Inside the directory, though, it serves every file, and it does not filter by name. Dot files such as `.env`, and the contents of a `.git` directory, are reachable like any other file. Serve a directory that holds only public assets, rather than a project or build root that happens to contain them.

## Examples & further reading

### Examples

- **[Static files example](https://github.com/serverpod/relic/blob/main/packages/examples/basic/static_files.dart)** - The program behind this page.

### API documentation

- [StaticHandler class](https://pub.dev/documentation/relic/latest/relic/StaticHandler-class.html) - Static file serving handler.
- [CacheBustingConfig class](https://pub.dev/documentation/relic/latest/relic/CacheBustingConfig-class.html) - Cache busting configuration.
- [CacheControlHeader class](https://pub.dev/documentation/relic/latest/relic/CacheControlHeader-class.html) - Cache control header handling.

### Further reading

- [HTTP caching](https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching) - Mozilla documentation on HTTP caching.
- [Cache-Control header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control) - Mozilla documentation on Cache-Control.
- [ETag header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag) - Mozilla documentation on ETags.
