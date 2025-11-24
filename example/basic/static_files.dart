import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// Demonstrates various static file serving patterns and caching strategies.
Future<void> main() async {
  final staticDir = Directory('example/_static_files');
  final app = RelicApp();

  // Serve all files from a directory with basic caching.

  // doctag<static-files-dir-serve>
  app.anyOf(
    {Method.get, Method.head},
    '/basic/**',
    StaticHandler.directory(
      staticDir,
      cacheControl:
          (final req, final fileInfo) => CacheControlHeader(maxAge: 86400),
    ).asHandler,
  );
  // end:doctag<static-files-dir-serve>

  // Serve a specific file with custom cache settings.

  // doctag<static-files-single-file>
  app.get(
    '/logo.svg',
    StaticHandler.file(
      File('example/_static_files/logo.svg'),
      cacheControl:
          (final req, final fileInfo) => CacheControlHeader(maxAge: 3600),
    ).asHandler,
  );
  // end:doctag<static-files-single-file>

  // Configure short-term caching for frequently updated content.

  // doctag<static-files-cache-short>
  app.anyOf(
    {Method.get, Method.head},
    '/short-cache/**',
    StaticHandler.directory(
      staticDir,
      cacheControl:
          (final req, final fileInfo) => CacheControlHeader(
            // Cache for 1 hour.
            maxAge: 3600,
            // Enable CDN and proxy caching.
            publicCache: true,
          ),
    ).asHandler,
  );
  // end:doctag<static-files-cache-short>

  // Configure long-term caching for immutable assets.

  // doctag<static-files-cache-long-immutable>
  app.anyOf(
    {Method.get, Method.head},
    '/long-cache/**',
    StaticHandler.directory(
      staticDir,
      cacheControl:
          (final req, final fileInfo) => CacheControlHeader(
            // Cache for 1 year.
            maxAge: 31536000,
            publicCache: true,
            // Tell browsers never to revalidate.
            immutable: true,
          ),
    ).asHandler,
  );
  // end:doctag<static-files-cache-long-immutable>

  // Set up cache busting for versioned assets.

  // doctag<static-files-cache-busting>
  final buster = CacheBustingConfig(
    mountPrefix: '/static',
    fileSystemRoot: staticDir,
  );

  // Create an index page that demonstrates cache-busted URLs.
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

  // Serve static files with automatic cache busting.
  app.anyOf(
    {Method.get, Method.head},
    '/static/**',
    StaticHandler.directory(
      staticDir,
      cacheControl:
          (final req, final fileInfo) => CacheControlHeader(
            // Safe to cache long term with versioning.
            maxAge: 31536000,
            publicCache: true,
            immutable: true,
          ),
      cacheBustingConfig: buster,
    ).asHandler,
  );
  // end:doctag<static-files-cache-busting>

  // Start the server and begin serving static files.
  await app.serve();
}
