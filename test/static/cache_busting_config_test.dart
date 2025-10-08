import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  test(
      'Given mountPrefix not starting with "/" when creating CacheBustingConfig then it throws ArgumentError',
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
      'Given empty separator when creating CacheBustingConfig then it throws ArgumentError',
      () async {
    final staticRoot = Directory(p.join(d.sandbox, 'static'));
    expect(
      () => CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
        separator: '',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test(
      'Given no directory at staticRoot when creating CacheBustingConfig then it throws ArgumentError',
      () {
    final staticRoot = Directory(p.join(d.sandbox, 'static'));
    expect(
      () => CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
        separator: '',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test(
      'Given file at staticRoot when creating CacheBustingConfig then it throws ArgumentError',
      () async {
    await d.file('static', 'content').create();
    final staticRoot = Directory(p.join(d.sandbox, 'static'));
    expect(
      () => CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
        separator: '',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  group('Given CacheBustingConfig configured for a directory without files',
      () {
    late CacheBustingConfig cfg;
    setUp(() async {
      await d.dir('static', []).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );
    });

    test(
        'when assetPath is called for a missing file then it throws PathNotFoundException',
        () async {
      expect(
        cfg.assetPath('/static/does-not-exist.txt'),
        throwsA(isA<PathNotFoundException>()),
      );
    });

    test(
        'when tryAssetPath is called for a missing file then it returns the original path',
        () async {
      const original = '/static/does-not-exist.txt';
      final result = await cfg.tryAssetPath(original);
      expect(result, original);
    });
  });
  group(
      'Given CacheBustingConfig without explicit separator configured for a directory with files',
      () {
    late CacheBustingConfig cfg;
    setUp(() async {
      await d.dir('static', [d.file('logo.png', 'png-bytes')]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );
    });

    test(
        'when assetPath is called for existing file then default cache busting separator is "@"',
        () async {
      const original = '/static/logo.png';
      final busted = await cfg.assetPath(original);
      expect(busted, contains('@'));
    });
  });

  group('Given CacheBustingConfig configured for a directory with files', () {
    late CacheBustingConfig cfg;
    setUp(() async {
      await d.dir('static', [d.file('logo.png', 'png-bytes')]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
        separator: '@',
      );
    });

    test(
        'when assetPath is called for an existing file then it returns a cache busted path',
        () async {
      const original = '/static/logo.png';
      final busted = await cfg.assetPath(original);
      expect(busted, startsWith('/static/logo@'));
    });

    test(
        'when tryAssetPath is called for an existing file then it returns a cache busted path',
        () async {
      const original = '/static/logo.png';
      final busted = await cfg.tryAssetPath(original);
      expect(busted, startsWith('/static/logo@'));
    });

    test(
        'when assetPath is called with an absolute path segment after mount then argument error is thrown',
        () async {
      expect(
        cfg.assetPath('/static//logo.png'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
        'when tryAssetPath is called with an absolute path segment after mount then it returns the original path',
        () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );

      const original = '/static//logo.png';
      expect(await cfg.tryAssetPath(original), original);
    });
  });

  group('Given files outside of CacheBustingConfig fileSystemRoot', () {
    late CacheBustingConfig cfg;
    setUp(() async {
      await d.dir('static', [d.file('logo.png', 'png-bytes')]).create();
      await d.file('secret.txt', 'top-secret').create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );
    });

    test(
        'when assetPath is called for a path that traverses outside of the mount prefix then it throws ArgumentError',
        () async {
      expect(
        cfg.assetPath('/static/../secret.txt'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
        'when assetPath is called for a path outside of the mount prefix then it returns it unchanged',
        () async {
      const outside = '/secret.txt';
      expect(await cfg.assetPath(outside), outside);
    });

    test(
        'when tryAssetPath is called for a path outside of mount prefix then returns it unchanged',
        () async {
      const outside = '/secret.txt';
      expect(await cfg.tryAssetPath(outside), outside);
    });
  });

  test(
      'Given file without extension in CacheBustingConfig directory when calling assetPath then it returns a cache busting path',
      () async {
    await d.dir('static', [d.file('logo', 'content-noext')]).create();
    final staticRoot = Directory(p.join(d.sandbox, 'static'));
    final cfg = CacheBustingConfig(
      mountPrefix: '/static',
      fileSystemRoot: staticRoot,
      separator: '@',
    );

    const original = '/static/logo';
    final busted = await cfg.assetPath(original);
    expect(busted, startsWith('/static/logo@'));
  });

  test(
      'Given a CacheBustingConfig with custom separator when calling assetPath then it uses that separator',
      () async {
    await d.dir('static', [d.file('logo.png', 'png-bytes')]).create();
    final staticRoot = Directory(p.join(d.sandbox, 'static'));
    final cfg = CacheBustingConfig(
      mountPrefix: '/static',
      fileSystemRoot: staticRoot,
      separator: '--',
    );
    const original = '/static/logo.png';
    final busted = await cfg.assetPath(original);
    expect(busted, startsWith('/static/logo--'));
  });

  test(
      'Given a CacheBustingConfig serving a directory where the directory name contains the separator when calling assetPath then only the filename is affected',
      () async {
    await d.dir(p.join('static', 'img@foo'), [
      d.file('logo.png', 'dir-at-bytes'),
    ]).create();

    final staticRoot = Directory(p.join(d.sandbox, 'static'));
    final cfg = CacheBustingConfig(
      mountPrefix: '/static',
      fileSystemRoot: staticRoot,
      separator: '@',
    );

    const original = '/static/img@foo/logo.png';
    final busted = await cfg.assetPath(original);
    expect(busted, startsWith('/static/img@foo/logo@'));
  });

  test(
      'Given a CacheBustingConfig serving a file starting wht the separator when calling assetPath then cache busting path is created correctly',
      () async {
    await d.dir('static', [d.file('@logo.png', 'at-logo')]).create();
    final staticRoot = Directory(p.join(d.sandbox, 'static'));
    final cfg = CacheBustingConfig(
      mountPrefix: '/static',
      fileSystemRoot: staticRoot,
      separator: '@',
    );

    const original = '/static/@logo.png';
    final busted = await cfg.assetPath(original);
    expect(busted, startsWith('/static/@logo@'));
  });

  group('Given a CacheBustingConfig serving a symlink that escapes the root',
      () {
    late CacheBustingConfig cfg;
    setUp(() async {
      await d.file('outside.txt', 'outside').create();
      await d.dir('static').create();
      final outsidePath = p.join(d.sandbox, 'outside.txt');
      final linkPath = p.join(d.sandbox, 'static', 'escape.txt');
      Link(linkPath).createSync(outsidePath);

      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );
    });
    test('when calling assetPath then it throws ArgumentError', () async {
      expect(
        cfg.assetPath('/static/escape.txt'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('when calling tryAssetPath then asset path is returned unchanged',
        () async {
      expect(
          await cfg.tryAssetPath('/static/escape.txt'), '/static/escape.txt');
    });
  });

  group(
      'Given a CacheBustingConfig with a mountPrefix that does not match fileSystemRoot',
      () {
    late CacheBustingConfig cfg;
    setUp(() async {
      await d.dir('static', [
        d.file('logo.png', 'png-bytes'),
      ]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      cfg = CacheBustingConfig(
        mountPrefix: '/web',
        fileSystemRoot: staticRoot,
        separator: '@',
      );
    });

    test(
        'when assetPath is called for an existing file then it returns a cache busted path',
        () async {
      const original = '/web/logo.png';
      final busted = await cfg.assetPath(original);
      expect(busted, startsWith('/web/logo@'));
    });

    test(
        'when assetPath is called for file using fileSystemRoot instead of mountPrefix  as base then it returns path unchanged',
        () async {
      const original = '/static/logo.png';
      final busted = await cfg.assetPath(original);
      expect(busted, equals('/static/logo.png'));
    });
  });
}
