import 'package:relic/relic.dart';

// doctag<headers-raw-and-typed>
Response describeAccept(Request req) {
  final raw = req.headers['accept'];
  final typed = req.headers.accept;
  final ranges = typed?.mediaRanges
      .map((r) => '${r.type}/${r.subtype} at ${r.quality}')
      .join(', ');
  return .ok(body: .fromString('raw:   $raw\ntyped: $ranges\n'));
}
// end:doctag<headers-raw-and-typed>

// doctag<headers-range>
Response describeRange(Request req) {
  final range = req.headers.range;
  if (range == null) return .ok(body: .fromString('The whole file\n'));
  final parts = range.ranges.map((r) => '${r.start ?? ''}-${r.end ?? ''}');
  return .ok(body: .fromString('${range.unit} ${parts.join(', ')}\n'));
}
// end:doctag<headers-range>

// doctag<headers-get>
Response compareETags(Request req) {
  final condition = req.headers.get(Headers.ifNoneMatch);
  final tags = condition.etags.map(
    (e) => e.isWeak ? 'weak ${e.value}' : e.value,
  );
  return .ok(body: .fromString('Compare against ${tags.join(', ')}\n'));
}
// end:doctag<headers-get>

// doctag<headers-build>
Response cachedForAnHour(Request req) {
  return .ok(
    headers: Headers.build((h) {
      h.cacheControl = CacheControlHeader(publicCache: true, maxAge: 3600);
      h.etag = const ETagHeader(value: 'v1');
      h['X-Request-Id'] = ['7f3a'];
    }),
    body: .fromString('Keep me for an hour\n'),
  );
}
// end:doctag<headers-build>

// doctag<headers-echo>
Response echoHeader(Request req) {
  final value = req.url.queryParameters['v'] ?? '';
  return .ok(
    headers: Headers.build((h) => h['X-Echo'] = [value]),
    body: .fromString('Echoed $value\n'),
  );
}
// end:doctag<headers-echo>

// doctag<headers-custom>
const rateLimitRemainingHeader = HeaderAccessor<int>(
  HeaderName.custom('x-ratelimit-remaining'),
  HeaderCodec.single(int.parse, encodeRateLimit),
);

Iterable<String> encodeRateLimit(int value) => ['$value'];

extension RateLimitHeaders on HeaderValues {
  int? get rateLimitRemaining => this(rateLimitRemainingHeader);
}

extension RateLimitHeadersSetter on MutableHeaders {
  set rateLimitRemaining(int? value) => assign(rateLimitRemainingHeader, value);
}
// end:doctag<headers-custom>

// doctag<headers-custom-middleware>
Middleware rateLimit(int quota) {
  var remaining = quota;
  return (next) => (req) async {
    if (remaining == 0) return Response(429);
    remaining--;
    final result = await next(req);
    if (result is! Response) return result;
    return result.copyWith(
      headers: result.headers.transform((h) {
        h.rateLimitRemaining = remaining;
      }),
    );
  };
}
// end:doctag<headers-custom-middleware>

Future<void> main() async {
  // doctag<headers-routes>
  final app = RelicApp()
    ..get('/accept', describeAccept)
    ..get('/file', describeRange)
    ..get('/compare', compareETags)
    ..get('/cached', cachedForAnHour)
    ..get('/echo', echoHeader)
    ..use('/api', rateLimit(2))
    ..get('/api/ping', (req) => Response.ok(body: .fromString('pong\n')));
  // end:doctag<headers-routes>

  await app.serve();
}
