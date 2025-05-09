import 'normalized_path.dart';

/// Represents the result of a route lookup.
final class LookupResult<T> {
  /// The value associated with the matched route.
  final T value;

  /// A map of parameter names to their extracted values from the path.
  final Map<Symbol, String> parameters;

  /// Indicates whether the matched route is dynamic (contains parameters).
  final bool isDynamic;

  /// Creates a [LookupResult] with the given [value] and [parameters].
  const LookupResult(this.value, this.parameters, this.isDynamic);
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
  // Note: not final since we update in attach
  var _root = _TrieNode<T>();

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

  /// Adds a route path and its associated value to the trie, or updates the
  /// value if the path already exists.
  ///
  /// Returns `true` if an existing value at the specific path was updated,
  /// or `false` if a new value was added to the path (either the path was
  /// newly created, or it existed as an intermediate path without a value).
  ///
  /// Throws an [ArgumentError] if [normalizedPath] contains conflicting
  /// parameter definitions (e.g., adding `/users/:id` when `/users/:userId`
  /// exists at the same parameter level, or if a parameter name is empty).
  bool addOrUpdate(final NormalizedPath normalizedPath, final T value) {
    final currentNode = _build(normalizedPath);
    final updated = currentNode.value != null;
    currentNode.value = value;
    return updated;
  }

  /// Updates the value associated with an existing route path.
  ///
  /// The [normalizedPath] must exactly match an already registered path that
  /// currently has a value.
  ///
  /// Throws an [ArgumentError] if the [normalizedPath] is not found in the
  /// trie, or if the node found at the path does not currently have a value
  /// (i.e., it's an intermediate path segment or its value was previously removed).
  ///
  /// Use [addOrUpdate] to set a value on a path that might not exist or
  /// might not currently have a value.
  void update(final NormalizedPath normalizedPath, final T value) {
    final currentNode = _find(normalizedPath);
    if (currentNode == null || currentNode.value == null) {
      throw ArgumentError.value(
          normalizedPath, 'normalizedPath', 'No value registered');
    }
    currentNode.value = value;
  }

  /// Removes the value associated with a specific route path.
  ///
  /// If found, the node's value is set to `null`.
  /// The node itself is not removed from the trie, allowing any child paths
  /// to remain accessible.
  ///
  /// The [normalizedPath] should represent the exact path definition, including
  /// any parameter segments (e.g., `/:id`).
  ///
  /// Returns the value that was previously associated with the path, or `null`
  /// if the path was not found or if the node at the path did not have a value.
  T? remove(final NormalizedPath normalizedPath) {
    final currentNode = _find(normalizedPath);
    if (currentNode == null) return null;
    final removed = currentNode.value;
    currentNode.value = null;
    return removed;
  }

  /// Finds the [_TrieNode] that exactly matches the given [normalizedPath].
  _TrieNode<T>? _find(final NormalizedPath normalizedPath) {
    final segments = normalizedPath.segments;
    _TrieNode<T> currentNode = _root;

    for (final segment in segments) {
      var nextNode = currentNode.children[segment];
      if (nextNode == null && segment.startsWith(':')) {
        final parameter = currentNode.parameter;
        if (parameter != null && parameter.name == segment.substring(1)) {
          nextNode = parameter.node;
        }
      }
      if (nextNode == null) return null; // early exit
      currentNode = nextNode;
    }
    return currentNode;
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
  /// - The node at [normalizedPath] has a value, and the root node of [trie] has as well.
  /// - Both nodes has an associated parameter.
  /// - There are overlapping children between the nodes.
  void attach(final NormalizedPath normalizedPath, final PathTrie<T> trie) {
    final node = trie._root;
    final currentNode = _build(normalizedPath);

    if (currentNode.value != null && node.value != null) {
      throw ArgumentError('Conflicting values');
    }

    if (currentNode.parameter != null && node.parameter != null) {
      throw ArgumentError('Conflicting parameters');
    }

    final keys = currentNode.children.keys.toSet();
    final otherKeys = node.children.keys.toSet();
    if (keys.intersection(otherKeys).isNotEmpty) {
      throw ArgumentError('Conflicting children');
    }

    // No conflicts so safe to update
    currentNode.value ??= node.value;
    currentNode.parameter ??= node.parameter;
    currentNode.children.addAll(node.children);
    trie._root = currentNode;
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
    var isDynamic = false;

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
          isDynamic = true;
        } else {
          // No match
          return null;
        }
      }
    }

    final value = currentNode.value;
    return value != null ? LookupResult(value, parameters, isDynamic) : null;
  }
}
