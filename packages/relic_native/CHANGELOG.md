## Unreleased
- Client certificates: `NativeTls.clientAuthorities` names the CAs a client
  certificate must chain to, and the handshake requires one
- `bind` refuses a group join with other TLS settings than the group's
- ALPN: the handshake selects `http/1.1` and refuses a client that offers
  only other protocols

## 2.0.0-rc.4
- Works on Windows: the acceptor and the reactors share one zio loop group,
  and the waiter thread waits on the completion port and owns the loop's wake
- Built with Zig 0.17.1

## 2.0.0-rc.3
- Initial release: `NativeAdapter.bind`, `NativeExchange` and `serveNative`
  on zio and `std.http.Server`. HTTP/1.0 and HTTP/1.1, keep-alive, several
  isolates on one server, prebuilt for Linux, macOS and Windows
- Streamed request and response bodies. `maxInlineBody` bounds the body
  read before the handler runs
- The prebuilt libraries use hardware AES for TLS. They need AES-NI,
  PCLMULQDQ and AVX on x64, and the ARMv8 crypto extensions on Linux and
  Windows arm64
