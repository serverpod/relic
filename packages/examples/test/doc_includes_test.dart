import 'dart:io';

import 'package:test/test.dart';

/// A parameter of a `GITHUB_CODE_BLOCK` line, as blended-include-code-plugin
/// reads it.
final _parameter = RegExp(r'([a-z]+)="([^"]+)"');

/// The opening of a fenced code block: three or more backticks or tildes.
final _fence = RegExp(r'^(`{3,}|~{3,})');

void main() {
  test(
    'Given the docs pages, '
    'when their code includes are resolved, '
    'then each names an existing file with one opening and one closing doctag, in that order.',
    () {
      final root = _repoRoot();
      final docs = Directory.fromUri(root.resolve('doc/site/docs/'));
      // The pages reach the examples through the docs/_example symlink. Map it
      // by hand, since a checkout without symlinks has a plain file there.
      final exampleLink = docs.uri.resolve('_example/');
      final examples = root.resolve('packages/examples/');

      final problems = <String>[];
      var includes = 0;
      final pages = docs
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md') || f.path.endsWith('.mdx'));
      for (final page in pages) {
        final lines = page.readAsLinesSync();
        // A line inside a fenced code block is shown, not included.
        String? fence;
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trimLeft();
          if (fence == null) {
            final open = _fence.firstMatch(line);
            if (open != null) {
              fence = open[1];
              continue;
            }
          } else {
            if (line.startsWith(fence) &&
                line.substring(fence.length).trim().isEmpty) {
              fence = null;
            }
            continue;
          }
          if (!line.startsWith('GITHUB_CODE_BLOCK')) continue;
          includes++;
          final where = '${page.uri.path.substring(root.path.length)}:${i + 1}';
          final parameters = {
            for (final m in _parameter.allMatches(lines[i])) m[1]!: m[2]!,
          };
          final file = parameters['file'];
          if (file == null) {
            problems.add('$where: no file parameter');
            continue;
          }
          var target = page.parent.uri.resolve(file);
          if (target.path.startsWith(exampleLink.path)) {
            target = examples.resolve(
              target.path.substring(exampleLink.path.length),
            );
          }
          final source = File.fromUri(target);
          if (!source.existsSync()) {
            problems.add('$where: $file does not exist');
            continue;
          }
          final tag = parameters['doctag'];
          if (tag == null) continue;
          problems.addAll(
            _checkTag(source.readAsLinesSync(), tag, '$where: $file'),
          );
        }
      }

      expect(includes, isPositive, reason: 'Found no includes under $docs');
      expect(problems, isEmpty);
    },
  );
}

/// Why the lines between the [tag] markers in [lines] are not one region.
Iterable<String> _checkTag(List<String> lines, String tag, String where) sync* {
  final open = 'doctag<$tag>';
  final close = 'end:doctag<$tag>';
  final opens = [
    for (var i = 0; i < lines.length; i++)
      if (lines[i].contains(open) && !lines[i].contains(close)) i,
  ];
  final closes = [
    for (var i = 0; i < lines.length; i++)
      if (lines[i].contains(close)) i,
  ];
  if (opens.length != 1 || closes.length != 1) {
    yield '$where: doctag "$tag" has ${opens.length} opening and '
        '${closes.length} closing markers';
  } else if (opens.single > closes.single) {
    yield '$where: doctag "$tag" closes before it opens';
  }
}

/// The repository root: the closest directory above the current one that
/// holds doc/site/docs.
Uri _repoRoot() {
  var dir = Directory.current.absolute;
  while (!Directory.fromUri(dir.uri.resolve('doc/site/docs/')).existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('No doc/site/docs above ${Directory.current.path}');
    }
    dir = parent;
  }
  return dir.uri;
}
