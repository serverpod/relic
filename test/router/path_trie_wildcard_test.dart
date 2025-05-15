import 'package:relic/src/router/normalized_path.dart';
import 'package:relic/src/router/path_trie.dart';
import 'package:test/test.dart';

void main() {
  group('PathTrie Wildcard (*) Matching', () {
    late PathTrie<int> trie;

    setUp(() {
      trie = PathTrie<int>();
    });

    test(
        'Given a trie with path /users/*/profile, '
        'when /users/123/profile is looked up, '
        'then it matches with correct value and paths', () {
      trie.add(NormalizedPath('/users/*/profile'), 1);
      final result = trie.lookup(NormalizedPath('/users/123/profile'));
      expect(result, isNotNull);
      expect(result!.value, 1);
      expect(result.parameters, isEmpty);
      expect(result.matched.path, '/users/123/profile');
      expect(result.remaining.segments, isEmpty);
    });

    test(
        'Given a trie with path /*/resource, '
        'when /any/resource is looked up, '
        'then it matches with correct value and paths', () {
      trie.add(NormalizedPath('/*/resource'), 1);
      final result = trie.lookup(NormalizedPath('/any/resource'));
      expect(result, isNotNull);
      expect(result!.value, 1);
      expect(result.parameters, isEmpty);
      expect(result.matched.path, '/any/resource');
      expect(result.remaining.segments, isEmpty);
    });

    test(
        'Given a trie with path /files/*, '
        'when /files/image.jpg is looked up, '
        'then it matches with correct value and paths', () {
      trie.add(NormalizedPath('/files/*'), 1);
      final result = trie.lookup(NormalizedPath('/files/image.jpg'));
      expect(result, isNotNull);
      expect(result!.value, 1);
      expect(result.parameters, isEmpty);
      expect(result.matched.path, '/files/image.jpg');
      expect(result.remaining.segments, isEmpty);
    });

    test(
        'Given a trie with path /a/*/c/*, '
        'when /a/b/c/d is looked up, '
        'then it matches with correct value and paths', () {
      trie.add(NormalizedPath('/a/*/c/*'), 1);
      final result = trie.lookup(NormalizedPath('/a/b/c/d'));
      expect(result, isNotNull);
      expect(result!.value, 1);
      expect(result.parameters, isEmpty);
      expect(result.matched.path, '/a/b/c/d');
      expect(result.remaining.segments, isEmpty);
    });

    test(
        'Given a trie with path /a/*/b, '
        'when /a/b (fewer segments) is looked up, '
        'then no match is found', () {
      trie.add(NormalizedPath('/a/*/b'), 1);
      expect(trie.lookup(NormalizedPath('/a/b')), isNull);
    });

    test(
        'Given a trie with /data/specific and /data/*, '
        'when they are looked up, '
        'then literal /data/specific is preferred over /data/*, and /data/* matches other segments',
        () {
      trie.add(NormalizedPath('/data/specific'), 1);
      trie.add(NormalizedPath('/data/*'), 2);
      final result = trie.lookup(NormalizedPath('/data/specific'));
      expect(result, isNotNull);
      expect(result!.value, 1);

      final wildResult = trie.lookup(NormalizedPath('/data/general'));
      expect(wildResult, isNotNull);
      expect(wildResult!.value, 2);
    });

    test(
        'Given a trie with path /assets/*, '
        'when /assets/img/logo.png (wildcard part spans multiple segments) is looked up, '
        'then no match is found', () {
      trie.add(NormalizedPath('/assets/*'), 1);
      expect(trie.lookup(NormalizedPath('/assets/img/logo.png')), isNull);
    });

    test(
        'Given a trie with path /api/:version/data/*, '
        'when /api/v1/data/users is looked up, '
        'then it matches with correct value, parameter, and paths', () {
      trie.add(NormalizedPath('/api/:version/data/*'), 1);
      final result = trie.lookup(NormalizedPath('/api/v1/data/users'));
      expect(result, isNotNull);
      expect(result!.value, 1);
      expect(result.parameters, equals({#version: 'v1'}));
      expect(result.matched.path, '/api/v1/data/users');
      expect(result.remaining.segments, isEmpty);
    });

    test(
        'Given a trie with path /a/b/*/d, '
        'when /a/b/c (shorter) is looked up, '
        'then no match is found', () {
      trie.add(NormalizedPath('/a/b/*/d'), 1);
      expect(trie.lookup(NormalizedPath('/a/b/c')), isNull);
    });

    test(
        'Given a trie with path /a/b/* (no tail), '
        'when /a/b/c/d (longer) is looked up, '
        'then no match is found', () {
      trie.add(NormalizedPath('/a/b/*'), 1);
      expect(trie.lookup(NormalizedPath('/a/b/c/d')), isNull);
    });

    test(
        'Given an empty trie, '
        'when adding a path like /*foo/bar (wildcard not a full segment), '
        'then an ArgumentError is thrown', () {
      expect(
          () => trie.add(NormalizedPath('/*foo/bar'), 1), throwsArgumentError);
    });

    group('Wildcard and Parameter interaction validation', () {
      test(
          'Given a trie with /test/*, '
          'when adding /test/:id (parameter after wildcard at same level), '
          'then an ArgumentError is thrown', () {
        trie.add(NormalizedPath('/test/*'), 1);
        expect(() => trie.add(NormalizedPath('/test/:id'), 2),
            throwsArgumentError);
      });

      test(
          'Given a trie with /test/:id, '
          'when adding /test/* (wildcard after parameter at same level), '
          'then an ArgumentError is thrown', () {
        trie.add(NormalizedPath('/test/:id'), 1);
        expect(
            () => trie.add(NormalizedPath('/test/*'), 2), throwsArgumentError);
      });
    });
  });
}
