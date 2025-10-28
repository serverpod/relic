import 'package:relic/src/router/normalized_path.dart';
import 'package:relic/src/router/path_trie.dart';
import 'package:test/test.dart';

void main() {
  test('Given a value at root, '
      'when use is applied to root, '
      'then the value is transformed', () {
    final trie = PathTrie<int>();
    final root = NormalizedPath('/');
    trie.add(root, 1);
    trie.use(root, (final i) => i * 2);
    expect(trie.lookup(root)?.value, 2, reason: 'Should double');
  });

  test('Given a value at path, '
      'when use is applied twice to path, '
      'then the mappings compose', () {
    final trie = PathTrie<int>();
    final root = NormalizedPath('/a');
    trie.add(root, 1);
    trie.use(root, (final i) => i * 2);
    trie.use(root, (final i) => i + 3);
    expect(trie.lookup(root)?.value, 8, reason: 'Should add 3 and then double');
  });

  test('Given an empty trie, '
      'when use is applied before add, '
      'then the value is transformed', () {
    final trie = PathTrie<int>();
    final root = NormalizedPath('/');
    trie.use(root, (final i) => i * 2);
    trie.add(root, 1);
    expect(trie.lookup(root)?.value, 2, reason: 'Should double');
  });

  test('Given a value at tail wildcard, '
      'when use is applied to tail wildcard, '
      'then matching paths are transformed', () {
    final trie = PathTrie<int>();
    final tail = NormalizedPath('/**');
    trie.add(tail, 1);
    trie.use(tail, (final i) => i * 2);
    expect(
      trie.lookup(NormalizedPath('/a/b/c'))?.value,
      2,
      reason: 'Should double',
    );
  });

  test('Given a value at parameterized path, '
      'when use is applied to parameter prefix, '
      'then descendant values are transformed', () {
    final trie = PathTrie<int>();
    trie.add(NormalizedPath('/:id/b/c'), 1);
    trie.use(NormalizedPath('/:id'), (final i) => i * 2);
    expect(
      trie.lookup(NormalizedPath('/a/b/c'))?.value,
      2,
      reason: 'Should double',
    );
  });

  test('Given a value at wildcard path, '
      'when use is applied to wildcard prefix, '
      'then descendant values are transformed', () {
    final trie = PathTrie<int>();
    trie.add(NormalizedPath('/*/b/c'), 1);
    trie.use(NormalizedPath('/*'), (final i) => i * 2);
    expect(
      trie.lookup(NormalizedPath('/a/b/c'))?.value,
      2,
      reason: 'Should double',
    );
  });

  test('Given multiple paths with values, '
      'when use is applied to root, '
      'then all descendant values are transformed', () {
    final trie = PathTrie<int>();
    final root = NormalizedPath('/');
    final pathA = NormalizedPath('/a');
    final pathB = NormalizedPath('/b');
    trie.add(root, 1);
    trie.add(pathA, 10);
    trie.add(pathB, 100);
    trie.use(root, (final i) => i * 2);
    expect(trie.lookup(root)?.value, 2, reason: 'Should double');
    expect(trie.lookup(pathA)?.value, 20, reason: 'Should double');
    expect(trie.lookup(pathB)?.value, 200, reason: 'Should double');
  });

  test('Given multiple paths with values, '
      'when use is applied to a specific path, '
      'then only descendants of that path are transformed', () {
    final trie = PathTrie<int>();
    final root = NormalizedPath('/');
    final pathA = NormalizedPath('/a');
    final pathB = NormalizedPath('/b');
    trie.add(root, 1);
    trie.add(pathA, 10);
    trie.add(pathB, 100);
    trie.use(pathA, (final i) => i * 2);
    expect(trie.lookup(root)?.value, 1, reason: 'Should not change');
    expect(trie.lookup(pathA)?.value, 20, reason: 'Should double');
    expect(trie.lookup(pathB)?.value, 100, reason: 'Should not change');
  });

  test('Given two tries where one is attached to the other, '
      'when use is applied to the prefix on the parent, '
      'then only attached trie values are transformed', () {
    final trieA = PathTrie<int>();
    final trieB = PathTrie<int>();
    final pathA = NormalizedPath('/a');
    final pathB = NormalizedPath('/b');
    trieA.add(pathA, 10);
    trieB.add(pathB, 100);
    trieA.attach(NormalizedPath('/prefix'), trieB);
    trieA.use(NormalizedPath('/prefix'), (final i) => i * 2);
    expect(trieA.lookup(pathA)?.value, 10, reason: 'Should not change');
    expect(
      trieA.lookup(NormalizedPath('/prefix/b'))?.value,
      200,
      reason: 'Should double',
    );
  });

  test('Given two tries where one is attached to the other, '
      'when use is applied to the root of the child, '
      'then only attached trie values are transformed', () {
    final trieA = PathTrie<int>();
    final trieB = PathTrie<int>();
    final pathA = NormalizedPath('/a');
    final pathB = NormalizedPath('/b');
    trieA.add(pathA, 10);
    trieB.add(pathB, 100);
    trieB.use(NormalizedPath.empty, (final i) => i * 2);
    trieA.attach(NormalizedPath('/prefix'), trieB);
    expect(trieA.lookup(pathA)?.value, 10, reason: 'Should not change');
    expect(
      trieA.lookup(NormalizedPath('/prefix/b'))?.value,
      200,
      reason: 'Should double',
    );
  });

  test('Given two tries with use applied, '
      'when attaching one to the other such that use collide, '
      'then map functions are composed', () {
    final trieA = PathTrie<int>();
    final trieB = PathTrie<int>();
    final attachAt = NormalizedPath('/prefix');
    trieA.use(attachAt, (final i) => i * 2);
    trieB.add(NormalizedPath('/suffix'), 1);
    trieB.use(NormalizedPath.empty, (final i) => i + 3);
    trieA.attach(attachAt, trieB);
    expect(
      trieA.lookup(NormalizedPath('/prefix/suffix'))?.value,
      8,
      reason: 'Should add 3 and then double',
    );
  });

  test('Given multiple use mappings on ancestor and descendant paths, '
      'when looking up a value, '
      'then transformations are applied from leaf to root', () {
    final trie = PathTrie<int>();
    final pathA = NormalizedPath('/a');
    final pathB = NormalizedPath('/a/b');
    trie.add(pathB, 1);
    trie.use(pathA, (final i) => i * 2);
    trie.use(pathB, (final i) => i + 3);
    expect(
      trie.lookup(pathB)?.value,
      8,
      reason: 'Should add 3 and then double',
    );
  });

  test('Given a trie of functions with hierarchical use mappings, '
      'when looking up the leaf function and applying it, '
      'then the call order is root to leaf', () {
    final trie = PathTrie<String Function(String)>();
    final pathA = NormalizedPath('/a');
    final pathB = NormalizedPath('/a/b');
    final pathC = NormalizedPath('/a/b/c');
    final pathD = NormalizedPath('/a/b/c/d');
    trie.use(pathA, (final next) => (final s) => '<a>${next(s)}</a>');
    trie.use(pathB, (final next) => (final s) => '<b>${next(s)}</b>');
    trie.use(pathC, (final next) => (final s) => '<c>${next(s)}</c>');
    trie.add(pathD, (final s) => s);
    expect(
      trie.lookup(pathD)?.value('request'),
      '<a><b><c>request</c></b></a>',
    );
  });
}
