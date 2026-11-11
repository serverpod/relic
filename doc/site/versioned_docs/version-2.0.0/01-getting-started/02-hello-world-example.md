---
sidebar_position: 2
sidebar_label: 👋 Hello world
---

# Hello world

This page builds a small Relic server in four steps. Each step adds one idea to the same program, and each ends with what the server sends back, so you can see the effect of every line you add.

## Create a package

A Relic server is an ordinary Dart program, so it starts as a new console application:

```bash
dart create hello_world
cd hello_world
dart pub add relic
```

`dart create` writes a program in `bin/hello_world.dart`. You will replace its contents in the next step.

## The smallest server

Replace the contents of `bin/hello_world.dart` with this program:

GITHUB_CODE_BLOCK lang="dart" doctag="hello-step-1" file="../_example/getting_started/hello.dart" title="bin/hello_world.dart"

Start it:

```bash
dart run bin/hello_world.dart
```

The program does not return. It waits for requests on port 8080 until you stop it with Ctrl+C. In a second terminal, send it a request with `curl`. The `-i` option makes curl print the status line and the headers of the response, not just the body:

```bash
curl -i http://localhost:8080/
```

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
date: Fri, 23 Oct 2026 11:17:01 GMT
content-length: 14

Hello, world!
```

Every line of that response traces back to the program. `RelicApp` is the application, and also its router. The call to `get` registers a handler for GET requests to the path `/`. A handler is a function that receives a `Request` and returns a result, and this one returns `Response.ok`, the response with status code 200. Its body comes from `Body.fromString`, and the body decides the `content-type` and `content-length` headers. It saw text, chose `text/plain` in UTF-8, and counted 14 bytes, one for each character of `Hello, world!` and one for the newline. Relic added the `date` header itself. Finally, `app.serve()` opens port 8080 on the loopback address, `127.0.0.1`, unless you pass another address and port.

Now ask for a path the program never mentions:

```bash
curl -i http://localhost:8080/nothing
```

```text
HTTP/1.1 404 Not Found
content-type: text/plain; charset=utf-8
date: Fri, 23 Oct 2026 11:17:01 GMT
content-length: 9

Not Found
```

No route matches `/nothing`, so Relic answers 404 on its own. A path the router knows, asked for with a method it doesn't, gets a different answer:

```bash
curl -i -X POST http://localhost:8080/
```

```text
HTTP/1.1 405 Method Not Allowed
date: Fri, 23 Oct 2026 11:17:01 GMT
content-length: 0
allow: GET, HEAD
```

The `allow` header lists the methods the path does accept. HEAD is in the list although the program registers only GET, because a GET route also answers HEAD requests. The answer to a HEAD request has the same headers as the answer to GET, and no body.

## Reading the path

A server that says the same thing to everyone is of limited use. A route can contain parameters, segments that start with a colon and match any value. Add a second route, and a handler for it:

GITHUB_CODE_BLOCK lang="dart" doctag="hello-step-2-app" file="../_example/getting_started/hello_parameters.dart" title="Two routes"

GITHUB_CODE_BLOCK lang="dart" doctag="hello-step-2-handler" file="../_example/getting_started/hello_parameters.dart" title="The handler"

The route `/user/:name/age/:age` has two parameters. When a request matches it, the router puts the matched segments in `rawPathParameters`, a map keyed by the parameter names as Dart symbols, `#name` and `#age`. The values are always strings, so the handler parses the age itself. This time the handler is a named function rather than an inline one. That keeps the route list short, and it matters for hot reload, as the end of this page shows.

Stop the server with Ctrl+C, start it again, and send it a name and an age:

```bash
curl http://localhost:8080/user/Nova/age/27
```

```text
Hello, Nova! To think you are 27 years old.
```

What happens when the age is not a number?

```bash
curl -i http://localhost:8080/user/Nova/age/old
```

```text
HTTP/1.1 500 Internal Server Error
content-type: text/plain; charset=utf-8
date: Fri, 23 Oct 2026 11:17:06 GMT
content-length: 21

Internal Server Error
```

`int.parse` threw a `FormatException`. Relic caught it, answered 500, and printed the exception and its stack trace in the terminal where the server runs. The server itself keeps running. A handler that takes input from clients would check the value first, for example with `int.tryParse`, and answer `Response.badRequest()` when it doesn't parse.

## Logging every request

That stack trace is the first sign of what the server is doing. To see every request, add middleware. Middleware wraps the handlers of the routes below a path, and `logRequests` is a middleware that comes with Relic:

GITHUB_CODE_BLOCK lang="dart" doctag="hello-step-3-app" file="../_example/getting_started/hello_logging.dart" title="Logging middleware"

Restart the server and send the request for Nova again. The terminal where the server runs now shows two lines for it:

```text
INFO - 2026-10-23 13:17:28.158932
2026-10-23T13:17:28.158804  0:00:00.000070 GET     [200] /user/Nova/age/27
```

The first line says when the message was printed. The second gives the time the request arrived, how long the handler took, the method, the status code and the path. Now request `/nothing` again. This time nothing is printed, because middleware added with `use` only runs for requests that match a route. The [Middleware](../02-reference/08-middleware.md) page explains how to reach the others too.

## Answering everything else

The default 404 says `Not Found`. To answer unmatched requests your own way, set the app's `fallback` to a handler. Here is the whole program, with a fallback after the routes:

GITHUB_CODE_BLOCK lang="dart" doctag="hello-world-app" file="../_example/example.dart" title="bin/hello_world.dart"

`respondWith` turns a function that returns a `Response` into a handler, which is what `fallback` takes. Restart the server and ask for `/nothing` once more:

```text
HTTP/1.1 404 Not Found
content-type: text/plain; charset=utf-8
date: Fri, 23 Oct 2026 11:17:32 GMT
content-length: 29

Sorry, that doesn't compute.
```

## Changing code without restarting

Restarting after every change gets old quickly. Start the server with the Dart VM service enabled instead:

```bash
dart run --enable-vm-service bin/hello_world.dart
```

You can also start it in debug mode from your IDE, with _Hot Reload On Save_ enabled in the Dart settings. Change the text in `helloHandler`, save, and send the request for Nova again. The new text comes back without a restart. Changes to the route list in `main` are another matter, because `main` does not run again on a reload. The [Hot reload](../02-reference/10-hot-reload.md) page has the details.
