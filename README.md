![Relic web server banner](https://github.com/serverpod/relic/raw/main/misc/images/github-banner.jpg)

<p align="center">
<a href="https://github.com/serverpod/relic/actions"><img src="https://github.com/serverpod/relic/workflows/Relic CI/badge.svg" alt="build"></a>
<a href="https://codecov.io/gh/serverpod/relic"><img src="https://codecov.io/gh/serverpod/relic/branch/main/graph/badge.svg" alt="codecov"></a>
<a href="https://github.com/serverpod/relic"><img src="https://img.shields.io/github/stars/serverpod/relic.svg?style=flat&logo=github&colorB=deeppink&label=stars" alt="Stars on Github"></a>
<a href="https://opensource.org/license/bsd-3-clause"><img src="https://img.shields.io/badge/license/bsd-3-clause.svg" alt="License: BSD-3-Clause"></a>
</p>

# Relic web server

Relic is a web server based on Shelf that supports middleware. It's currently available as a tech preview to gather feedback before we release a stable version. __Beware that the API is still subject to change.__ The best way to provide your feedback is through issues on GitHub here:
[https://github.com/serverpod/relic/issues](https://github.com/serverpod/relic/issues)

This package was born out of the needs of [Serverpod](https://serverpod.dev), as we wanted a more modern and performant base for our web server. Relic is based on [Shelf](https://pub.dev/packages/shelf), but we have made several improvements:

- We removed all `List<int>` in favor of `Uint8List`.
- We made everything type-safe (no more dynamic).
- Encoding types have been moved to the `Body` of a `Request`/`Response` to simplify the logic when syncing up the headers and to have a single source of truth.
- We've added parsers and validation for all commonly used HTTP headers. E.g., times are represented by `DateTime`, cookies have their own class with validation of formatting, etc.
- Routing has been implemented using a [trie](https://en.wikipedia.org/wiki/Trie) data-structure (`PathTrie`) for efficient route matching and parameter extraction.
- Extended test coverage.
- There are lots of smaller fixes here and there.

Although the structure is very similar to Shelf, this is no longer backward compatible. We like to think that a transition would be pretty straightforward, and we are planning put a guide in place.

Before a stable release, we're also planning on adding the following features:
- We want to more tightly integrate a http server (i.e., start with `HttpServer` from `dart:io` as a base) with Relic so that everything uses the same types. This will also improve performance as fewer conversions will be needed.
- We're planning to add an improved testing framework.
- Performance testing and optimizations.

In addition, we're planning to include Relic in [Serverpod](https://serverpod.dev), both for powering our RPC and as a base for our web server. This would add support for middleware in our RPC. In our web server integration, we have support for HTML templates and routing. You also get access to the rest of the Serverpod ecosystem in terms of serialization, caching, pub-sub, and database integrations.

## Example

See `relic/example/example.dart` for a runnable example. The following code demonstrates basic routing and request handling:

```dart
import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// A simple 'Hello World' server
Future<void> main() async {
  // Setup router
  final router = Router<Handler>()..get('/user/:name/age/:age', hello);

  // Setup a handler.
  //
  // A [Handler] is function consuming and producing [RequestContext]s,
  // but if you are mostly concerned with converting [Request]s to [Response]s
  // (known as a [Responder] in relic parlor) you can use [respondWith] to
  // wrap a [Responder] into a [Handler]
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(routeWith(router))
      .addHandler(respondWith((final _) => Response.notFound(
          body: Body.fromString("Sorry, that doesn't compute"))));

  // Start the server with the handler
  await serve(handler, InternetAddress.anyIPv4, 8080);

  print('Serving at http://localhost:8080');
  // Check the _example_ directory for other examples.
}

ResponseContext hello(final RequestContext ctx) {
  final name = ctx.pathParameters[#name];
  final age = int.parse(ctx.pathParameters[#age]!);

  return (ctx as RespondableContext).respond(Response.ok(
      body: Body.fromString('Hello $name! To think you are $age years old.')));
}
```

## Security

### Error Message Sanitization

Relic provides built-in protection against information leakage through error messages. The server will always return generic error messages instead of potentially exposing sensitive information from request bodies or application state.

```dart
// Secure error handling is always enabled
await serve(
  handler, 
  InternetAddress.anyIPv4, 
  8080,
);
```

This feature is particularly important when handling JSON parsing errors or other exceptions that might reflect user input back to the client, which can cause false positives in security scanners.

See `example/secure_error_handling.dart` for a complete example.

## Handlers and Middleware

A [Handler][] is any function that handles a [Request][] and returns a
[Response][]. It can either handle the request itself–for example, a static file
server that looks up the requested URI on the filesystem–or it can do some
processing and forward it to another handler–for example, a logger that prints
information about requests and responses to the command line.

[handler]: https://pub.dev/documentation/relic/latest/relic/Handler.html
[request]: https://pub.dev/documentation/relic/latest/relic/Request-class.html
[response]: https://pub.dev/documentation/relic/latest/relic/Response-class.html

The latter kind of handler is called "[middleware][]", since it sits in the
middle of the server stack. Middleware can be thought of as a function that
takes a handler and wraps it in another handler to provide additional
functionality. A Shelf application is usually composed of many layers of
middleware with one or more handlers at the very center; the [Pipeline][] class
makes this sort of application easy to construct.

[middleware]: https://pub.dev/documentation/relic/latest/relic/Middleware.html
[pipeline]: https://pub.dev/documentation/relic/latest/relic/Pipeline-class.html

Some middleware can also take multiple handlers and call one or more of them for
each request. For example, a routing middleware might choose which handler to
call based on the request's URI or HTTP method, while a cascading middleware
might call each one in sequence until one returns a successful response.

Middleware that routes requests between handlers should be sure to update each
request's [`handlerPath`][handlerpath] and [`url`][url]. This allows inner
handlers to know where they are in the application so they can do their own
routing correctly. This can be easily accomplished using
[`Request.copyWith()`][change]:

[handlerpath]:
  https://pub.dev/documentation/relic/latest/relic/Request/handlerPath.html
[url]: https://pub.dev/documentation/relic/latest/relic/Request/url.html
[change]: https://pub.dev/documentation/relic/latest/relic/Request/copyWith.html

```dart
// In an imaginary routing middleware...
var component = request.url.pathSegments.first;
var handler = _handlers[component];
if (handler == null) return Response.notFound();

// Create a new request just like this one but with whatever URL comes after
// [component] instead.
return handler(request.copyWith(path: component));
```

## Adapters

An adapter is any code that creates [Request][] objects, passes them to a
handler, and deals with the resulting [Response][]. For the most part, adapters
forward requests from and responses to an underlying HTTP server;
[serve][] is this sort of adapter. An adapter might also synthesize
HTTP requests within the browser using `window.location` and `window.history`,
or it might pipe requests directly from an HTTP client to a Shelf handler.

[serve]: https://pub.dev/documentation/relic/latest/relic/serve.html

### API Requirements

An adapter must handle all errors from the handler, including the handler
returning a `null` response. It should print each error to the console if
possible, then act as though the handler returned a 500 response. The adapter
may include body data for the 500 response, but this body data must not include
information about the error that occurred. This ensures that unexpected errors
don't result in exposing internal information in production by default; if the
user wants to return detailed error descriptions, they should explicitly include
middleware to do so.

An adapter should ensure that asynchronous errors thrown by the handler don't
cause the application to crash, even if they aren't reported by the future
chain. Specifically, these errors shouldn't be passed to the root zone's error
handler; however, if the adapter is run within another error zone, it should
allow these errors to be passed to that zone. The following function can be used
to capture only errors that would otherwise be top-leveled:

```dart
/// Run [callback] and capture any errors that would otherwise be top-leveled.
///
/// If `this` is called in a non-root error zone, it will just run [callback]
/// and return the result. Otherwise, it will capture any errors using
/// [runZoned] and pass them to [onError].
void catchTopLevelErrors(
  void Function() callback,
  void Function(Object error, StackTrace stackTrace) onError,
) {
  if (Zone.current.inSameErrorZone(Zone.root)) {
    return runZonedGuarded(callback, onError);
  } else {
    return callback();
  }
}
```

An adapter that knows its own URL should provide an implementation of the
[`RelicServer`][server] interface.

[server]: https://pub.dev/documentation/relic/latest/relic/RelicServer-class.html

### Request Requirements

If the underlying request uses a chunked transfer coding, the adapter must
decode the body before passing it to [Request][] and should remove the
`Transfer-Encoding` header. This ensures that message bodies are chunked if and
only if the headers declare that they are.

### Response Requirements

An adapter must not add or modify any [entity headers][] for a response.

[entity headers]: https://www.w3.org/Protocols/rfc2616/rfc2616-sec7.html#sec7.1

If _none_ of the following conditions are true, the adapter must apply [chunked
transfer coding][] to a response's body and set its Transfer-Encoding header to
`chunked`:

- The status code is less than 200, or equal to 204 or 304.
- A Content-Length header is provided.
- The Content-Type header indicates the MIME type `multipart/byteranges`.
- The Transfer-Encoding header is set to anything other than `identity`.

[chunked transfer coding]:
  https://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.6.1

Adapters may find the [`addChunkedEncoding()`][addchunkedencoding] middleware
useful for implementing this behavior, if the underlying server doesn't
implement it manually.

[addchunkedencoding]:
  https://pub.dev/documentation/shelf/latest/shelf/addChunkedEncoding.html

When responding to a HEAD request, the adapter must not emit an entity body.
Otherwise, it shouldn't modify the entity body in any way.

An adapter should include information about itself in the Server header of the
response by default. If the handler returns a response with the Server header
set, that must take precedence over the adapter's default header.

An adapter should include the Date header with the time the handler returns a
response. If the handler returns a response with the Date header set, that must
take precedence.

## Inspiration

- [Shelf](https://pub.dev/packages/shelf) for Dart.
- [Connect](https://github.com/senchalabs/connect) for NodeJS.
- [Rack](https://github.com/rack/rack) for Ruby.
