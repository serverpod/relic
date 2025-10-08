import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('Given a CacheBustingConfig with a static directory', () {
    setUp(() async {
      await d.dir('static', [
        d.file('logo.png', 'png-bytes'),
        d.dir('images', [d.file('logo.png', 'nested-bytes')]),
      ]).create();
    });

    test(
        'when assetPath is called for a missing file, '
        'then it throws PathNotFoundException', () async {
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
        'when assetPath is called with path containing .. segments, '
        'then it rejects paths outside root', () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );

      expect(
        cfg.assetPath('/static/../secret.txt'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
        'when assetPath is called with absolute path segment after mount, '
        'then it rejects paths outside root', () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );

      expect(
        cfg.assetPath('/static//etc/passwd'),
        throwsA(isA<ArgumentError>()),
      );
    });

    group('when a symlink escapes the root', () {
      test(
          'when assetPath is called, '
          'then it rejects paths outside root', () async {
        final outsidePath = p.join(d.sandbox, 'outside.txt');
        await File(outsidePath).writeAsString('outside');

        final linkPath = p.join(d.sandbox, 'static', 'escape.txt');
        final link = Link(linkPath);
        try {
          await link.create(outsidePath);
        } on FileSystemException {
          return; // platform forbids symlinks
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
    });

    test(
        'when tryBust is called for a missing file, '
        'then it returns the original path', () async {
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
        'when tryBust is called with path outside mountPrefix, '
        'then it returns the path unchanged', () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );

      const outside = '/other/logo.png';
      expect(await cfg.tryBust(outside), outside);
    });

    test(
        'when assetPath is called with path outside mountPrefix, '
        'then it returns the path unchanged', () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );

      const outside = '/other/logo.png';
      expect(await cfg.assetPath(outside), outside);
    });

    test(
        'when creating config with invalid mountPrefix, '
        'then it throws ArgumentError', () async {
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
        'when assetPath is called for a file without extension, '
        'then it returns a busted path', () async {
      await d.file(p.join('static', 'logo'), 'content-noext').create();

      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );

      const original = '/static/logo';
      final busted = await cfg.assetPath(original);
      expect(busted, startsWith('/static/logo@'));
    });

    group('when a custom separator is configured', () {
      test(
          'when assetPath is called, '
          'then it uses that separator', () async {
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
    });

    group('when a directory name contains @', () {
      test(
          'when assetPath is called, '
          'then only the filename is affected', () async {
        await d.dir(p.join('static', 'img@foo'), [
          d.file('logo.png', 'dir-at-bytes'),
        ]).create();

        final staticRoot = Directory(p.join(d.sandbox, 'static'));
        final cfg = CacheBustingConfig(
          mountPrefix: '/static',
          fileSystemRoot: staticRoot,
        );

        const original = '/static/img@foo/logo.png';
        final busted = await cfg.assetPath(original);
        expect(busted, startsWith('/static/img@foo/logo@'));
      });
    });

    group('when a filename starts with @', () {
      test(
          'when assetPath is called, '
          'then it busts correctly', () async {
        await d.file(p.join('static', '@logo.png'), 'at-logo').create();

        final staticRoot = Directory(p.join(d.sandbox, 'static'));
        final cfg = CacheBustingConfig(
          mountPrefix: '/static',
          fileSystemRoot: staticRoot,
        );

        const original = '/static/@logo.png';
        final busted = await cfg.assetPath(original);
        expect(busted, startsWith('/static/@logo@'));
      });
    });
  });
}
