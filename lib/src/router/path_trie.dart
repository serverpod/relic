import 'normalized_path.dart';

/// Represents the result of a route lookup.
final class LookupResult<T> {
  /// The value associated with the matched route.
  final T value;

  /// A map of parameter names to their extracted values from the path.
  final Map<Symbol, String> parameters;

  /// Creates a [LookupResult] with the given [value] and [parameters].
  const LookupResult(this.value, this.parameters);
}

/// A node within the path trie.
final class _TrieNode<T> {
  /// Child nodes representing literal path segments.
  final Map<String, _TrieNode<T>> children = {};

  /// Parameter definition associated with this node, if any.
  ///
  /// Stores the parameter name and the child node that represents the
  /// parameterized path segment.
  _Parameter<T>? parameter;

  /// The value associated with the route ending at this node.
  ///
  /// A non-null value indicates the end of a path
  T? value;
}

typedef _Parameter<T> = ({_TrieNode<T> node, String name});

/// A Trie (prefix tree) data structure optimized for matching URL paths.
///
/// Supports literal segments and parameterized segments (e.g., `:id`). Allows
/// associating a value of type [T] with each complete path.
final class PathTrie<T> {
  final _TrieNode<T> _root = _TrieNode<T>();

  /// Adds a route path and its associated value to the trie.
  ///
  /// The [normalizedPath] is expected to be pre-normalized (e.g., using
  /// [NormalizedPath]). Path segments starting with `:` are treated as parameters.
  ///
  /// If a route with the exact same path already exists, an [ArgumentError] is
  /// thrown. If adding a parameter conflicts with an existing parameter name at
  /// the same level (e.g., adding `/users/:id` after `/users/:userId`), an
  /// [ArgumentError] is also thrown.
  void add(final NormalizedPath normalizedPath, final T value) {
    final currentNode = _build(normalizedPath);
    // Mark the end node and handle potential overwrites
    if (currentNode.value != null) {
      throw ArgumentError(
        'Value already registered: '
            'Existing: "${currentNode.value}" '
            'New: "$value" '
            'for path $normalizedPath',
        'normalizedPath',
      );
    }
    currentNode.value = value;
  }

  /// Builds a trie node for the given normalized path.
  _TrieNode<T> _build(final NormalizedPath normalizedPath) {
    final segments = normalizedPath.segments;
    _TrieNode<T> currentNode = _root;

    for (final segment in segments) {
      if (segment.startsWith(':')) {
        final paramName = segment.substring(1).trim();
        if (paramName.isEmpty) {
          throw ArgumentError.value(normalizedPath, 'normalizedPath',
              'Parameter name cannot be empty');
        }
        // Ensure parameter child exists and handle name conflicts
        var parameter = currentNode.parameter;
        if (parameter == null) {
          parameter = (node: _TrieNode<T>(), name: paramName);
        } else if (parameter.name != paramName) {
          // Throw an error if a different parameter name already exists at this level.
          throw ArgumentError(
            'Conflicting parameter names at the same level: '
                'Existing: ":${parameter.name}", '
                'New: ":$paramName" '
                'for path $normalizedPath',
            'normalizedPath',
          );
        }
        currentNode.parameter = parameter;
        currentNode = parameter.node;
      } else {
        // Handle literal segment
        currentNode = currentNode.children.putIfAbsent(
          segment,
          () => _TrieNode<T>(),
        );
      }
    }
    return currentNode;
  }

  /// Attaches another [PathTrie] at the specified [normalizedPath] within this trie.
  ///
  /// The [normalizedPath] determines the location where the root of the [trie]
  /// will be attached. The last segment of the [normalizedPath] will become
  /// the key for the attached trie's root node in the current trie.
  ///
  /// For example, if this trie has a path `/a/b` and you attach another trie
  /// at `/a/b/c`, the attached trie's root will be accessible via `/a/b/c`.
  ///
  /// Throws an [ArgumentError] if:
  /// - The [normalizedPath] has a length less than 1 (i.e., attempting to attach at the root).
  /// - A node already exists at the target attachment path.
  void attach(final NormalizedPath normalizedPath, final PathTrie<T> trie) {
    final pathLength = normalizedPath.length;
    if (pathLength < 1) {
      throw ArgumentError('Cannot attach at root');
    }
    final lastSegment = normalizedPath.segments.last;
    final prefixPath = normalizedPath.subPath(0, pathLength - 1);

    final node = trie._root;
    final currentNode = _build(prefixPath);
    if (currentNode.children.containsKey(lastSegment)) {
      throw ArgumentError.value(
        normalizedPath,
        'normalizedPath',
        'Path already exists',
      );
    }

    currentNode.children[lastSegment] = node;
  }

  /// Looks up a path in the trie and extracts parameters.
  ///
  /// The [normalizedPath] is expected to be pre-normalized. Literal segments are
  /// prioritized over parameters during matching.
  ///
  /// Returns a [LookupResult] containing the associated value and extracted
  /// parameters if a matching route is found, otherwise returns `null`.
  LookupResult<T>? lookup(final NormalizedPath normalizedPath) {
    final segments = normalizedPath.segments;
    _TrieNode<T> currentNode = _root;
    final parameters = <Symbol, String>{};

    for (final segment in segments) {
      final child = currentNode.children[segment];
      if (child != null) {
        // Prioritize literal match
        currentNode = child;
      } else {
        final parameter = currentNode.parameter;
        if (parameter != null) {
          // Match parameter
          parameters[Symbol(parameter.name)] = segment;
          currentNode = parameter.node;
        } else {
          // No match
          return null;
        }
      }
    }

    final value = currentNode.value;
    return value != null ? LookupResult(value, parameters) : null;
  }
}
