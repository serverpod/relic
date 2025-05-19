import 'package:relic/src/router/normalized_path.dart';
import 'package:relic/src/router/path_trie.dart';
import 'package:test/test.dart';

void main() {
  group('PathTrie Tail (**) Matching', () {
    late PathTrie<int> trie;

    setUp(() {
      trie = PathTrie<int>();
    });

    test(
        'Given a trie with path /static/**, '
        'when /static/css/style.css is looked up, '
        'then it matches with correct value and remaining path', () {
      trie.add(NormalizedPath('/static/**'), 1);
      final result = trie.lookup(NormalizedPath('/static/css/style.css'));
      expect(result, isNotNull);
      expect(result!.value, 1);
      expect(result.parameters, isEmpty);
      expect(result.matched.path, '/static');
      expect(result.remaining.path, '/css/style.css');
    });

    test(
        'Given a trie with path /**, '
        'when /any/path/anywhere is looked up, '
        'then it matches with an empty matched path and correct remaining path',
        () {
      trie.add(NormalizedPath('/**'), 1);
      final result = trie.lookup(NormalizedPath('/any/path/anywhere'));
      expect(result, isNotNull);
      expect(result!.value, 1);
      expect(result.parameters, isEmpty);
      expect(result.matched.segments, isEmpty);
      expect(result.remaining.path, '/any/path/anywhere');
    });

    group('Root path (/) matching with root tail (/**) interactions', () {
      setUp(() {
        // Ensures a fresh trie for each scenario in this group
        trie = PathTrie<int>();
      });

      test(
          'Given a trie with only path /** defined, '
          'when the root path / is looked up,'
          'then /** matches with its value and empty matched/remaining paths',
          () {
        trie.add(NormalizedPath('/**'), 1);
        final result = trie.lookup(NormalizedPath('/'));
        expect(result, isNotNull,
            reason: 'Lookup for / should find /** if / has no value');
        expect(result!.value, 1);
        expect(result.matched.segments, isEmpty,
            reason: 'Matched path for /** lookup of / should be empty');
        expect(result.remaining.segments, isEmpty,
            reason: 'Remaining path for /** lookup of / should be empty');
      });

      test(
          'Given a trie with only path / defined, '
          'when the root path / is looked up, '
          'then / matches with its value and empty matched/remaining paths',
          () {
        trie.add(NormalizedPath('/'), 2);
        final result = trie.lookup(NormalizedPath('/'));
        expect(result, isNotNull);
        expect(result!.value, 2);
        expect(result.matched.segments, isEmpty);
        expect(result.remaining.segments, isEmpty);
      });

      test(
          'Given a trie with path / and path /** defined, '
          'when the root path / is looked up, '
          'then the literal path / takes precedence with its value', () {
        trie.add(NormalizedPath('/'), 2);
        trie.add(NormalizedPath('/**'), 3); // /** has a different value

        final result = trie.lookup(NormalizedPath('/'));
        expect(result, isNotNull,
            reason: 'Lookup for / should prefer value on / over /**');
        expect(result!.value, 2, reason: 'Value from / should be preferred');
        expect(result.matched.segments, isEmpty);
        expect(result.remaining.segments, isEmpty);
      });

      test(
          'Given a trie with path / and path /** defined, '
          'when a sub-path like /some/path is looked up, '
          'then path /** matches with its value and correct remaining path',
          () {
        trie.add(NormalizedPath('/'), 2);
        trie.add(NormalizedPath('/**'), 3);

        final result = trie.lookup(NormalizedPath('/some/path'));
        expect(result, isNotNull,
            reason: '/** should still match longer paths');
        expect(result!.value, 3,
            reason: 'Value from /** should match longer paths');
        expect(result.matched.segments, isEmpty);
        expect(result.remaining.path, '/some/path');
      });
    });

    test(
        'Given a trie with /assets/js/app.js and /assets/**, '
        'when paths are looked up, '
        'then literal is preferred and tail matches remaining', () {
      trie.add(NormalizedPath('/assets/js/app.js'), 1);
      trie.add(NormalizedPath('/assets/**'), 2);

      final literalResult = trie.lookup(NormalizedPath('/assets/js/app.js'));
      expect(literalResult, isNotNull);
      expect(literalResult!.value, 1);
      expect(literalResult.matched.path, '/assets/js/app.js');
      expect(literalResult.remaining.segments, isEmpty);

      final tailResult = trie.lookup(NormalizedPath('/assets/img/logo.png'));
      expect(tailResult, isNotNull);
      expect(tailResult!.value, 2);
      expect(tailResult.matched.path, '/assets');
      expect(tailResult.remaining.path, '/img/logo.png');
    });

    test(
        'Given a trie with /foo/bar/** and /foo/**, '
        'when paths are looked up, '
        'then the more specific /foo/bar/** is chosen over /foo/**', () {
      trie.add(NormalizedPath('/foo/bar/**'), 1);
      trie.add(NormalizedPath('/foo/**'), 2);

      final resSpecific = trie.lookup(NormalizedPath('/foo/bar/baz/qux'));
      expect(resSpecific, isNotNull);
      expect(resSpecific!.value, 1);
      expect(resSpecific.matched.path, '/foo/bar');
      expect(resSpecific.remaining.path, '/baz/qux');

      final resGeneral = trie.lookup(NormalizedPath('/foo/other/path'));
      expect(resGeneral, isNotNull);
      expect(resGeneral!.value, 2);
      expect(resGeneral.matched.path, '/foo');
      expect(resGeneral.remaining.path, '/other/path');
    });

    test(
        'Given a trie with path /user/:id/files/**, '
        'when /user/42/files/docs/report.pdf is looked up, '
        'then it matches with correct parameter and remaining path', () {
      trie.add(NormalizedPath('/user/:id/files/**'), 1);
      final result =
          trie.lookup(NormalizedPath('/user/42/files/docs/report.pdf'));
      expect(result, isNotNull);
      expect(result!.value, 1);
      expect(result.parameters, equals({#id: '42'}));
      expect(result.matched.path, '/user/42/files');
      expect(result.remaining.path, '/docs/report.pdf');
    });

    test(
        'Given a trie with path /data/export/**, '
        'when /data (shorter than prefix) is looked up, '
        'then no match is found', () {
      trie.add(NormalizedPath('/data/export/**'), 1);
      expect(trie.lookup(NormalizedPath('/data')), isNull);
    });

    test(
        'Given an empty trie, '
        'when adding a path like /**foo, '
        'then an ArgumentError is thrown', () {
      expect(() => trie.add(NormalizedPath('/downloads/**foo'), 1),
          throwsArgumentError,
          reason: 'Tail not a full segment');
    });

    group('Tail and Other Segment interaction validation', () {
      test(
          'Given a trie with /test/**, '
          'when adding /test/:id, '
          'then an ArgumentError is thrown', () {
        trie.add(NormalizedPath('/test/**'), 1);
        expect(
            () => trie.add(NormalizedPath('/test/:id'), 2), throwsArgumentError,
            reason: 'Parameter after tail at same level');
      });

      test(
          'Given a trie with /test/:id, '
          'when adding /test/**, '
          'then an ArgumentError is thrown', () {
        trie.add(NormalizedPath('/test/:id'), 1);
        expect(
            () => trie.add(NormalizedPath('/test/**'), 2), throwsArgumentError,
            reason: 'Tail after parameter at same level');
      });

      test(
          'Given a trie with /test/**, '
          'when adding /test/*, '
          'then an ArgumentError is thrown', () {
        trie.add(NormalizedPath('/test/**'), 1);
        expect(
            () => trie.add(NormalizedPath('/test/*'), 2), throwsArgumentError,
            reason: 'Wildcard after tail at same level');
      });

      test(
          'Given a trie with /test/*, '
          'when adding /test/**, '
          'then an ArgumentError is thrown', () {
        trie.add(NormalizedPath('/test/*'), 1);
        expect(
            () => trie.add(NormalizedPath('/test/**'), 2), throwsArgumentError,
            reason: 'Tail after wildcard at same level');
      });

      test(
          'Given an empty trie, '
          'when adding a path /a/**/b/c (tail /** not as the last segment), '
          'then an ArgumentError is thrown', () {
        expect(
            () => trie.add(NormalizedPath('/a/**/b/c'), 1), throwsArgumentError,
            reason: 'Tail /** not as the last segment.');
      });
    });
  });
}
