import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../static/test_util.dart';

void main() {
  group('Cache busting middleware', () {
    setUp(() async {
      await d.dir('static', [
        d.file('logo.png', 'png-bytes'),
        d.dir('images', [d.file('logo.png', 'nested-bytes')]),
      ]).create();
    });

    test('generates cache-busted URL and serves via root-mounted handler',
        () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final handler = const Pipeline()
          .addMiddleware(cacheBusting(CacheBustingConfig(
            mountPrefix: '/static',
            fileSystemRoot: staticRoot,
          )))
          .addHandler(createStaticHandler(
            staticRoot.path,
            cacheControl: (final _, final __) => null,
          ));

      const original = '/static/logo.png';
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );
      final busted = await cfg.bust(original);
      expect(busted, isNot(original));
      expect(busted, startsWith('/static/logo@'));
      expect(busted, endsWith('.png'));

      final response = await makeRequest(
        handler,
        busted,
        handlerPath: 'static',
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'png-bytes');
    });

    test('works when static handler is mounted under router', () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final router = Router<Handler>()
        ..get(
            '/assets/**',
            createStaticHandler(
              staticRoot.path,
              cacheControl: (final _, final __) => null,
            ));

      final handler = const Pipeline()
          .addMiddleware(cacheBusting(CacheBustingConfig(
            mountPrefix: '/assets',
            fileSystemRoot: staticRoot,
          )))
          .addMiddleware(routeWith(router))
          .addHandler(respondWith((final _) => Response.notFound()));

      const original = '/assets/images/logo.png';
      final cfg = CacheBustingConfig(
        mountPrefix: '/assets',
        fileSystemRoot: staticRoot,
      );
      final busted = await cfg.bust(original);

      final response = await makeRequest(handler, busted);
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'nested-bytes');
    });

    test('works with custom handlerPath mounted under root', () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final handler = const Pipeline()
          .addMiddleware(cacheBusting(CacheBustingConfig(
            mountPrefix: '/static',
            fileSystemRoot: staticRoot,
          )))
          .addHandler(createStaticHandler(
            staticRoot.path,
            cacheControl: (final _, final __) => null,
          ));

      const original = '/static/images/logo.png';
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );
      final busted = await cfg.bust(original);

      final response = await makeRequest(
        handler,
        busted,
        handlerPath: 'static',
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'nested-bytes');
    });
  });
}
