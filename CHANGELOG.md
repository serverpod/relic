## Unreleased
- fix: `ContentTypeHeader` follows the media type grammar of RFC 9110 8.3.1. It reads the bytes with the scanner the other typed headers use, in place of the regular expressions of `http_parser`, and a value parses in about a seventh of the time
  - A byte above 0x7F outside a quoted value is a `FormatException`, as are a folded line and a backslash before a control character. A tab inside a quoted value is accepted, and so is a `;` with no parameter after it, as in `application/json;`
  - Encoding writes a parameter value that is not a token as a quoted string. It throws `FormatException` for a value with a control character or a code unit above 0xFF

## 2.0.0

Relic 2.0 adds `relic_native`, a native HTTP adapter that answers about five times the requests per second of `relic_io`. To try it, add the package and call `app.serveNative()` where the program called `app.serve()`.

The release also makes the typed headers fully RFC compliant, adds HTML form and multipart parsing, and fixes the findings of a security audit.

Relic 2.0.0 requires Dart 3.10.0 or later.

### `relic_native`

`relic_native` is a new package, a Relic adapter on an HTTP server written in Zig, a systems language that compiles to native code and has no garbage collector. The server accepts connections, parses requests, keeps connections alive, enforces timeouts, terminates TLS and frames WebSockets in native code, and a request reaches the handler as plain Dart data. It runs the same handlers, middleware and router as `relic_io` and passes the same conformance suite.

#### Benchmarks

The figures are from a GCP c4d-standard-32 instance, 16 AMD EPYC 9B45 cores with one thread per core, running Ubuntu 24.04 and Dart 3.13.7. oha held 64 keep-alive connections over loopback from the same machine.

One isolate at saturation over HTTP, in thousands of requests per second:

| Route | `relic_io` | `relic_native` | Speed-up |
|---|---:|---:|---:|
| Plaintext, a 13-byte answer | 61.1 | 294.9 | 5x |
| Headers, three typed request headers read | 33.8 | 182.9 | 5x |
| Browser, 1 KB of JSON to a browser-like request | 30.4 | 128.6 | 4x |

The same over HTTPS. It is TLS 1.3 on connections that stay open, so it measures records, not handshakes:

| Route | `relic_io` | `relic_native` | Speed-up |
|---|---:|---:|---:|
| Plaintext | 25.4 | 243.3 | 10x |
| Headers | 18.6 | 146.8 | 8x |
| Browser | 18.1 | 98.4 | 5x |

99th percentile latency over HTTP, in milliseconds, with each adapter at 75 percent of its own saturation rate:

| Route | `relic_io` | `relic_native` |
|---|---:|---:|
| Plaintext | 1.29 | 0.27 |
| Headers | 1.41 | 0.44 |
| Browser | 1.59 | 0.66 |

Throughput grows with `noOfIsolates`. Four isolates answer 580 thousand requests per second on the headers route, against 105 thousand on `relic_io`.

With 10,000 idle WebSockets open over TLS, the server's resident memory grows by 14.8 KiB per connection on `relic_native` and 61.6 KiB on `relic_io`.

#### Protocols and platforms

The adapter is opt-in, and `app.serve()` stays on `relic_io`. It speaks HTTP/1.0 and HTTP/1.1, its HTTPS is TLS 1.3 only, and it supports WebSockets and hijacked connections. Prebuilt libraries ship for Linux, macOS and Windows on x64 and arm64, so a project needs no Zig toolchain. The gain shows once the server is the limit, not the database or the handler. The [`relic_native` changelog](https://pub.dev/packages/relic_native/changelog) and the [serving page](https://docs.dartrelic.dev/reference/serving) have the details.

### All changes

The changes are grouped by area, and each breaking change carries a BREAKING label in its group.

#### Headers

- feat!: RFC compliant typed headers ([#360](https://github.com/serverpod/relic/pull/360)) - fixes [#113](https://github.com/serverpod/relic/issues/113), [#142](https://github.com/serverpod/relic/issues/142)
  - BREAKING: Many typed headers changed their Dart interface or their parse and serialize semantics. Parsing is lenient on receive, except for security-sensitive headers, and construction and serialization are strict
  - BREAKING: Extended `Content-Disposition` parameters such as `filename*` are RFC 8187 ext-values and always encode as UTF-8. `ContentDispositionParameter` has no `encoding`, and its `language` is a `LanguageTag`. Parsing throws `FormatException` for a charset other than UTF-8 and for a malformed ext-value ([#380](https://github.com/serverpod/relic/pull/380))
  - Add a typed `ContentTypeHeader`, read with `headers.contentType` ([#380](https://github.com/serverpod/relic/pull/380))
  - Add `CacheControlHeader.parseStrict` for values under the sender's own control. It throws `FormatException` for an unrecognized directive or a malformed delta-seconds value, and `parse` stays lenient per RFC 9111 5.2 ([#370](https://github.com/serverpod/relic/pull/370))
- refactor!: Cookie and Set-Cookie headers ([#361](https://github.com/serverpod/relic/pull/361))
  - BREAKING: `SetCookie` is a single cookie, and `SetCookieHeader` is a `List<SetCookie>`, one `Set-Cookie` line per cookie (RFC 6265 4.1). Build a cookie with `SetCookie(...)` and add it with `mh.setCookie = (mh.setCookie ?? const SetCookieHeader.empty()).add(cookie)`
  - The request `Cookie` header is parsed leniently: a malformed cookie is skipped, nameless `=value` segments are dropped, and the header is rejected only when no cookie in it is usable
  - Add `CookieHeader.getCookies(name)`, every cookie with that name in order, byte-identical duplicates included
  - `Set-Cookie` decode is strict: a malformed attribute rejects the cookie
  - `Domain` is normalized per RFC 6265 5.2.3: the leading dots are stripped and the host is lower-cased. An all-dots `Domain` is rejected
  - `Max-Age` is a strict decimal integer per RFC 6265 5.2.2, so a value such as `0xFF` is rejected
- feat!: Rebase `Headers` on `HeaderStore`
  - BREAKING: `Headers` and `MutableHeaders` are not `Map`s. Read with `headers[name]`, `headers(accessor)`, `get` or `tryGet`. Write with `Headers.build`, `transform`, and `MutableHeaders.set`, `add`, `remove` and `assign`. The `Headers.x[headers]` form, the `Header` extension type and `HeadersBase` are gone
  - BREAKING: `Headers.fromMap` throws `FormatException` for a name that is not a token or a value with CR, LF or NUL
  - BREAKING: `HeaderAccessor` takes a `HeaderName`. `ReadOnlyAccessor` has an abstract `decode`, and an accessor built from a function extends `FunctionAccessor`
  - BREAKING: `Request.target` holds the path and query as a `RequestTarget`. An adapter answers 400 to a malformed one
  - New package `relic_headers`, re-exported by relic_core: `HeaderName`, `HeaderStore`, `MutableHeaderStore`, `MapHeaderStore` and `ByteHeaderStore`. `HeaderName.custom` takes a lowercase token
  - Typed headers decode from the wire bytes. `HeaderCodec.bytes` and `HeaderCodec.fields` take a parser over bytes, and `HeaderCodec.single` and the text constructors stay
  - The `Headers.xHeader` string constants are deprecated in favour of `HeaderName.x`

#### Bodies and forms

- feat!: The `Body` frames every response
  - BREAKING: `Content-Length`, `Content-Type` and the chunked coding come from the `Body`. Setting them on the response headers has no effect
  - BREAKING: `BodyType` has no const constructor. It carries Content-Type parameters such as `boundary` in `parameters`, and `Body.fromData` and `Body.fromDataStream` take a `parameters` argument
  - The `Body` constructor is public and takes `bytes`, `stream` or `open`. A body built with `open` opens only when read
  - Add `Body.bytes`, `Body.readAll()` and `Body.consume()`. `read(maxLength:)` rejects a body whose known length is over the limit without reading it
  - Add `BodyType.fromContentType`, the type of a body sent with a `ContentTypeHeader`
  - A HEAD request gets the same `Response` as GET. The adapter sends its length and type and no body
- feat: Add HTML form and multipart parsing ([#380](https://github.com/serverpod/relic/pull/380)) - closes [#379](https://github.com/serverpod/relic/issues/379)
  - Add `req.urlEncodedForm()`, `req.multipartForm()` and `req.formData()`, which picks the parser from the request Content-Type
  - Add `req.multipart()` to stream parts without aggregating them. Each part is a `MultipartFieldPart`, `MultipartFilePart` or `MultipartOtherPart`
  - Read fields through accessors such as `IntFormField('age')` with `form.fields.get`, `tryGet` and `getAll`, and files through `FormFile`. A missing field throws `MissingFormFieldException`, a value that does not decode throws `InvalidFormFieldException`
  - `FormLimits` caps body size, part, field and file counts, and field and file sizes. Going over one throws `FormLimitExceededException`, whose `limit` names the `FormLimit`
  - Uploads go to `MemoryUploadStorage` by default. `TempUploadStorage` in relic_io writes each upload to its own directory. On POSIX systems the directory has mode 0700. On Windows it inherits the permissions of its parent, and the default parent, the user's temp directory, is private to that user. Call `MultipartFormData.dispose()` to delete them
  - Upload filenames are reduced to their basename, with control and bidi formatting characters removed. `.`, `..` and an empty filename give a null `filename`. `filename*` is ignored, per RFC 7578
  - The server answers an uncaught `FormException` with its `statusCode`, which is 400, 413 or 415. When parsing fails it also sends `Connection: close`, as the rest of the body may be unread
- fix: A 206 range response defaults its Content-Type to application/octet-stream

#### Routing

- fix!: A HEAD request to a path without a HEAD route runs its GET route (RFC 9110 9.1)
  - BREAKING: `Router.lookup(Method.head, ...)` returns the GET route of such a path, and `MethodMiss.allowed` lists HEAD beside GET. A GET handler that must not run on HEAD checks `request.method`
  - BREAKING: `RouterMatch` has no public constructor, and `LookupResult` takes `T extends Object`
  - A `Hijack` or `WebSocketUpgrade` answering such a HEAD gets 405. `RouterMatch.headFallback` marks the match and `RouterMatch.registered` lists the path's own methods
- refactor!: Drop `NormalizedPath` interning ([#375](https://github.com/serverpod/relic/pull/375)) - fixes [#118](https://github.com/serverpod/relic/issues/118), [#342](https://github.com/serverpod/relic/issues/342), closes [#344](https://github.com/serverpod/relic/issues/344)
  - BREAKING: `NormalizedPath.interned` is removed. Construction does not cache, so there is no per-isolate cache to size and no input that can thrash it
  - Add `Router.lookupUri(method, url)`, the entry point for request routing. It derives the path with `NormalizedPath.fromUri` and looks it up with `lookupPath`
- fix: `RelicApp.run(backtrack: false)` and `routeWith(backtrack: false)` look routes up without backtracking
- fix: `Request.forwardTo` keeps the `backtrack` and `useHostWhenRouting` options of the original

#### WebSockets

- feat: `FramedWebSocket` frames RFC 6455 over any `StreamChannel<Uint8List>`. The server upgrades through the adapter when `capabilities.webSocket` is set and frames over `hijack` otherwise. With neither it answers 501
- fix: A `WebSocketUpgrade` answers a request other than GET with 405

#### Adapters and serving

- feat!: Replace the request stream with an exchange-based `Adapter`
  - BREAKING: `Adapter` is an interface with `listeners`, `capabilities` and `start(sink)`. It hands over `AdapterExchange` objects with `respond`, `hijack`, `upgradeWebSocket` and `abort`. `Adapter.requests`, `Adapter.port` and `AdapterRequest` are gone. The port is on `listeners` and on `RelicServer.port`. The toolkit for writing an adapter is in `package:relic_core/adapter.dart`
  - BREAKING: `IOAdapter.port`, `requests`, `respond`, `hijack`, `connect` and `IOAdapterRequest` are gone
  - BREAKING: `HttpResponseExtension.applyHeaders(headers, body)` is `applyFraming(headers, framing)`
  - BREAKING: `HijackCallback` receives a `StreamChannel<Uint8List>`
  - BREAKING: `hijack` throws `HijackRefused` when the request body is chunked and not read to its end
  - BREAKING: `Request.protocolVersion` is `Request.protocol`, an `HttpProtocol`
  - BREAKING: `RelicWebSocket` implementers provide `done`, and `tryClose` accepts 1001
  - BREAKING: `RelicServer.close()` waits for the exchanges in flight and sends 1001 to every WebSocket. `close(grace:)` forces the close after a deadline, and `close(force: true)` ends a graceful close that is still waiting. `RelicApp.close` takes the same `force` and `grace`
  - Add `Request.cancelled`, a future that completes when the client went away before the response finished. The dart:io adapter sees that only once something was written
  - Hijacked and upgraded connections count in `connectionsInfo()`, a graceful close drains them, and `close(force: true)` destroys them
- feat: New package `relic_native`, a Relic adapter on a Zig HTTP server with TLS, WebSockets and hijacking, prebuilt for Linux, macOS and Windows on x64 and arm64. Its own CHANGELOG describes it
- fix: The dart:io adapter closes the connection after a request that lists `close` in any Connection line, also beside a later `keep-alive`, which won in dart:io's `persistentConnection`

#### Security

- fix!: Address security audit findings ([#369](https://github.com/serverpod/relic/pull/369))
  - BREAKING: Cross-origin WebSocket upgrades are rejected with 403 by default. Pass `WebSocketUpgrade(..., allowAnyOrigin: true)` to accept them. Only the host is compared, since a TLS-terminating proxy changes scheme and port
  - BREAKING: A header name that is not a token, or a value with CR, LF or NUL, throws `FormatException` where it is set
  - BREAKING: Malformed auth headers are rejected, and so are MIME type parts that are not tokens, which `io.ContentType` took separately and so slipped past the CR and LF check on other header values
  - The request path is split into segments before percent-decoding, so an encoded separator (`%2F`) cannot introduce a path boundary that no upstream proxy saw. `NormalizedPath.fromUri` names the safe conversion
  - The path is normalized before the routing host is prepended, so a path resolving upwards cannot pop the host and select another virtual host
  - Auth headers are parsed in one pass by the linear header scanner, with no quadratic backtracking on a long value, and text between auth-params is rejected instead of skipped
  - `Content-Disposition` parameter values and `AuthenticationHeader` challenge parts are escaped and validated, so a quote in a filename or realm cannot end the value and graft on another parameter or challenge
  - Multi-range responses are streamed lazily and the range count is capped, so a short request cannot ask for many times the file size
  - Multipart boundaries are drawn from a cryptographic generator instead of about 20 bits from `Random`
  - A response that fails to write gets a 500, or an aborted connection once its head is out, instead of a client left waiting
  - `use()` on a catch-all route applies to the prefix itself, so `/api` does not bypass the middleware that `/api/keys` runs
  - Add `Token68` for the RFC 9110 `token68` form, used to validate a single-token `WWW-Authenticate` challenge
  - docs: The static file handler serves every file in its directory, dot files included. The documentation no longer says it filters hidden files

#### Other changes

- build!: The minimum Dart SDK is 3.10.0
- perf!: A sync response reaches the adapter without a Future, and a `ContextProperty` takes its slot once
  - BREAKING: The routing handler and `respondWith` return a sync handler's `Response` as is. A handler that throws before its first `await` throws to the caller
  - BREAKING: A `ContextProperty` holds its slot for the life of the isolate. Create each one once, as a global
- feat: Add `httpDate()`. `httpDate`, `logMessage` and `logRequests` read the time through `package:clock`, so `withClock` controls them

## 1.2.0
- feat: Make `NormalizedPath` interning cache configurable ([#343](https://github.com/serverpod/relic/pull/343))
  - Introduce abstract `Cache<K, V>` interface
  - Add `NoCache` implementation for high-cardinality workloads
  - `LruCache` now implements `Cache`
  - `NormalizedPath.interned` can be swapped to any `Cache` implementation
- feat: Add `staticChangeCount` and VM service extension to `DeveloperTools` ([#341](https://github.com/serverpod/relic/pull/341))
- feat: Add `DeveloperTools` class to `RelicApp` ([#340](https://github.com/serverpod/relic/pull/340))

## 1.1.1
- docs(ai): Adds skills for AI agents based on documentation. ([#338](https://github.com/serverpod/relic/pull/338))

## 1.1.0
- feat: Allow internal request forwarding with `req.forwardTo(newReq)` ([#331](https://github.com/serverpod/relic/pull/331))
- feat: Add `indexAssets()` and `tryAssetPathSync()` to `CacheBustingConfig` ([#332](https://github.com/serverpod/relic/pull/332))
- feat: Auto-index assets in `StaticHandler` when cache busting is configured ([#332](https://github.com/serverpod/relic/pull/332))

## 1.0.0

Relic is now considered stable and production-ready! 🎉

## 0.15.1
- fix: Downgrade meta dep to ^1.16.0 to match flutter 3.32.0 (serverpod lower bound) ([#325](https://github.com/serverpod/relic/pull/325))

## 0.15.0
- feat: Add virtual host routing support ([#322](https://github.com/serverpod/relic/pull/322))
  - Add `useHostWhenRouting` parameter to `routeWith()` middleware
  - Add `useHostWhenRouting` parameter to `RelicApp`
  - When enabled, routing uses `{host}{path}` for route matching
- feat: Add `paths`, `toString()`, and `toDot()` to PathTrie for debugging ([#320](https://github.com/serverpod/relic/pull/320))
- feat: Add `force` parameter to server `close()` method ([#317](https://github.com/serverpod/relic/pull/317))
- refactor: Restructure into multi-package workspace with relic_core, relic_io, and relic packages

## 0.14.0
- feat!: Add optional consume flag to attach ([#309](https://github.com/serverpod/relic/pull/309))
  - BREAKING: `attach` now throws `ArgumentError` when called with a tail path (`/**`), unless `consume: true` and the attached trie/router has a single value at the root (`isSingle`)
  - BREAKING: `group` now throws `ArgumentError` when called with a tail path
  - Add `consume` flag to `attach` that resets the attached trie's root after attachment
  - Add `isSingle` property to check if a trie/router has only a single root value/route
  - Allow `attach(..., consume: true)` at tail paths (`/**`) when the attached trie/router `isSingle`
  - Update `injectAt` to use `attach(..., consume: true)`, still enabling injection at tail paths for simple `HandlerObject`s (those adding a single handler at the root ('/'))

## 0.13.1
- fix: Close connection, if request too large ([#303](https://github.com/serverpod/relic/pull/303))

## 0.13.0
- feat!: Add maxLength argument on read ([#301](https://github.com/serverpod/relic/pull/301))

## 0.12.0
- feat!: Support back-tracking during routing ([#297](https://github.com/serverpod/relic/pull/297))
- fix: Ensure close is idempotent ([#295](https://github.com/serverpod/relic/pull/295))

## 0.11.0
- feat!: Add typed accessor for query and path parameters ([#288](https://github.com/serverpod/relic/pull/288))
- feat: Introduce ConnectionInfo ([#273](https://github.com/serverpod/relic/pull/273))
- feat: Add IPAddress class (independent of dart:io) ([#272](https://github.com/serverpod/relic/pull/272))
- refactor!: Simplify ContextProperty interface
- refactor!: Disallow url rewriting in Request.copyWith ([#289](https://github.com/serverpod/relic/pull/289))
- refactor!: Use named ctors on all header classes ([#283](https://github.com/serverpod/relic/pull/283))
- refactor!: Avoid repeating ctor name on parameter ([#282](https://github.com/serverpod/relic/pull/282))
- fix!: Remove stale arguments from Request and Response class ([#274](https://github.com/serverpod/relic/pull/274))
- fix: Don't overwrite Content-Length when set as header ([#291](https://github.com/serverpod/relic/pull/291))

## 0.10.0
- refactor!: The Great Simplification ([#264](https://github.com/serverpod/relic/pull/264))
  - Merged `RequestContext` into `Request` by moving the token property
  - `HandledContext` renamed to `Result`
  - Merge `ResponseContext` into `Response` (now implements `Result`)
  - Removed `respond()`, `hijack()`, and `connect()` methods - handlers can construct and return `Result`s directly
  - Updated handler signatures: `Handler = FutureOr<Result> Function(Request req)`
  - Consolidated context classes into single file using part files
  - Updated all examples and tests
  - Significant simplification of the class hierarchy by eliminating the:
  - `Context`,
  - `RequestContext`,
  - `RespondableContext`,
  - `HijackableContext`,
  - `ConnectableContext`, and
  - `ResponseContext` interfaces
  - Renamed `ConnectionContext` to `WebSocketUpgrade` (now extends `Result`)
  - Renamed `HijackedContext` to `Hijack` (now extends `Result`)

## 0.9.2
- feat: Expose `noOfIsolates` parameter on serve extension on `RelicApp` ([#260](https://github.com/serverpod/relic/pull/260))
- feat: Add `injectAt` extension method on `Router<T>` ([#261](https://github.com/serverpod/relic/pull/261))
- feat: Allow re-run of `RelicApp.run` after `close` ([#257](https://github.com/serverpod/relic/pull/257))

## 0.9.1
- feat: Add async RelicServer.connectionsInfo() method ([#255](https://github.com/serverpod/relic/pull/255))
  - Adds a `connectionsInfo()` method to `RelicServer` that returns the
  current number of active, closing, and idle connections.
  - A new `ConnectionsInfo` typedef is introduced as a record type with
  `active`, `closing`, and `idle` fields.

## 0.9.0
- refactor!: Context renaming ([#251](https://github.com/serverpod/relic/pull/251))
  Renames core context types for improved clarity and consistency:
  - `NewContext` → `RequestContext`
  - `ConnectContext` → `ConnectionContext`
  - `HijackContext` → `HijackedContext`
  - Base class `RequestContext` renamed to `Context`
- chore!: Upgrade sdk to ^3.7.0 ([#239](https://github.com/serverpod/relic/pull/239))
- feat: Introduce MultiIsolateRelicServer ([#216](https://github.com/serverpod/relic/pull/216))
  Implements multi-isolate support for `RelicServer` to enable concurrent request handling across multiple CPU cores. Adds `noOfIsolates` optional named parameter to `RelicServer`
  constructor, and `RelicApp.run`.
- fix: Mask sensitive credentials in authorization header toString() methods ([#238](https://github.com/serverpod/relic/pull/238))

## 0.8.0
- feat!: RelicApp now supports hot-reload ([#226](https://github.com/serverpod/relic/pull/226))
- feat: Introduce RelicApp ([#212](https://github.com/serverpod/relic/pull/212))
- feat: Introduce MiddlewareObject ([#211](https://github.com/serverpod/relic/pull/211))
- feat: Introduce HandlerObject ([#210](https://github.com/serverpod/relic/pull/210))
- feat(router): Add fallback property for unmatched routes ([#196](https://github.com/serverpod/relic/pull/196))
- feat(router): Add asHandler extension to use Router<Handler> as Handler ([#209](https://github.com/serverpod/relic/pull/209))
- feat: Adds support for cache busting ([#192](https://github.com/serverpod/relic/pull/192))
- feat: Support mime-type inference ([#206](https://github.com/serverpod/relic/pull/206))
- feat: Add NewContext.withRequest convenience method ([#198](https://github.com/serverpod/relic/pull/198))
- fix: Build platform correct path when serving files. ([#207](https://github.com/serverpod/relic/pull/207))

## 0.7.0
- feat(router): Add support for setting up mappings of values on lookup `router.use(path, map)` ([#186](https://github.com/serverpod/relic/pull/186))
- feat(trie): Add support for setting up mappings of values on lookup `trie.use(path, map)` ([#185](https://github.com/serverpod/relic/pull/185))

## 0.6.0
- feat!: Custom CacheControl header per file ([#167](https://github.com/serverpod/relic/pull/167))
- feat!: Distinguish between path and method miss in router lookups ([#179](https://github.com/serverpod/relic/pull/179))
- feat!: Remove automatic X-Powered-By header ([#169](https://github.com/serverpod/relic/pull/169))
- feat!: Remove unused strict flag ([#181](https://github.com/serverpod/relic/pull/181))
- feat(router): Router.group ([#157](https://github.com/serverpod/relic/pull/157))
- feat: Add operator== and hashCode on all header classes ([#155](https://github.com/serverpod/relic/pull/155))
- fix: HEAD request should match GET except for body, including Content-Length ([#180](https://github.com/serverpod/relic/pull/180))
- fix: Host header is not a Uri. Introduce an RFC3986 compliant HostHeader class ([#142](https://github.com/serverpod/relic/pull/142))
- fix: Rip out Router.staticCache ([#172](https://github.com/serverpod/relic/pull/172))
- fix: Set content length on body, not headers ([#161](https://github.com/serverpod/relic/pull/161))

## 0.5.0
- refactor!: Rename withResponse to respond (matches connect/hijack) ([#134](https://github.com/serverpod/relic/pull/134))
- docs: Adds a docusaurus documentation page for relic. ([#132](https://github.com/serverpod/relic/pull/132))
- refactor!: Static File Handler Overhaul ([#127](https://github.com/serverpod/relic/pull/127))

## 0.4.1
- fix: Export bindHttpServer in io_adapter.dart ([#114](https://github.com/serverpod/relic/pull/114))
- fix: Handle ':' in BasicAuthorizationHeader parser correctly ([#112](https://github.com/serverpod/relic/pull/112))

## 0.4.0

- fix: Missing convenience getters and setter for Headers.xForwardedFor ([#108](https://github.com/serverpod/relic/pull/108))
- refactor!: Get rid of old context map on Message (Request/Response) ([#105](https://github.com/serverpod/relic/pull/105))
- feat: X-Forwarded-For typed header ([#107](https://github.com/serverpod/relic/pull/107))
- feat: Add ContextProperty class (wraps Expando) ([#94](https://github.com/serverpod/relic/pull/94))
- feat: Typed forwarded header ([#101](https://github.com/serverpod/relic/pull/101))
- build(deps): Bump cli_tools from 0.5.1 to 0.6.0 ([#100](https://github.com/serverpod/relic/pull/100))
- refactor!: Replace DuplexStreamChannel with RelicWebSocket ([#91](https://github.com/serverpod/relic/pull/91))
- test: Add headers constants test and rename file ([#89](https://github.com/serverpod/relic/pull/89))
- build(deps): Bump lints from 5.1.1 to 6.0.0 ([#92](https://github.com/serverpod/relic/pull/92))
- fix: Fix request/response header sets ([#90](https://github.com/serverpod/relic/pull/90))
- docs: Update router docs ([#88](https://github.com/serverpod/relic/pull/88))
- docs: Update router entry comment ([#87](https://github.com/serverpod/relic/pull/87))
- feat: WebSocket support ([#84](https://github.com/serverpod/relic/pull/84))
- feat: Store benchmark results with git notes ([#79](https://github.com/serverpod/relic/pull/79))
- feat: The routeWith middleware builder function is now generic. ([#78](https://github.com/serverpod/relic/pull/78))
- feat(Handler)!: Signature changed  ([#76](https://github.com/serverpod/relic/pull/76))
- feat: Add Router.isEmpty getter ([#75](https://github.com/serverpod/relic/pull/75))
- docs: Add CONTRIBUTING.md and CODE_OF_CONDUCT.md ([#69](https://github.com/serverpod/relic/pull/69))
- feat: PathTrie wildcard and tail matching support ([#70](https://github.com/serverpod/relic/pull/70))
- feat: Router middleware ([#68](https://github.com/serverpod/relic/pull/68))
- feat!: Router now supports verb directly ([#65](https://github.com/serverpod/relic/pull/65))
- docs: Add badges for codecov, etc. ([#67](https://github.com/serverpod/relic/pull/67))
- feat: Add addOrUpdate, update, and remove to PathTrie ([#63](https://github.com/serverpod/relic/pull/63))
- feat: Support Router.attach ([#62](https://github.com/serverpod/relic/pull/62))
- feat: Allow a trie to be attached as a subtrie to another ([#61](https://github.com/serverpod/relic/pull/61))
- feat: Router class ([#52](https://github.com/serverpod/relic/pull/52))
- refactor!: Decouple from dart:io and avoid using exceptions for control-flow ([#48](https://github.com/serverpod/relic/pull/48))
- chore: Add serverpod lints ([#46](https://github.com/serverpod/relic/pull/46))
- feat!: Replace HeaderDecode with HeaderCodec to allow customization on encoding as well ([#43](https://github.com/serverpod/relic/pull/43))
- fix: Ensure cache is updated immediately ([#42](https://github.com/serverpod/relic/pull/42))
- feat!: Support typed access to custom headers ([#38](https://github.com/serverpod/relic/pull/38))
- ci: Hoist continue-on-error to job ([#37](https://github.com/serverpod/relic/pull/37))
- ci: Add test coverage ([#36](https://github.com/serverpod/relic/pull/36))
- fix!: RelicServer cannot reliably know the Uri to use to hit it ([#32](https://github.com/serverpod/relic/pull/32))
- chore: Automate publishing to pub.dev when semver tag is created ([#31](https://github.com/serverpod/relic/pull/31))
- chore: Add pull request title validation. ([#30](https://github.com/serverpod/relic/pull/30))
- refactor!: Get rid of RelicAddress. ([#29](https://github.com/serverpod/relic/pull/29))

## 0.3.0

- feat: Implements lazy loading when parsing headers to avoid unnecessary validation.
- feat: Makes address strongly typed and adds `RelicAddress` type.
- fix: Resolves issue with `Content-Length` header conflicting with `Transfer-Encoding: chunked`.

## 0.2.0

- First tech preview.

## 0.1.0

- Initial version.
