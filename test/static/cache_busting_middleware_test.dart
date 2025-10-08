import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'test_util.dart';

void main() {
  group(
      'Given a static asset served through a root-mounted cache busting middleware',
      () {
    late Handler handler;
    setUp(() async {
      await d.dir('static', [d.file('logo.png', 'png-bytes')]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      handler = const Pipeline()
          .addMiddleware(cacheBusting(CacheBustingConfig(
            mountPrefix: '/static',
            fileSystemRoot: staticRoot,
          )))
          .addHandler(createStaticHandler(
            staticRoot.path,
            cacheControl: (final _, final __) => null,
          ));
    });

    test('when requesting asset with a non-busted URL then it serves the asset',
        () async {
      final response =
          await makeRequest(handler, '/static/logo.png', handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'png-bytes');
    });

    test(
        'when requesting asset with a cache busted URL then it serves the asset',
        () async {
      final response = await makeRequest(handler, '/static/logo@abc.png',
          handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'png-bytes');
    });
  });

  group(
      'Given a static asset served through a router-mounted static handler and pipeline mounted cache busting middleware',
      () {
    late Handler handler;
    setUp(() async {
      await d.dir('static', [d.file('logo.png', 'png-bytes')]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final router = Router<Handler>()
        ..get(
            '/static/**',
            createStaticHandler(
              staticRoot.path,
              cacheControl: (final _, final __) => null,
            ));

      handler = const Pipeline()
          .addMiddleware(cacheBusting(CacheBustingConfig(
            mountPrefix: '/static',
            fileSystemRoot: staticRoot,
          )))
          .addMiddleware(routeWith(router))
          .addHandler(respondWith((final _) => Response.notFound()));
    });

    test('when requesting asset with a non-busted URL then it serves the asset',
        () async {
      final response = await makeRequest(handler, '/static/logo.png');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'png-bytes');
    });

    test(
        'when requesting asset with a cache busted URL then it serves the asset',
        () async {
      final response = await makeRequest(handler, '/static/logo@abc.png');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'png-bytes');
    });
  });

  test(
      'Given a cache busting middleware when the request is the mount root then middleware early-returns unchanged',
      () async {
    await d.dir('static').create();
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

    final response = await makeRequest(handler, '/static/@abs');
    expect(response.statusCode, HttpStatus.ok);
    expect(await response.readAsString(), '/static/@abs');
  });

  group('Given static asset served outside of cache busting mountPrefix', () {
    late Handler handler;

    setUp(() async {
      await d.dir('other', [d.file('logo.png', 'png-bytes')]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'other'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );

      handler = const Pipeline()
          .addMiddleware(cacheBusting(cfg))
          .addHandler(createStaticHandler(
            staticRoot.path,
            cacheControl: (final _, final __) => null,
          ));
    });

    test('when requesting asset with a non-busted URL then it serves the asset',
        () async {
      final response =
          await makeRequest(handler, '/other/logo.png', handlerPath: 'other');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'png-bytes');
    });

    test(
        'when requesting asset with a busted URL then URL is not rewritten resulting in asset not being found',
        () async {
      final response = await makeRequest(handler, '/other/logo@abc.png',
          handlerPath: 'other');
      expect(response.statusCode, HttpStatus.notFound);
    });
  });

  group(
      'Given a static asset with a filename starting with separator served through cache busting middleware',
      () {
    late Handler handler;
    setUp(() async {
      await d.dir('static', [d.file('@logo.png', 'png-bytes')]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
        separator: '@',
      );
      handler = const Pipeline()
          .addMiddleware(cacheBusting(cfg))
          .addHandler(createStaticHandler(
            staticRoot.path,
            cacheControl: (final _, final __) => null,
          ));
    });

    test('when requesting asset with a non-busted URL then it serves the asset',
        () async {
      final response = await makeRequest(handler, '/static/@logo.png',
          handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'png-bytes');
    });

    test(
        'when requesting asset with a cache busted URL then it serves the asset',
        () async {
      final response = await makeRequest(handler, '/static/@logo@abc.png',
          handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'png-bytes');
    });
  });

  group(
      'Given a static asset without extension served through cache busting middleware',
      () {
    late Handler handler;
    setUp(() async {
      await d.dir('static', [d.file('logo', 'file-contents')]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
        separator: '@',
      );
      handler = const Pipeline()
          .addMiddleware(cacheBusting(cfg))
          .addHandler(createStaticHandler(
            staticRoot.path,
            cacheControl: (final _, final __) => null,
          ));
    });

    test('when requesting asset with a non-busted URL then it serves the asset',
        () async {
      final response =
          await makeRequest(handler, '/static/logo', handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'file-contents');
    });

    test(
        'when requesting asset with a cache busted URL then it serves the asset',
        () async {
      final response =
          await makeRequest(handler, '/static/logo@abc', handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'file-contents');
    });
  });

  group(
      'Given a static asset served through cache busting middleware with a custom separator',
      () {
    late Handler handler;
    setUp(() async {
      await d.dir('static', [d.file('logo.png', 'png-bytes')]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
        separator: '--',
      );
      handler = const Pipeline()
          .addMiddleware(cacheBusting(cfg))
          .addHandler(createStaticHandler(
            staticRoot.path,
            cacheControl: (final _, final __) => null,
          ));
    });

    test('when requesting asset with a non-busted URL then it serves the asset',
        () async {
      final response =
          await makeRequest(handler, '/static/logo.png', handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'png-bytes');
    });

    test(
        'when requesting asset with a cache busted URL using the custom separator then it serves the asset',
        () async {
      final response = await makeRequest(handler, '/static/logo--abc.png',
          handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'png-bytes');
    });

    test(
        'when requesting asset with a cache busted URL using the default separator then it does not find the asset',
        () async {
      final response = await makeRequest(handler, '/static/logo@abc.png',
          handlerPath: 'static');
      expect(response.statusCode, HttpStatus.notFound);
    });
  });

  group('Given a static asset in a nested directory containing the separator',
      () {
    late Handler handler;
    setUp(() async {
      await d.dir('static', [
        d.dir('@images', [d.file('logo.png', 'nested-bytes')])
      ]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
        separator: '@',
      );
      handler = const Pipeline()
          .addMiddleware(cacheBusting(cfg))
          .addHandler(createStaticHandler(
            staticRoot.path,
            cacheControl: (final _, final __) => null,
          ));
    });

    test('when requesting asset with a non-busted URL then it serves the asset',
        () async {
      final response = await makeRequest(handler, '/static/@images/logo.png',
          handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'nested-bytes');
    });

    test(
        'when requesting asset with a cache busted URL then it serves the asset',
        () async {
      final response = await makeRequest(
          handler, '/static/@images/logo@abc.png',
          handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'nested-bytes');
    });
  });

  group(
      'Given a static asset served through a router-mounted static handler and cache busting middleware',
      () {
    late Handler handler;
    setUp(() async {
      await d.dir('static', [d.file('logo.png', 'png-bytes')]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final router = Router<Handler>()
        ..get(
            '/static/**',
            createStaticHandler(
              staticRoot.path,
              cacheControl: (final _, final __) => null,
            ))
        ..use(
            '/static/**',
            cacheBusting(CacheBustingConfig(
              mountPrefix: '/static',
              fileSystemRoot: staticRoot,
            )));

      handler = const Pipeline()
          .addMiddleware(routeWith(router))
          .addHandler(respondWith((final _) => Response.notFound()));
    });

    test('when requesting asset with a non-busted URL then it serves the asset',
        () async {
      final response = await makeRequest(handler, '/static/logo.png');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'png-bytes');
    });

    test(
        'when requesting asset with a cache busted URL then it serves the asset',
        () async {
      final response = await makeRequest(handler, '/static/logo@abc.png');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'png-bytes');
    });
  });
}
