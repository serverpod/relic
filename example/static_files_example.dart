import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// A minimal server that serves static files with cache busting.
///
/// - Serves files under the URL prefix "/static" from `example/static_files`.
/// - Try: http://localhost:8080/
Future<void> main() async {
  final staticDir = Directory('static_files');
  final cacheCfg = CacheBustingConfig(
    mountPrefix: '/static',
    fileSystemRoot: staticDir,
  );

  // Setup router and a small index page showing cache-busted URLs.
  final router = Router<Handler>()
    ..get('/', respondWith((final _) async {
      final helloUrl = await cacheCfg.bust('/static/hello.txt');
      final logoUrl = await cacheCfg.bust('/static/logo.svg');
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
          staticDir.path,
          cacheControl: (final _, final __) => null,
        ));

  // Setup a handler pipeline with logging, cache busting, and routing.
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(cacheBusting(cacheCfg))
      .addMiddleware(routeWith(router))
      .addHandler(respondWith((final _) => Response.notFound()));

  // Start the server
  await serve(handler, InternetAddress.loopbackIPv4, 8080);
}
