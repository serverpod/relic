import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:relic_io/relic_io.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  test(
    'Given mountPrefix not starting with "/" when creating CacheBustingConfig then it throws ArgumentError',
    () {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      expect(
        () => CacheBustingConfig(
          mountPrefix: 'static',
          fileSystemRoot: staticRoot,
        ),
        throwsArgumentError,
      );
    },
  );

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
        throwsArgumentError,
      );
    },
  );

  test(
    'Given "/" separator when creating CacheBustingConfig then it throws ArgumentError',
    () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      expect(
        () => CacheBustingConfig(
          mountPrefix: '/static',
          fileSystemRoot: staticRoot,
          separator: '/',
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'Given separator starting with "/" when creating CacheBustingConfig then it throws ArgumentError',
    () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      expect(
        () => CacheBustingConfig(
          mountPrefix: '/static',
          fileSystemRoot: staticRoot,
          separator: '/@',
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'Given separator ending with "/" when creating CacheBustingConfig then it throws ArgumentError',
    () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      expect(
        () => CacheBustingConfig(
          mountPrefix: '/static',
          fileSystemRoot: staticRoot,
          separator: '@/',
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'Given separator containing "/" when creating CacheBustingConfig then it throws ArgumentError',
    () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      expect(
        () => CacheBustingConfig(
          mountPrefix: '/static',
          fileSystemRoot: staticRoot,
          separator: '@/@',
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'Given no directory at staticRoot when creating CacheBustingConfig then it throws ArgumentError',
    () {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      expect(
        () => CacheBustingConfig(
          mountPrefix: '/static',
          fileSystemRoot: staticRoot,
          separator: '@',
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'Given file at staticRoot when creating CacheBustingConfig then it throws ArgumentError',
    () async {
      await d.file('static', 'content').create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      expect(
        () => CacheBustingConfig(
          mountPrefix: '/static',
          fileSystemRoot: staticRoot,
          separator: '@',
        ),
        throwsArgumentError,
      );
    },
  );

  group('Given a CacheBustingConfig', () {
    late CacheBustingConfig cfg;
    setUp(() async {
      await d.dir('static', [
        d.file('logo.png', 'png-bytes'),
        d.file('logo', 'content-noext'),
        d.file('@logo.png', 'at-logo'),
        d.dir('img@foo', [d.file('logo.png', 'dir-at-bytes')]),
      ]).create();
      await d.file('secret.txt', 'top-secret').create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
        separator: '@',
      );
    });

    test(
      'when assetPath is called for a missing file then it throws PathNotFoundException',
      () async {
        expect(
          cfg.assetPath('/static/does-not-exist.txt'),
          throwsA(isA<PathNotFoundException>()),
        );
      },
    );

    test(
      'when tryAssetPath is called for a missing file then it returns the original path',
      () async {
        const original = '/static/does-not-exist.txt';
        final result = await cfg.tryAssetPath(original);
        expect(result, original);
      },
    );

    test(
      'when assetPath is called for an existing file then it returns a cache busted path',
      () async {
        final busted = await cfg.assetPath('/static/logo.png');
        expect(busted, startsWith('/static/logo@'));
      },
    );

    test(
      'when tryAssetPath is called for an existing file then it returns a cache busted path',
      () async {
        final busted = await cfg.tryAssetPath('/static/logo.png');
        expect(busted, startsWith('/static/logo@'));
      },
    );

    test(
      'when assetPath is called for a file without extension then it returns a cache busted path',
      () async {
        final busted = await cfg.assetPath('/static/logo');
        expect(busted, startsWith('/static/logo@'));
      },
    );

    test(
      'when assetPath is called for a file starting with the separator then cache busting path is created correctly',
      () async {
        final busted = await cfg.assetPath('/static/@logo.png');
        expect(busted, startsWith('/static/@logo@'));
      },
    );

    test(
      'when assetPath is called for a file in a directory containing the separator then only the filename is affected',
      () async {
        final busted = await cfg.assetPath('/static/img@foo/logo.png');
        expect(busted, startsWith('/static/img@foo/logo@'));
      },
    );

    test(
      'when assetPath is called with an absolute path segment after mount then it throws ArgumentError',
      () async {
        expect(cfg.assetPath('/static//logo.png'), throwsArgumentError);
      },
    );

    test(
      'when tryAssetPath is called with an absolute path segment after mount then it returns the original path',
      () async {
        const original = '/static//logo.png';
        expect(await cfg.tryAssetPath(original), original);
      },
    );

    test(
      'when assetPath is called for a path outside of the mount prefix then it returns it unchanged',
      () async {
        const outside = '/secret.txt';
        expect(await cfg.assetPath(outside), outside);
      },
    );

    test(
      'when tryAssetPath is called for a path outside of mount prefix then it returns it unchanged',
      () async {
        const outside = '/secret.txt';
        expect(await cfg.tryAssetPath(outside), outside);
      },
    );

    test(
      'when assetPath is called for a path that traverses outside of the mount prefix then it throws ArgumentError',
      () async {
        expect(cfg.assetPath('/static/../secret.txt'), throwsArgumentError);
      },
    );

    test(
      'when tryStripHashFromFilename is called with filename equal to the separator then same filename is returned',
      () {
        expect(cfg.tryStripHashFromFilename('@'), '@');
      },
    );

    test(
      'when tryStripHashFromFilename is called with non busted filename then same filename is returned',
      () {
        expect(cfg.tryStripHashFromFilename('logo.png'), 'logo.png');
      },
    );

    test(
      'when tryStripHashFromFilename is called with busted filename then hash is stripped from filename',
      () {
        expect(cfg.tryStripHashFromFilename('logo@abc123.png'), 'logo.png');
      },
    );

    test(
      'when tryStripHashFromFilename is called with busted filename that has no extension then it strips the hash and keeps no extension',
      () {
        expect(cfg.tryStripHashFromFilename('logo@abc123'), 'logo');
      },
    );

    test(
      'when tryStripHashFromFilename is called with busted filename starting with separator then only trailing hash is stripped',
      () {
        expect(cfg.tryStripHashFromFilename('@logo@abc123.png'), '@logo.png');
      },
    );
  });

  test(
    'Given a CacheBustingConfig without explicit separator when assetPath is called for existing file then default cache busting separator is "@"',
    () async {
      await d.dir('static', [d.file('logo.png', 'png-bytes')]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );
      final busted = await cfg.assetPath('/static/logo.png');
      expect(busted, contains('@'));
    },
  );

  test(
    'Given a CacheBustingConfig with custom separator when assetPath is called then it uses that separator',
    () async {
      await d.dir('static', [d.file('logo.png', 'png-bytes')]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
        separator: '--',
      );
      final busted = await cfg.assetPath('/static/logo.png');
      expect(busted, startsWith('/static/logo--'));
    },
  );

  test(
    'Given a CacheBustingConfig with custom separator when calling tryStripHashFromFilename then hash is stripped using that separator',
    () async {
      await d.dir('static', []).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
        separator: '--',
      );
      expect(cfg.tryStripHashFromFilename('logo--abc123.png'), 'logo.png');
    },
  );

  group(
    'Given a CacheBustingConfig with a mountPrefix that does not match fileSystemRoot',
    () {
      late CacheBustingConfig cfg;
      setUp(() async {
        await d.dir('static', [d.file('logo.png', 'png-bytes')]).create();
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
          final busted = await cfg.assetPath('/web/logo.png');
          expect(busted, startsWith('/web/logo@'));
        },
      );

      test(
        'when assetPath is called for file using fileSystemRoot instead of mountPrefix as base then it returns path unchanged',
        () async {
          final busted = await cfg.assetPath('/static/logo.png');
          expect(busted, equals('/static/logo.png'));
        },
      );
    },
  );

  group('Given a CacheBustingConfig configured for a directory with nested files', () {
    late CacheBustingConfig cfg;
    setUp(() async {
      await d.dir('static', [
        d.file('logo.png', 'png-bytes'),
        d.dir('images', [d.file('hero.jpg', 'jpg-bytes')]),
      ]).create();
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );
    });

    test(
      'when tryAssetPathSync is called before indexAssets then it returns the original path',
      () {
        expect(cfg.tryAssetPathSync('/static/logo.png'), '/static/logo.png');
      },
    );

    test(
      'when indexAssets is called then tryAssetPathSync returns a cache-busted path for root-level files',
      () async {
        await cfg.indexAssets();
        final busted = cfg.tryAssetPathSync('/static/logo.png');
        expect(busted, startsWith('/static/logo@'));
      },
    );

    test(
      'when indexAssets is called then tryAssetPathSync returns a cache-busted path for nested files',
      () async {
        await cfg.indexAssets();
        final busted = cfg.tryAssetPathSync('/static/images/hero.jpg');
        expect(busted, startsWith('/static/images/hero@'));
      },
    );

    test(
      'when tryAssetPathSync is called for a path not in the cache then it returns the original path',
      () async {
        await cfg.indexAssets();
        expect(
          cfg.tryAssetPathSync('/static/missing.txt'),
          '/static/missing.txt',
        );
      },
    );

    test(
      'when tryAssetPathSync is called for a path outside mount prefix then it returns the original path',
      () async {
        await cfg.indexAssets();
        expect(cfg.tryAssetPathSync('/other/logo.png'), '/other/logo.png');
      },
    );

    test(
      'when indexAssets is called then subdirectories are not indexed as paths',
      () async {
        await cfg.indexAssets();
        expect(cfg.tryAssetPathSync('/static/images'), '/static/images');
      },
    );

    test(
      'when assetPath is called then tryAssetPathSync returns the same result',
      () async {
        final busted = await cfg.assetPath('/static/logo.png');
        expect(cfg.tryAssetPathSync('/static/logo.png'), busted);
      },
    );

    test(
      'when tryAssetPath is called then tryAssetPathSync returns the same result',
      () async {
        final busted = await cfg.tryAssetPath('/static/logo.png');
        expect(cfg.tryAssetPathSync('/static/logo.png'), busted);
      },
    );

    test(
      'when assetPath is called twice for the same path then it returns the same result',
      () async {
        final first = await cfg.assetPath('/static/logo.png');
        final second = await cfg.assetPath('/static/logo.png');
        expect(second, first);
      },
    );
  });

  group(
    'Given a CacheBustingConfig with a symlink escaping root among regular files',
    () {
      late CacheBustingConfig cfg;
      setUp(() async {
        await d.file('outside.txt', 'outside-content').create();
        await d.dir('static', [d.file('good.txt', 'good-content')]).create();
        final outsidePath = p.join(d.sandbox, 'outside.txt');
        final linkPath = p.join(d.sandbox, 'static', 'escape.txt');
        Link(linkPath).createSync(outsidePath);

        final staticRoot = Directory(p.join(d.sandbox, 'static'));
        cfg = CacheBustingConfig(
          mountPrefix: '/static',
          fileSystemRoot: staticRoot,
        );
      });

      test(
        'when calling assetPath on the escaping symlink then it throws ArgumentError',
        () async {
          expect(cfg.assetPath('/static/escape.txt'), throwsArgumentError);
        },
      );

      test(
        'when calling tryAssetPath on the escaping symlink then asset path is returned unchanged',
        () async {
          expect(
            await cfg.tryAssetPath('/static/escape.txt'),
            '/static/escape.txt',
          );
        },
      );

      test(
        'when indexAssets is called then it indexes the regular file',
        () async {
          await cfg.indexAssets();
          expect(
            cfg.tryAssetPathSync('/static/good.txt'),
            startsWith('/static/good@'),
          );
        },
      );

      test(
        'when indexAssets is called then tryAssetPathSync returns original path for the escaping symlink',
        () async {
          await cfg.indexAssets();
          expect(
            cfg.tryAssetPathSync('/static/escape.txt'),
            '/static/escape.txt',
          );
        },
      );
    },
  );

  test(
    'Given an empty directory when indexAssets is called then tryAssetPathSync returns original paths',
    () async {
      await d.dir('empty').create();
      final staticRoot = Directory(p.join(d.sandbox, 'empty'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/empty',
        fileSystemRoot: staticRoot,
      );

      await cfg.indexAssets();
      expect(
        cfg.tryAssetPathSync('/empty/anything.txt'),
        '/empty/anything.txt',
      );
    },
  );
}
