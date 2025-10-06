import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'test_util.dart';

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

    test('bust throws when file does not exist', () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );

      expect(
        cfg.bust('/static/does-not-exist.txt'),
        throwsA(isA<PathNotFoundException>()),
      );
    });

    test('tryBust returns original path when file does not exist', () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );

      const original = '/static/does-not-exist.txt';
      final result = await cfg.tryBust(original);
      expect(result, original);
    });

    test('bust/tryBust leave paths outside mountPrefix unchanged', () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );

      const outside = '/other/logo.png';
      expect(await cfg.tryBust(outside), outside);
      expect(await cfg.bust(outside), outside);
    });

    test('middleware does not rewrite when not under mount prefix', () async {
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

      final response = await makeRequest(handler, '/other/logo.png');
      expect(response.statusCode, HttpStatus.notFound);
    });

    test('middleware does not rewrite trailing-slash requests (empty basename)',
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

      // Requesting a directory trailing slash should not be rewritten and
      // directory listings are not supported -> 404.
      final response =
          await makeRequest(handler, '/static/images/', handlerPath: 'static');
      expect(response.statusCode, HttpStatus.notFound);
    });

    test('middleware passes through non-busted filenames (no @)', () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );
      final handler = const Pipeline()
          .addMiddleware(cacheBusting(cfg))
          .addHandler(createStaticHandler(
            staticRoot.path,
            cacheControl: (final _, final __) => null,
          ));

      final response =
          await makeRequest(handler, '/static/logo.png', handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'png-bytes');
    });

    test('middleware does not strip leading @ when no hash present', () async {
      await d.file(p.join('static', '@plain.txt'), 'plain-at').create();

      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );
      final handler = const Pipeline()
          .addMiddleware(cacheBusting(cfg))
          .addHandler(createStaticHandler(
            staticRoot.path,
            cacheControl: (final _, final __) => null,
          ));

      final response = await makeRequest(handler, '/static/@plain.txt',
          handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'plain-at');
    });

    test('invalid mountPrefix throws (must start with /)', () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      expect(
        () => CacheBustingConfig(
          mountPrefix: 'static',
          fileSystemRoot: staticRoot,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('bust/no-ext works and serves via middleware', () async {
      // Add a no-extension file
      await d.file(p.join('static', 'logo'), 'content-noext').create();

      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );
      final handler = const Pipeline()
          .addMiddleware(cacheBusting(cfg))
          .addHandler(createStaticHandler(
            staticRoot.path,
            cacheControl: (final _, final __) => null,
          ));

      const original = '/static/logo';
      final busted = await cfg.bust(original);
      expect(busted, startsWith('/static/logo@'));
      expect(busted, isNot(endsWith('.')));

      final response =
          await makeRequest(handler, busted, handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'content-noext');
    });

    test('directory name containing @ is not affected', () async {
      // Add nested directory with @ in its name
      await d.dir(p.join('static', 'img@foo'), [
        d.file('logo.png', 'dir-at-bytes'),
      ]).create();

      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );
      final handler = const Pipeline()
          .addMiddleware(cacheBusting(cfg))
          .addHandler(createStaticHandler(
            staticRoot.path,
            cacheControl: (final _, final __) => null,
          ));

      const original = '/static/img@foo/logo.png';
      final busted = await cfg.bust(original);
      expect(busted, startsWith('/static/img@foo/logo@'));
      expect(busted, endsWith('.png'));

      final response =
          await makeRequest(handler, busted, handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'dir-at-bytes');
    });

    test('filename starting with @ busts and strips correctly', () async {
      await d.file(p.join('static', '@logo.png'), 'at-logo').create();

      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );
      final handler = const Pipeline()
          .addMiddleware(cacheBusting(cfg))
          .addHandler(createStaticHandler(
            staticRoot.path,
            cacheControl: (final _, final __) => null,
          ));

      const original = '/static/@logo.png';
      final busted = await cfg.bust(original);
      expect(busted, startsWith('/static/@logo@'));
      expect(busted, endsWith('.png'));

      final response =
          await makeRequest(handler, busted, handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'at-logo');
    });
  });
}
