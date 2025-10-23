import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// Examples from static-files.md
Future<void> main() async {
  final staticDir = Directory('example/static_files');
  final app = RelicApp();

  // Basic directory serving

  app.anyOf(
    {Method.get, Method.head},
    '/basic/**',
    StaticHandler.directory(
      staticDir,
      cacheControl:
          (final ctx, final fileInfo) => CacheControlHeader(maxAge: 86400),
    ).asHandler,
  );

  // Single file serving

  app.get(
    '/logo.svg',
    StaticHandler.file(
      File('example/static_files/logo.svg'),
      cacheControl:
          (final ctx, final fileInfo) => CacheControlHeader(maxAge: 3600),
    ).asHandler,
  );

  // Short-term caching

  app.anyOf(
    {Method.get, Method.head},
    '/short-cache/**',
    StaticHandler.directory(
      staticDir,
      cacheControl:
          (final ctx, final fileInfo) => CacheControlHeader(
            maxAge: 3600, // 1 hour
            publicCache: true, // Allow CDN caching
          ),
    ).asHandler,
  );

  // Long-term caching with immutable assets

  app.anyOf(
    {Method.get, Method.head},
    '/long-cache/**',
    StaticHandler.directory(
      staticDir,
      cacheControl:
          (final ctx, final fileInfo) => CacheControlHeader(
            maxAge: 31536000, // 1 year
            publicCache: true,
            immutable: true, // Browser won't revalidate
          ),
    ).asHandler,
  );

  // Cache busting setup

  final buster = CacheBustingConfig(
    mountPrefix: '/static',
    fileSystemRoot: staticDir,
  );

  // Index page showing cache-busted URLs
  app.get(
    '/',
    respondWith((final _) async {
      final helloUrl = await buster.assetPath('/static/hello.txt');
      final logoUrl = await buster.assetPath('/static/logo.svg');
      final html =
          '<html><body>'
          '<h1>Static files with cache busting</h1>'
          '<ul>'
          '<li><a href="$helloUrl">hello.txt</a></li>'
          '<li><img src="$logoUrl" alt="logo" height="64" /></li>'
          '</ul>'
          '</body></html>';
      return Response.ok(body: Body.fromString(html, mimeType: MimeType.html));
    }),
  );

  // Serve static files with cache busting
  app.anyOf(
    {Method.get, Method.head},
    '/static/**',
    StaticHandler.directory(
      staticDir,
      cacheControl:
          (final ctx, final fileInfo) => CacheControlHeader(
            maxAge: 31536000, // 1 year - safe with cache busting
            publicCache: true,
            immutable: true,
          ),
      cacheBustingConfig: buster,
    ).asHandler,
  );

  // Start the server
  await app.serve();
}
