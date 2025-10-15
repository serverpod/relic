import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'test_util.dart';

void main() {
  group(
      'Given a static asset served through a root-mounted cache busting static file handler',
      () {
    late Handler handler;
    setUp(() async {
      await d.dir('static', [d.file('logo.png', 'png-bytes')]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      handler = const Pipeline().addHandler(createStaticHandler(
        staticRoot.path,
        cacheControl: (final _, final __) => null,
        cacheBustingConfig: CacheBustingConfig(
          mountPrefix: '/static',
          fileSystemRoot: staticRoot,
          separator: '@',
        ),
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
      'Given a static asset served through a router-mounted cache busting static handler',
      () {
    late Handler handler;
    setUp(() async {
      await d.dir('static', [d.file('logo.png', 'png-bytes')]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final router = RelicRouter()
        ..get(
            '/static/**',
            createStaticHandler(
              staticRoot.path,
              cacheControl: (final _, final __) => null,
              cacheBustingConfig: CacheBustingConfig(
                mountPrefix: '/static',
                fileSystemRoot: staticRoot,
                separator: '@',
              ),
            ));

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

  group('Given static asset served outside of cache busting mountPrefix', () {
    late Handler handler;

    setUp(() async {
      await d.dir('other', [d.file('logo.png', 'png-bytes')]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'other'));
      handler = const Pipeline().addHandler(createStaticHandler(
        staticRoot.path,
        cacheControl: (final _, final __) => null,
        cacheBustingConfig: CacheBustingConfig(
          mountPrefix: '/static',
          fileSystemRoot: staticRoot,
          separator: '@',
        ),
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
        'when requesting asset with a busted URL then it still serves the asset (handler-level cache busting)',
        () async {
      final response = await makeRequest(handler, '/other/logo@abc.png',
          handlerPath: 'other');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'png-bytes');
    });
  });

  group(
      'Given a static asset with a filename starting with separator served through cache busting static file handler',
      () {
    late Handler handler;
    setUp(() async {
      await d.dir('static', [d.file('@logo.png', 'png-bytes')]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      handler = const Pipeline().addHandler(createStaticHandler(
        staticRoot.path,
        cacheControl: (final _, final __) => null,
        cacheBustingConfig: CacheBustingConfig(
          mountPrefix: '/static',
          fileSystemRoot: staticRoot,
          separator: '@',
        ),
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
      'Given a static asset without extension served through cache busting static file handler',
      () {
    late Handler handler;
    setUp(() async {
      await d.dir('static', [d.file('logo', 'file-contents')]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      handler = const Pipeline().addHandler(createStaticHandler(
        staticRoot.path,
        cacheControl: (final _, final __) => null,
        cacheBustingConfig: CacheBustingConfig(
          mountPrefix: '/static',
          fileSystemRoot: staticRoot,
          separator: '@',
        ),
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
      'Given a static asset served through cache busting static file handler with a custom separator',
      () {
    late Handler handler;
    setUp(() async {
      await d.dir('static', [d.file('logo.png', 'png-bytes')]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      handler = const Pipeline().addHandler(createStaticHandler(
        staticRoot.path,
        cacheControl: (final _, final __) => null,
        cacheBustingConfig: CacheBustingConfig(
          mountPrefix: '/static',
          fileSystemRoot: staticRoot,
          separator: '--',
        ),
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

  group(
      'Given a static asset served through cache busting static handler in a nested directory containing the separator',
      () {
    late Handler handler;
    setUp(() async {
      await d.dir('static', [
        d.dir('@images', [d.file('logo.png', 'nested-bytes')])
      ]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      handler = const Pipeline().addHandler(createStaticHandler(
        staticRoot.path,
        cacheControl: (final _, final __) => null,
        cacheBustingConfig: CacheBustingConfig(
          mountPrefix: '/static',
          fileSystemRoot: staticRoot,
          separator: '@',
        ),
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
      'Given a static handler configured with CacheBustingConfig that has different fileSystemRoot',
      () {
    late Handler handler;
    setUp(() async {
      await d.dir('static', [
        d.dir('images', [d.file('logo.png', 'nested-bytes')])
      ]).create();
      await d.dir('cache', []).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cacheRoot = Directory(p.join(d.sandbox, 'cache'));
      handler = const Pipeline().addHandler(createStaticHandler(
        staticRoot.path,
        cacheControl: (final _, final __) => null,
        cacheBustingConfig: CacheBustingConfig(
          mountPrefix: '/cache',
          fileSystemRoot: cacheRoot,
          separator: '@',
        ),
      ));
    });

    test('when requesting asset with a non-busted URL then it serves the asset',
        () async {
      final response = await makeRequest(handler, '/static/images/logo.png',
          handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'nested-bytes');
    });

    test(
        'when requesting asset with a cache busted URL then it still serves the asset (handler-level cache busting)',
        () async {
      final response = await makeRequest(handler, '/static/images/logo@abc.png',
          handlerPath: 'static');
      expect(response.statusCode, HttpStatus.ok);
      expect(await response.readAsString(), 'nested-bytes');
    });
  });
}
