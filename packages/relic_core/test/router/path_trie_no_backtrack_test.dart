import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('Given a trie looked up without backtracking', () {
    late PathTrie<int> trie;

    setUp(() {
      trie = PathTrie<int>();
    });

    TrieMatch<int>? lookup(final String path) =>
        trie.lookup(NormalizedPath(path), backtrack: false);

    test('when a literal path is looked up, '
        'then it matches with the whole path consumed', () {
      trie.add(NormalizedPath('/users/profile'), 1);
      final result = lookup('/users/profile');
      expect(result, isNotNull);
      expect(result!.value, 1);
      expect(result.parameters, isEmpty);
      expect(result.matched.path, '/users/profile');
      expect(result.remaining.segments, isEmpty);
    });

    test('when a parameterized path is looked up, '
        'then the parameters are extracted', () {
      trie.add(NormalizedPath('/users/:id/items/:itemId'), 1);
      final result = lookup('/users/42/items/7');
      expect(result, isNotNull);
      expect(result!.value, 1);
      expect(result.parameters, equals({#id: '42', #itemId: '7'}));
      expect(result.matched.path, '/users/42/items/7');
    });

    test('when a wildcard path is looked up, '
        'then it matches without binding a parameter', () {
      trie.add(NormalizedPath('/users/*/profile'), 1);
      final result = lookup('/users/123/profile');
      expect(result, isNotNull);
      expect(result!.value, 1);
      expect(result.parameters, isEmpty);
      expect(result.matched.path, '/users/123/profile');
    });

    test('when a literal and a parameter route share a segment, '
        'then the literal is taken', () {
      trie.add(NormalizedPath('/users/:id'), 1);
      trie.add(NormalizedPath('/users/me'), 2);
      expect(lookup('/users/me')?.value, 2);
      expect(lookup('/users/42')?.value, 1);
    });

    test('when the literal branch dead-ends, '
        'then the parameter route that would have matched is not tried', () {
      trie.add(NormalizedPath('/:entity/:id'), 1);
      trie.add(NormalizedPath('/users/:id/profile'), 2);
      expect(lookup('/users/789'), isNull);
      expect(lookup('/users/789/profile')?.value, 2);
      expect(lookup('/posts/789')?.value, 1);
    });

    test('when the literal branch dead-ends above a tail, '
        'then the tail that would have matched is not tried', () {
      trie.add(NormalizedPath('/app/**'), 1);
      trie.add(NormalizedPath('/app/admin/users'), 2);
      expect(lookup('/app/admin'), isNull);
      expect(lookup('/app/admin/users')?.value, 2);
      expect(lookup('/app/other')?.value, 1);
    });

    test('when a tail path is looked up, '
        'then the matched and remaining paths split at the tail', () {
      trie.add(NormalizedPath('/static/**'), 1);
      final result = lookup('/static/css/style.css');
      expect(result, isNotNull);
      expect(result!.value, 1);
      expect(result.matched.path, '/static');
      expect(result.remaining.path, '/css/style.css');
    });

    test('when a parameter precedes a tail, '
        'then both the parameter and the remaining path are reported', () {
      trie.add(NormalizedPath('/user/:id/files/**'), 1);
      final result = lookup('/user/42/files/docs/report.pdf');
      expect(result, isNotNull);
      expect(result!.parameters, equals({#id: '42'}));
      expect(result.matched.path, '/user/42/files');
      expect(result.remaining.path, '/docs/report.pdf');
    });

    test('when two tails nest, '
        'then the deeper tail is taken for a path under it', () {
      trie.add(NormalizedPath('/foo/bar/**'), 1);
      trie.add(NormalizedPath('/foo/**'), 2);
      final specific = lookup('/foo/bar/baz/qux');
      expect(specific!.value, 1);
      expect(specific.matched.path, '/foo/bar');
      expect(specific.remaining.path, '/baz/qux');
      final general = lookup('/foo/other/path');
      expect(general!.value, 2);
      expect(general.matched.path, '/foo');
      expect(general.remaining.path, '/other/path');
    });

    test('when the path ends where a tail starts, '
        'then the tail matches with nothing remaining', () {
      trie.add(NormalizedPath('/archive/**'), 1);
      final result = lookup('/archive');
      expect(result, isNotNull);
      expect(result!.value, 1);
      expect(result.matched.path, '/archive');
      expect(result.remaining.segments, isEmpty);
    });

    test('when the root tail is looked up with the root path, '
        'then the tail matches', () {
      trie.add(NormalizedPath('/**'), 1);
      final result = lookup('/');
      expect(result, isNotNull);
      expect(result!.value, 1);
      expect(result.remaining.segments, isEmpty);
    });

    test('when the path is shorter than the prefix of a tail route, '
        'then there is no match', () {
      trie.add(NormalizedPath('/data/export/**'), 1);
      expect(lookup('/data'), isNull);
    });

    test('when the path is longer than every route, '
        'then there is no match', () {
      trie.add(NormalizedPath('/a/b'), 1);
      expect(lookup('/a/b/c'), isNull);
    });

    test('when use is applied at two levels of the matched path, '
        'then the outer mapping wraps the inner one', () {
      trie.add(NormalizedPath('/api/v1/items'), 1);
      trie.use(NormalizedPath('/api'), (final i) => i * 10);
      trie.use(NormalizedPath('/api/v1'), (final i) => i + 1);
      expect(lookup('/api/v1/items')?.value, 20);
    });

    test('when use is applied on a parameter prefix, '
        'then the mapping applies to the descendant value', () {
      trie.add(NormalizedPath('/:id/b/c'), 1);
      trie.use(NormalizedPath('/:id'), (final i) => i * 2);
      expect(lookup('/a/b/c')?.value, 2);
    });

    test('when use is applied on a tail route, '
        'then the mapping applies to the tail value', () {
      trie.add(NormalizedPath('/files/**'), 1);
      trie.use(NormalizedPath('/files'), (final i) => i * 3);
      expect(lookup('/files/a/b')?.value, 3);
      expect(lookup('/files')?.value, 3);
    });
  });
}
