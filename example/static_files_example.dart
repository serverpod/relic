// ignore_for_file: avoid_print

import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

/// A minimal server that serves static files with cache busting.
///
/// - Serves files under the URL prefix "/static" from `example/static_files`.
/// - Try: http://localhost:8080/
Future<void> main() async {
  final staticDir = Directory('static_files');
  if (!staticDir.existsSync()) {
    print('Please run this example from example directory (cd example).');
    return;
  }
  final buster = CacheBustingConfig(
    mountPrefix: '/static',
    fileSystemRoot: staticDir,
  );

  // Setup router and a small index page showing cache-busted URLs. We're
  // setting the cache control header to immutable for a year.
  final router = Router<Handler>()
    ..get('/', respondWith((final _) async {
      final helloUrl = await buster.assetPath('/static/hello.txt');
      final logoUrl = await buster.assetPath('/static/logo.svg');
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
          cacheControl: (final _, final __) => CacheControlHeader(
            maxAge: 31536000,
            publicCache: true,
            immutable: true,
          ),
          cacheBustingConfig: buster,
        ));

  // Setup a handler pipeline with logging, cache busting, and routing.
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(routeWith(router))
      .addHandler(respondWith((final _) => Response.notFound()));

  // Start the server
  await serve(handler, InternetAddress.loopbackIPv4, 8080);
}
