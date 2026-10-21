## 2.0.0-rc.2
- Initial release: `NativeAdapter.bind`, `NativeExchange` and `serveNative`
  on zio and `std.http.Server`. HTTP/1.0 and HTTP/1.1, keep-alive, several
  isolates on one server, prebuilt for Linux, macOS and Windows
- Streamed request and response bodies. `maxInlineBody` bounds the body
  read before the handler runs
- `idleTimeout`, `headerTimeout`, `bodyTimeout`, `writeTimeout` and
  `maxConnections` on `bind` and `serveNative`
- `Request.cancelled` completes when the peer hangs up
- A head that is not CRLF framed, folds a line, lacks a colon, or carries a
  non-token name or a control character in a value is answered 400
- `hijack` hands the connection over as a raw byte channel
- WebSocket upgrades are framed on the native side. `capabilities.webSocket`
  is true, and `maxWebSocketMessage` on `bind` bounds a message
- HTTPS through tls.zig. `tls` on `bind` and `serveNative` takes a
  `NativeTls` with a PEM certificate chain and private key. TLS 1.3 only
