## 2.0.0-rc.5
- Client certificates: `NativeTls.clientAuthorities` names the CAs a client
  certificate must chain to, and the handshake requires one
- `bind` refuses a group join with other TLS settings than the group's
- ALPN: the handshake selects `http/1.1` and refuses a client that offers
  only other protocols
- Encrypted private keys: `NativeTls.password` opens a PKCS#8 key under
  PBES2 with PBKDF2 and AES-128 or AES-256 CBC, or one behind OpenSSL's
  DEK-Info headers
- PKCS#1 `RSA PRIVATE KEY` files are read, the form cert-manager writes by
  default
- An IPv6 listener takes IPv4 clients on every platform, as in dart:io. Before,
  Windows and a Linux with net.ipv6.bindv6only=1 kept it IPv6 only
- zio pinned at upstream main (IOCP file streaming #857, task-group publish fix
  #877) with the fork's executor-tick patches on top
- Resolves with code_assets 1.1 and up, so a workspace on Flutter below 3.47,
  which pins meta to 1.18, can take the package
- A listening port on Windows refuses every other bind, as in dart:io. Before,
  a socket with SO_REUSEADDR could take it
- `NativeAdapter.bind` takes `v6Only`, as `IOAdapter.bind` does

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
