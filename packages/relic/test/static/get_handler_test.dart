import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  setUp(() async {
    await d.file('root.txt', 'root txt').create();
    await d.dir('files', [
      d.file('test.txt', 'test txt content'),
      d.file('with space.txt', 'with space content'),
    ]).create();
  });

  test(
    'Given a non-existent relative path when creating a static handler then it throws an ArgumentError',
    () async {
      expect(
        () =>
            StaticHandler.directory(
              Directory('random/relative'),
              cacheControl: (_, _) => null,
            ).asHandler,
        throwsArgumentError,
      );
    },
  );

  test(
    'Given an existing relative path when creating a static handler then it returns normally',
    () async {
      final existingRelative = p.relative(d.sandbox);
      expect(
        () =>
            StaticHandler.directory(
              Directory(existingRelative),
              cacheControl: (_, _) => null,
            ).asHandler,
        returnsNormally,
      );
    },
  );

  test(
    'Given a non-existent absolute path when creating a static handler then it throws an ArgumentError',
    () {
      final nonExistingAbsolute = p.join(d.sandbox, 'not_here');
      expect(
        () =>
            StaticHandler.directory(
              Directory(nonExistingAbsolute),
              cacheControl: (_, _) => null,
            ).asHandler,
        throwsArgumentError,
      );
    },
  );

  test(
    'Given an existing absolute path when creating a static handler then it returns normally',
    () {
      expect(
        () =>
            StaticHandler.directory(
              Directory(d.sandbox),
              cacheControl: (_, _) => null,
            ).asHandler,
        returnsNormally,
      );
    },
  );
}
