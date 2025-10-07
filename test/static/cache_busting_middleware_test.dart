import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'test_util.dart';

void main() {
  group('Given cache busting middleware and a static directory', () {
    setUp(() async {
      await d.dir('static', [
        d.file('logo.png', 'png-bytes'),
        d.dir('images', [d.file('logo.png', 'nested-bytes')]),
      ]).create();
    });

    test(
        'when the static handler is mounted at root then requesting a busted URL serves the file',
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
      final busted = await cfg.assetPath(original);
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

    test(
        'and the static handler is router-mounted when requesting a busted URL then it serves the file',
        () async {
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
      final busted = await cfg.assetPath(original);

      final response = await makeRequest(handler, busted);
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'nested-bytes');
    });

    test(
        'and handlerPath is used under root when requesting a busted URL then it serves the file',
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

      const original = '/static/images/logo.png';
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );
      final busted = await cfg.assetPath(original);

      final response = await makeRequest(
        handler,
        busted,
        handlerPath: 'static',
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'nested-bytes');
    });

    test(
        'when bust is called for a missing file then it throws PathNotFoundException',
        () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );

      expect(
        cfg.assetPath('/static/does-not-exist.txt'),
        throwsA(isA<PathNotFoundException>()),
      );
    });

    test(
        'when traversal attempts are made then bust rejects paths outside root',
        () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );

      expect(
        cfg.assetPath('/static/../secret.txt'),
        throwsA(isA<ArgumentError>()),
      );

      // Also reject absolute after mount
      expect(
        cfg.assetPath('/static//etc/passwd'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
        'and a symlink escapes the root when calling bust then it rejects paths outside root',
        () async {
      // Create a file outside the static root
      final outsidePath = p.join(d.sandbox, 'outside.txt');
      await File(outsidePath).writeAsString('outside');

      // Create a symlink inside static pointing to the outside file
      final linkPath = p.join(d.sandbox, 'static', 'escape.txt');
      final link = Link(linkPath);
      try {
        // Use absolute target to be explicit
        await link.create(outsidePath);
      } on FileSystemException {
        // If the platform forbids symlinks, skip this test gracefully
        return;
      }

      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );

      expect(
        cfg.assetPath('/static/escape.txt'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
        'when tryBust is called for a missing file then it returns the original path',
        () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );

      const original = '/static/does-not-exist.txt';
      final result = await cfg.tryBust(original);
      expect(result, original);
    });

    test(
        'when the path is outside mountPrefix then bust/tryBust return it unchanged',
        () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );

      const outside = '/other/logo.png';
      expect(await cfg.tryBust(outside), outside);
      expect(await cfg.assetPath(outside), outside);
    });

    test(
        'when a request is outside mountPrefix then middleware does not rewrite',
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

      final response = await makeRequest(handler, '/other/logo.png');
      expect(response.statusCode, HttpStatus.notFound);
    });

    test(
        'and the request is the mount root (trailing slash) then it is not rewritten',
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

      // Requesting the mount prefix itself should not be rewritten and
      // directory listings are not supported -> 404.
      final response =
          await makeRequest(handler, '/static/', handlerPath: 'static');
      expect(response.statusCode, HttpStatus.notFound);
    });

    test(
        'and the request is the mount root then middleware early-returns unchanged',
        () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );

      // Echo handler to observe the requestedUri.path after middleware.
      final handler = const Pipeline()
          .addMiddleware(cacheBusting(cfg))
          .addHandler(respondWith((final ctx) =>
              Response.ok(body: Body.fromString(ctx.requestedUri.path))));

      final response = await makeRequest(handler, '/static/');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), '/static/');
    });

    test('and the filename is not busted then middleware serves the file',
        () async {
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

    test(
        'and the filename starts with @ and has no hash then it is not stripped',
        () async {
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

    test(
        'when creating config with invalid mountPrefix then it throws ArgumentError',
        () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      expect(
        () => CacheBustingConfig(
          mountPrefix: 'static',
          fileSystemRoot: staticRoot,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
        'and the file has no extension when calling bust then it serves via middleware',
        () async {
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
      final busted = await cfg.assetPath(original);
      expect(busted, startsWith('/static/logo@'));
      expect(busted, isNot(endsWith('.')));

      final response =
          await makeRequest(handler, busted, handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'content-noext');
    });

    test(
        'and a directory name contains @ when calling bust then only the filename is affected',
        () async {
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
      final busted = await cfg.assetPath(original);
      expect(busted, startsWith('/static/img@foo/logo@'));
      expect(busted, endsWith('.png'));

      final response =
          await makeRequest(handler, busted, handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'dir-at-bytes');
    });

    test(
        'Given a filename starting with @ when calling bust then it busts and strips correctly',
        () async {
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
      final busted = await cfg.assetPath(original);
      expect(busted, startsWith('/static/@logo@'));
      expect(busted, endsWith('.png'));

      final response =
          await makeRequest(handler, busted, handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'at-logo');
    });
  });
}
