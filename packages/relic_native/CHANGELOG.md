## Unreleased
- fix: The request body takes its type from `relic_core`, and a request
  with no content has no body type
- fix: A request with more than one `Content-Type` field gets 400. A
  filter in front and the server could otherwise read the body as
  different types, as in CVE-2023-38199

## 2.0.0

The first release of `relic_native`, a
[Relic](https://pub.dev/packages/relic) adapter on an HTTP server written in
Zig. It answers about five times the requests per second of `relic_io`. To
try it, add the package and call `app.serveNative()` where the program
called `app.serve()`.

### Benchmarks

On a GCP c4d-standard-32 instance, 16 AMD EPYC 9B45 cores, one isolate
answers 295 thousand plaintext requests per second on `relic_native` and
61 thousand on `relic_io`. Over HTTPS it is 243 thousand and 25 thousand.
An idle WebSocket over TLS takes 14.8 KiB of the server's memory, and
61.6 KiB on `relic_io`. The
[Relic changelog](https://pub.dev/packages/relic/changelog#200) has the
other routes and how they were measured.

### Features

- Initial release: `NativeAdapter`, a Relic adapter on a Zig HTTP server
  built on zio and `std.http.Server`, which each isolate drives from its own
  thread. `NativeExchange`, `NativeOptions`, `NativeTls` and `serveNative`
  go with it
- HTTP/1.0 and HTTP/1.1 with keep-alive, streamed request and response
  bodies, WebSockets and hijacked connections. `NativeOptions` holds the
  limits and timeouts, `maxInlineBody` among them, the body read before the
  handler runs
- Several isolates serve one port: a `bind` with the same `group` joins the
  server the first one created, and passes the same `tls`
- HTTPS through `NativeTls`, TLS 1.3 only: a certificate chain and a private
  key. The key is ECDSA, RSA or Ed25519 in PKCS#8 form, or a SEC 1
  (`EC PRIVATE KEY`) or PKCS#1 (`RSA PRIVATE KEY`) one. `password` opens an
  encrypted key, a PKCS#8 key under PBES2 with PBKDF2 and AES-128 or AES-256
  CBC, or one behind OpenSSL's DEK-Info headers. `clientAuthorities` names
  the CAs a client certificate must chain to, and the handshake then requires
  one. ALPN selects `http/1.1` and refuses a client that offers only other
  protocols
- `bind` takes `v6Only`, as `IOAdapter.bind` does. Without it an IPv6
  listener takes IPv4 clients
- Prebuilt for Linux, macOS and Windows on x64 and arm64, so a project needs
  no Zig toolchain. The libraries use hardware AES for TLS. They need AES-NI,
  PCLMULQDQ and AVX on x64, and the ARMv8 crypto extensions on Linux and
  Windows arm64
