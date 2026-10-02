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
      // What a page handler reads: the agent, the language and a cookie.
      final agent = req.headers.userAgent ?? '';
      final language = req.headers.acceptLanguage?.toString() ?? '';
      final session = req.headers.cookie?.cookies
          .where((final c) => c.name == 'session')
          .firstOrNull
          ?.value;
      return Response.ok(
        body: Body.fromString(
          '${agent.length} ${language.length} ${session?.length ?? 0}',
        ),
      );
    })
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
