import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'test_util.dart';

void main() {
  group('Given cache busting middleware with a static directory', () {
    setUp(() async {
      await d.dir('static', [
        d.file('logo.png', 'png-bytes'),
        d.dir('images', [d.file('logo.png', 'nested-bytes')]),
      ]).create();
    });

    group('when the static handler is mounted at root', () {
      test(
          'when requesting a busted URL, '
          'then it serves the file', () async {
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

        const busted = '/static/logo@abc.png';

        final response = await makeRequest(
          handler,
          busted,
          handlerPath: 'static',
        );
        expect(response.statusCode, HttpStatus.ok);
        expect(await response.readAsString(), 'png-bytes');
      });
    });

    group('when the static handler is router-mounted', () {
      test(
          'when requesting a busted URL, '
          'then it serves the file', () async {
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

        const busted = '/assets/images/logo@abc.png';

        final response = await makeRequest(handler, busted);
        expect(response.statusCode, HttpStatus.ok);
        expect(await response.readAsString(), 'nested-bytes');
      });
    });

    group('when handlerPath is used under root', () {
      test(
          'when requesting a busted URL, '
          'then it serves the file', () async {
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

        const busted = '/static/images/logo@abc.png';

        final response = await makeRequest(
          handler,
          busted,
          handlerPath: 'static',
        );
        expect(response.statusCode, HttpStatus.ok);
        expect(await response.readAsString(), 'nested-bytes');
      });
    });

    test(
        'when a request is outside mountPrefix, '
        'then middleware does not rewrite', () async {
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

    group('when the request is the mount root with trailing slash', () {
      test(
          'when requesting the directory, '
          'then it is not rewritten', () async {
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
    });

    group('when the request is the mount root without file', () {
      test(
          'when requesting the directory, '
          'then middleware early-returns unchanged', () async {
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
    });

    test(
        'when the filename is not busted, '
        'then middleware serves the file', () async {
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

    group('when the filename starts with @ and has no hash', () {
      test(
          'when requesting the file, '
          'then it is not stripped', () async {
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
    });

    group('when the file has no extension', () {
      test(
          'when requesting a busted URL, '
          'then it serves via middleware', () async {
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

        const busted = '/static/logo@abc';

        final response =
            await makeRequest(handler, busted, handlerPath: 'static');
        expect(response.statusCode, HttpStatus.ok);
        expect(await response.readAsString(), 'content-noext');
      });
    });

    group('when a custom separator is configured', () {
      test(
          'when requesting a busted URL, '
          'then it serves the file', () async {
        final staticRoot = Directory(p.join(d.sandbox, 'static'));
        final cfg = CacheBustingConfig(
          mountPrefix: '/static',
          fileSystemRoot: staticRoot,
          separator: '--',
        );
        final handler = const Pipeline()
            .addMiddleware(cacheBusting(cfg))
            .addHandler(createStaticHandler(
              staticRoot.path,
              cacheControl: (final _, final __) => null,
            ));

        const busted = '/static/logo--abc.png';

        final response =
            await makeRequest(handler, busted, handlerPath: 'static');
        expect(response.statusCode, HttpStatus.ok);
        expect(await response.readAsString(), 'png-bytes');
      });
    });

    group('when the filename starts with the separator and has no hash', () {
      test(
          'when requesting the file, '
          'then it is not stripped', () async {
        // Create a file that starts with the separator characters
        await d.file(p.join('static', '--plain.txt'), 'dashdash').create();

        final staticRoot = Directory(p.join(d.sandbox, 'static'));
        final cfg = CacheBustingConfig(
          mountPrefix: '/static',
          fileSystemRoot: staticRoot,
          separator: '--',
        );
        final handler = const Pipeline()
            .addMiddleware(cacheBusting(cfg))
            .addHandler(createStaticHandler(
              staticRoot.path,
              cacheControl: (final _, final __) => null,
            ));

        final response = await makeRequest(handler, '/static/--plain.txt',
            handlerPath: 'static');
        expect(response.statusCode, HttpStatus.ok);
        expect(await response.readAsString(), 'dashdash');
      });
    });

    group('when a directory name contains @', () {
      test(
          'when requesting a busted URL, '
          'then only the filename is affected', () async {
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

        const busted = '/static/img@foo/logo@abc.png';

        final response =
            await makeRequest(handler, busted, handlerPath: 'static');
        expect(response.statusCode, HttpStatus.ok);
        expect(await response.readAsString(), 'dir-at-bytes');
      });
    });
    group('when a filename starts with @', () {
      test(
          'when requesting a busted URL, '
          'then it serves the file', () async {
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

        const busted = '/static/@logo@abc.png';

        final response =
            await makeRequest(handler, busted, handlerPath: 'static');
        expect(response.statusCode, HttpStatus.ok);
        expect(await response.readAsString(), 'at-logo');
      });
    });
  });
}
