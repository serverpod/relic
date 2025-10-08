import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('Given CacheBustingConfig and a static directory', () {
    setUp(() async {
      await d.dir('static', [
        d.file('logo.png', 'png-bytes'),
        d.dir('images', [d.file('logo.png', 'nested-bytes')]),
      ]).create();
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

    test('when path contains .. segments then bust rejects paths outside root',
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
    });

    test(
        'when absolute path segment appears after mount then bust rejects paths outside root',
        () async {
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

    test(
        'and a symlink escapes the root when calling bust then it rejects paths outside root',
        () async {
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
        'when the path is outside mountPrefix then tryBust returns it unchanged',
        () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );

      const outside = '/other/logo.png';
      expect(await cfg.tryBust(outside), outside);
    });

    test(
        'when the path is outside mountPrefix then assetPath returns it unchanged',
        () async {
      final staticRoot = Directory(p.join(d.sandbox, 'static'));
      final cfg = CacheBustingConfig(
        mountPrefix: '/static',
        fileSystemRoot: staticRoot,
      );

      const outside = '/other/logo.png';
      expect(await cfg.assetPath(outside), outside);
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

    test('when busting a file without extension then it returns a busted path',
        () async {
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

    test(
        'and a custom separator is configured when busting then it uses that separator',
        () async {
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
        'and a directory name contains @ when calling bust then only the filename is affected',
        () async {
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

    test(
        'Given a filename starting with @ when calling bust then it busts correctly',
        () async {
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
}
