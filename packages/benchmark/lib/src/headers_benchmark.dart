// Header access cost per request for a realistic browser request head:
// eighteen fields including a large cookie. Two stores, two access
// patterns. The lazy store is what relic_native produces, the map store is
// what relic_io produces today.
import 'package:relic/relic.dart';

/// Eighteen headers as Chrome sends them, cookie included.
const browserRequestHeaders = <(String, String)>[
  ('Host', 'www.example.com'),
  ('Connection', 'keep-alive'),
  ('Cache-Control', 'max-age=0'),
  ('sec-ch-ua', '"Chromium";v="130", "Google Chrome";v="130"'),
  ('sec-ch-ua-mobile', '?0'),
  ('sec-ch-ua-platform', '"macOS"'),
  ('Upgrade-Insecure-Requests', '1'),
  (
    'User-Agent',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
  ),
  (
    'Accept',
    'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,'
        'image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
  ),
  ('Sec-Fetch-Site', 'none'),
  ('Sec-Fetch-Mode', 'navigate'),
  ('Sec-Fetch-User', '?1'),
  ('Sec-Fetch-Dest', 'document'),
  ('Accept-Encoding', 'gzip, deflate, br, zstd'),
  ('Accept-Language', 'en-US,en;q=0.9,da;q=0.8'),
  (
    'Cookie',
    'session=8f3c2a1e9b7d4c6a5e2f1b3d9c8a7e6f; theme=dark; '
        '_ga=GA1.2.1234567890.1700000000; _gid=GA1.2.0987654321.1700000000; '
        'consent=functional,analytics; ab=variant-b; lang=en',
  ),
  ('If-None-Match', '"33a64df551425fcc55e4d42a148795d9f25f89d4"'),
  ('Content-Length', '0'),
];

final _encoded = ByteHeaderStore.encode(browserRequestHeaders);

/// A fresh lazy store over the same head bytes each time, as an adapter
/// hands one over per request.
///
/// The bytes and slots come from the parser, so this allocates only the
/// store's own bookkeeping.
ByteHeaderStore byteStore() => ByteHeaderStore(_encoded.bytes, _encoded.slots);

/// A fresh map store, as the dart:io adapter builds one per request.
MapHeaderStore mapStore() {
  final store = MapHeaderStore();
  for (final (name, value) in browserRequestHeaders) {
    store.add(HeaderName.lookup(name), value);
  }
  return store;
}

/// What a typical handler touches: the host, the content length and the
/// cookie, through the typed accessors.
int readThree(Headers headers) =>
    (headers.host?.host.length ?? 0) +
    (headers.contentLength ?? 0) +
    (headers.cookie?.cookies.length ?? 0);

/// Every field, as a logger or a proxy would.
int readAll(Headers headers) {
  var total = 0;
  headers.forEach((name, value) => total += value.length);
  return total;
}
