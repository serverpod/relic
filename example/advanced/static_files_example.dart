import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// Examples from static-files.md
Future<void> main() async {
  final staticDir = Directory('example/static_files');
  final app = RelicApp();

  // Basic directory serving

  // doctag<static-files-dir-serve>
  app.anyOf(
    {Method.get, Method.head},
    '/basic/**',
    StaticHandler.directory(
      staticDir,
      cacheControl:
          (final ctx, final fileInfo) => CacheControlHeader(maxAge: 86400),
    ).asHandler,
  );
  // end:doctag<static-files-dir-serve>

  // Single file serving

  // doctag<static-files-single-file>
  app.get(
    '/logo.svg',
    StaticHandler.file(
      File('example/static_files/logo.svg'),
      cacheControl:
          (final ctx, final fileInfo) => CacheControlHeader(maxAge: 3600),
    ).asHandler,
  );
  // end:doctag<static-files-single-file>

  // Short-term caching

  // doctag<static-files-cache-short>
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
  // end:doctag<static-files-cache-short>

  // Long-term caching with immutable assets

  // doctag<static-files-cache-long-immutable>
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
  // end:doctag<static-files-cache-long-immutable>

  // Cache busting setup

  // doctag<static-files-cache-busting>
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
  // end:doctag<static-files-cache-busting>

  // Start the server
  await app.serve();
}
