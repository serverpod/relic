import 'dart:convert';
import 'dart:math';

import 'package:relic/relic.dart';

/// The routes of bin/http_load.dart, so bin/load_serve.dart can serve them
/// on their own for a profiler or a load tool started elsewhere.
RelicApp loadApp() {
  final random = Random(1);
  // A Body is read once, so every response gets its own.
  Body hello() => Body.fromString('Hello, World!');
  return RelicApp()
    ..get('/plaintext', (final req) => Response.ok(body: hello()))
    ..get(
      '/json',
      (final req) => Response.ok(
        body: Body.fromString(
          jsonEncode({'message': 'Hello, World!'}),
          mimeType: MimeType.json,
        ),
      ),
    )
    ..get('/headers', (final req) {
      // What a page handler reads: the agent, the languages and a cookie.
      final agent = req.headers.userAgent ?? '';
      final languages = req.headers.acceptLanguage?.values.length ?? 0;
      final session = req.headers.cookie?.cookies
          .where((final c) => c.name == 'session')
          .firstOrNull
          ?.value;
      return Response.ok(
        body: Body.fromString(
          '${agent.length} $languages ${session?.length ?? 0}',
        ),
      );
    })
    ..get('/browser', _browser)
    ..get('/alloc', (final req) {
      // Garbage per request: a few thousand short-lived objects and a
      // 64 KiB string built from them.
      final parts = List.generate(4000, (final i) => 'item-$i-${i * 7}');
      final text = parts.join(',');
      return Response.ok(body: Body.fromString(text.substring(0, 1024)));
    })
    ..get('/mixed', (final req) async {
      // One request in a hundred waits on something slow.
      if (random.nextInt(100) == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return Response.ok(body: hello());
    });
}

/// A page handler on a real browser head.
///
/// It reads the host, a cookie and the validator, and answers with etag,
/// cache-control and 1 KB of JSON, or 304 when the validator matches.
Response _browser(final Request req) {
  final host = req.headers.host?.host;
  final session = req.headers.cookie?.cookies
      .where((final c) => c.name == 'session')
      .firstOrNull
      ?.value;
  final matched =
      req.headers.ifNoneMatch?.etags.any((final e) => e.value == _etag.value) ??
      false;
  if (matched) {
    return Response.notModified(
      headers: Headers.build((final h) => h.etag = _etag),
    );
  }
  return Response.ok(
    headers: Headers.build(
      (final h) => h
        ..etag = _etag
        ..cacheControl = CacheControlHeader(privateCache: true, maxAge: 60),
    ),
    body: Body.fromString(
      '{"host":${jsonEncode(host)},"session":${jsonEncode(session)},'
      '"items":$_items}',
      mimeType: MimeType.json,
    ),
  );
}

const _etag = ETagHeader(value: 'relic-browser-1');

final _items = jsonEncode([
  for (var i = 0; i < 20; i++)
    {
      'id': i,
      'name': 'item $i',
      'tags': ['new', 'sale'],
      'price': 100 + i,
    },
]);
