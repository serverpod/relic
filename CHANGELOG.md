## 2.0.0-rc.2
- feat!: Add HTML form and multipart parsing ([#380](https://github.com/serverpod/relic/pull/380)) - closes [#379](https://github.com/serverpod/relic/issues/379)
  - BREAKING: The minimum Dart SDK is 3.10.0. The Dart 3.9.0 compiler crashes in the FFI transform ([dart-lang/sdk#61321](https://github.com/dart-lang/sdk/issues/61321))
  - BREAKING: `BodyType` has no const constructor. Drop `const` from `BodyType(...)` calls
  - BREAKING: Extended `Content-Disposition` parameters such as `filename*` are RFC 8187 ext-values and always encode as UTF-8. `ContentDispositionParameter` has no `encoding`, and its `language` is a `LanguageTag`. Parsing throws `FormatException` for a charset other than UTF-8 and for a malformed ext-value
  - Add `req.urlEncodedForm()`, `req.multipartForm()` and `req.formData()`, which picks the parser from the request Content-Type
  - Add `req.multipart()` to stream parts without aggregating them. Each part is a `MultipartFieldPart`, `MultipartFilePart` or `MultipartOtherPart`
  - Read fields through accessors such as `IntFormField('age')` with `form.fields.get`, `tryGet` and `getAll`, and files through `FormFile`. A missing field throws `MissingFormFieldException`, a value that does not decode throws `InvalidFormFieldException`
  - `FormLimits` caps body size, part, field and file counts, and field and file sizes. Going over one throws `FormLimitExceededException`, whose `limit` names the `FormLimit`
  - Uploads go to `MemoryUploadStorage` by default. `TempUploadStorage` in relic_io writes each upload to its own directory. On POSIX systems the directory has mode 0700. On Windows it inherits the permissions of its parent, and the default parent, the user's temp directory, is private to that user. Call `MultipartFormData.dispose()` to delete them
  - Upload filenames are reduced to their basename, with control and bidi formatting characters removed. `.`, `..` and an empty filename give a null `filename`. `filename*` is ignored, per RFC 7578
  - The server answers an uncaught `FormException` with its `statusCode`, which is 400, 413 or 415. When parsing fails it also sends `Connection: close`, as the rest of the body may be unread
  - `BodyType` carries Content-Type parameters such as `boundary` in `parameters`. `Body.fromData` and `Body.fromDataStream` take a `parameters` argument, and the dart:io adapter carries them through
  - Add a typed `ContentTypeHeader`, read with `headers.contentType`. Set Content-Type through the body

## 2.0.0-rc.1
- refactor!: Drop `NormalizedPath` interning ([#375](https://github.com/serverpod/relic/pull/375)) - fixes [#118](https://github.com/serverpod/relic/issues/118), [#342](https://github.com/serverpod/relic/issues/342), closes [#344](https://github.com/serverpod/relic/issues/344)
  - BREAKING: `NormalizedPath.interned` is removed. Construction no longer caches, so there is no per-isolate cache to size, and no input that can thrash it
  - Add `Router.lookupUri(method, url)`, the entry point for request routing: it derives the path with `NormalizedPath.fromUri` and looks it up with `lookupPath`
  - Routing recovers most of the lost throughput by pre-computing repeated work and by undoing parameter bindings in place while backtracking, instead of copying the parameter map at every level
- fix!: Address security audit findings ([#369](https://github.com/serverpod/relic/pull/369))
  - BREAKING: Cross-origin WebSocket upgrades are rejected with 403 by default; pass `WebSocketUpgrade(..., allowAnyOrigin: true)` to accept them. Only the host is compared, since a TLS-terminating proxy changes scheme and port
  - BREAKING: Header names and values are validated on assignment. CR, LF, NUL, and invalid names now throw where every header write funnels, rather than reaching the wire
  - BREAKING: Malformed auth headers and non-token MIME type parts are rejected where they were previously tolerated
  - The request path is split into segments before percent-decoding, so an encoded separator (`%2F`) can no longer introduce a path boundary that no upstream proxy saw; `NormalizedPath.fromUri` names the safe conversion
  - The path is normalized before the routing host is prepended, so a path resolving upwards can no longer pop the host and select another virtual host
  - Auth headers are parsed with the linear header scanner: one pass with no quadratic backtracking on a long value, and text between auth-params is rejected instead of skipped
  - `Content-Disposition` parameter values and `AuthenticationHeader` challenge parts are escaped and validated, so a quote in a filename or realm can no longer end the value and graft on another parameter or challenge
  - The token grammar is enforced on MIME type parts, which `io.ContentType` took separately and thus bypassed the CR/LF check applied to ordinary header values
  - Multi-range responses are streamed lazily and the range count is capped, so a short request can no longer ask for many times the file size
  - Multipart boundaries are drawn from a cryptographic generator instead of ~20 bits from `Random`
  - The adapter dispatch is awaited, so a response that fails to write yields a 500 instead of leaving the connection open and the client waiting
  - Detached (hijacked and upgraded) connections are tracked by the adapter: counted by `connectionsInfo()`, drained and sent a 1001 close on graceful shutdown, and destroyed on `close(force: true)`
  - `use()` on a catch-all route now applies to the prefix itself, so `/api` no longer bypasses the middleware that `/api/keys` runs
  - Add `Token68` for the RFC 9110 `token68` form, used when validating a single-token `WWW-Authenticate` challenge
  - docs: The static file handler never filtered hidden files; the documentation no longer claims it does. Every file in the served directory is served, dot files included

## 2.0.0-beta.1
- feat: Add `CacheControlHeader.parseStrict` for validating own values ([#370](https://github.com/serverpod/relic/pull/370))
  - Throws a `FormatException` for an unrecognized directive or a malformed delta-seconds value instead of ignoring it
  - Intended for values under the sender's own control, such as server configuration; `parse` remains lenient per RFC 9111 5.2

## 2.0.0-beta.0

Overhaul of typed HTTP headers for RFC compliance, landing in concert with serverpod 4.0. Parsing of received (request) headers is lenient (except security-sensitive ones), while construction and serialization are always strict. Many typed headers changed shape and/or semantics, so this is a breaking release.

- refactor!: Cookie and Set-Cookie headers ([#361](https://github.com/serverpod/relic/pull/361))
  - BREAKING: `SetCookie` now represents a single cookie, and `SetCookieHeader` is a `List<SetCookie>` collection (one `Set-Cookie` line per cookie, RFC 6265 4.1). The previous single-cookie `SetCookieHeader(name:, value:, ...)` API is replaced by `SetCookie(...)`; augment a response with `mh.setCookie = (mh.setCookie ?? const SetCookieHeader.empty()).add(cookie)`
  - The request `Cookie` header is parsed leniently: a malformed cookie is skipped and the header is rejected only when no cookie in it is usable
  - Add `CookieHeader.getCookies(name)` returning every cookie with that name in order; byte-identical duplicates are preserved (not collapsed)
  - `Set-Cookie` decode is strict (it is produced by the server): a malformed attribute rejects the cookie
  - `Domain` is normalized per RFC 6265 5.2.3 — the full leading-dot run is stripped and the host is lower-cased; an all-dots `Domain` is rejected
  - `Max-Age` is parsed as a strict decimal integer per RFC 6265 5.2.2; non-decimal values such as `0xFF` are rejected
  - Nameless `=value` segments are dropped when parsing the request `Cookie` header
- feat!: RFC compliant typed headers ([#360](https://github.com/serverpod/relic/pull/360)) — fixes [#113](https://github.com/serverpod/relic/issues/113), [#142](https://github.com/serverpod/relic/issues/142)
  - Many typed headers changed their Dart interface and/or their parse/serialize semantics
  - Parsing is lenient on receive; construction and serialization are strict

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
