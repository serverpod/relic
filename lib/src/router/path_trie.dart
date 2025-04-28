import 'normalized_path.dart';

/// Represents the result of a route lookup.
final class LookupResult<T> {
  /// The value associated with the matched route.
  final T value;

  /// A map of parameter names to their extracted values from the path.
  final Map<Symbol, String> parameters;

  const LookupResult(this.value, this.parameters);
}

/// A node within the path trie.
final class _TrieNode<T> {
  /// Child nodes representing literal path segments.
  final Map<String, _TrieNode<T>> children = {};

  _Parameter<T>? parameter;

  /// The value associated with the route ending at this node.
  ///
  /// A non-null value indicates the end of a path
  T? value;
}

typedef _Parameter<T> = ({_TrieNode<T> node, String name});

/// A Trie (prefix tree) data structure optimized for matching URL paths.
///
/// Supports literal segments and parameterized segments (e.g., `:id`).
/// Allows associating a value of type [T] with each complete path.
final class PathTrie<T> {
  final _TrieNode<T> _root = _TrieNode<T>();

  /// Adds a route path and its associated value to the trie.
  ///
  /// The [normalizedPath] is expected to be pre-normalized (e.g., using
  /// [NormalizedPath]). Path segments starting with `:` are treated as
  /// parameters.
  ///
  /// If a route with the exact same path already exists, its value is
  /// overwritten, and a warning is printed.
  /// If adding a parameter conflicts with an existing parameter name at the
  /// same level (e.g., adding `/users/:id` after `/users/:userId`), an
  /// [ArgumentError] is thrown.
  void add(final NormalizedPath normalizedPath, final T value) {
    final segments = normalizedPath.segments;
    _TrieNode<T> currentNode = _root;

    for (final segment in segments) {
      if (segment.startsWith(':')) {
        final paramName = segment.substring(1);
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

  /// Looks up a path in the trie and extracts parameters.
  ///
  /// The [normalizedPath] is expected to be pre-normalized.
  /// Literal segments are prioritized over parameters during matching.
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
