import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// Minimal example serving files from the local example/static_files directory.
///
/// - Serves static files under the URL prefix "/static".
/// - Try opening: http://localhost:8080/static/hello.txt
/// - Or:          http://localhost:8080/static/logo.svg
Future<void> main() async {
  final staticDir = File('static_files').absolute.path;

  // Router mounts the static handler under /static/** and shows an index that
  // demonstrates cache-busted URLs.
  final router = Router<Handler>()
    ..get('/', respondWith((final _) async {
      final helloUrl = await withCacheBusting(
        mountPrefix: '/static',
        fileSystemRoot: staticDir,
        staticPath: '/static/hello.txt',
      );
      final logoUrl = await withCacheBusting(
        mountPrefix: '/static',
        fileSystemRoot: staticDir,
        staticPath: '/static/logo.svg',
      );
      final html = '<html><body>'
          '<h1>Static files with cache busting</h1>'
          '<ul>'
          '<li><a href="$helloUrl">hello.txt</a></li>'
          '<li><img src="$logoUrl" alt="logo" height="64" /></li>'
          '</ul>'
          '</body></html>';
      return Response.ok(body: Body.fromString(html, mimeType: MimeType.html));
    }))
    ..get(
        '/static/**',
        createStaticHandler(
          staticDir,
          cacheControl: (final _, final __) => null,
        ));

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(stripCacheBusting('/static'))
      .addMiddleware(routeWith(router))
      .addHandler(respondWith((final _) => Response.notFound()));

  await serve(handler, InternetAddress.loopbackIPv4, 8080);
  // Now open your browser at: http://localhost:8080/
}
