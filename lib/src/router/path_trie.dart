import 'normalized_path.dart';

typedef Parameters = Map<Symbol, String>;

/// Represents the successfull result of a lookup.
class TrieMatch<T> {
  /// The value associated with the matched route.
  final T value;

  /// A map of parameter names to their extracted values from the path.
  final Parameters parameters;

  /// The normalized path that was matched.
  final NormalizedPath matched;

  /// If a match, does not consume the full path, then stores the [remaining]
  ///
  /// This can only happen with a path that ends with a tail segment `/**`,
  /// otherwise it will be empty.
  final NormalizedPath remaining;

  /// Creates a [TrieMatch] with the given [value] and [parameters].
  const TrieMatch(this.value, this.parameters, this.matched, this.remaining);
}

/// A node within the path trie.
final class _TrieNode<T> {
  /// Child nodes representing literal path segments.
  final Map<String, _TrieNode<T>> children = {};

  /// Parameter definition associated with this node, if any.
  _DynamicSegment<T>? dynamicSegment;

  /// The value associated with the path ending at this node.
  ///
  /// A non-null value indicates the end of a path
  T? value;

  /// A map function applied on lookup, before returning result.
  ///
  /// If null, no mapping is applied.
  T Function(T value)? map;

  /// Indicates whether this node is empty.
  bool get isEmpty =>
      children.isEmpty && dynamicSegment == null && value == null;
}

sealed class _DynamicSegment<T> {
  final node = _TrieNode<T>();
}

/// Stores the parameter [name] and the child [node] that represents the
/// parameterized path segment.
final class _Parameter<T> extends _DynamicSegment<T> {
  final String name;

  _Parameter(this.name);
}

final class _Wildcard<T> extends _DynamicSegment<T> {}

final class _Tail<T> extends _DynamicSegment<T> {}

/// A Trie (prefix tree) data structure optimized for matching URL paths.
///
/// Supports literal segments, parameterized segments (e.g., `:id`), wildcard segments (`*`),
/// and tail segments (`**`). Allows associating a value of type [T] with each complete path.
final class PathTrie<T extends Object> {
  // Note: not final since we update in attach
  var _root = _TrieNode<T>();

  /// Adds a path and its associated value to the trie.
  ///
  /// The [normalizedPath] is expected to be pre-normalized (e.g., using
  /// [NormalizedPath]). Path segments starting with `:` are treated as parameters.
  ///
  /// If the path already exists, an [ArgumentError] is
  /// thrown. If adding a parameter conflicts with an existing parameter name at
  /// the same level (e.g., adding `/users/:id` after `/users/:userId`), an
  /// [ArgumentError] is also thrown.
  void add(final NormalizedPath normalizedPath, final T value) {
    final currentNode = _build(normalizedPath);
    // Mark the end node and handle potential overwrites
    if (currentNode.value != null) {
      throw ArgumentError.value(
        normalizedPath,
        'normalizedPath',
        'Value already registered: '
            'Existing: "${currentNode.value}" '
            'New: "$value"',
      );
    }
    currentNode.value = value;
  }

  /// Adds a path and its associated value to the trie, or updates the
  /// value if the path already exists.
  ///
  /// Returns `true` if a new value was added to the path (either the path was
  /// newly created, or it existed as an intermediate path without a value)
  /// or `false` if an existing value at the specific path was updated,
  ///
  /// Throws an [ArgumentError] if [normalizedPath] contains conflicting
  /// parameter definitions (e.g., adding `/users/:id` when `/users/:userId`
  /// exists at the same parameter level, or if a parameter name is empty).
  bool addOrUpdate(final NormalizedPath normalizedPath, final T value) {
    final currentNode = _build(normalizedPath);
    final added = currentNode.value == null;
    currentNode.value = value;
    return added;
  }

  /// Adds or updates the value associated with a path using an [action]
  /// function.
  ///
  /// This method locates or creates the node for the given [normalizedPath].
  /// It then calls the [action] function, passing the current value at that node
  /// (which may be `null` if the path is new or had no value). The value
  /// returned by [action] is then stored at the node.
  ///
  /// This is useful for scenarios where the new value depends on the old one,
  /// like incrementing a counter or modifying an existing object in place.
  ///
  /// Returns the computed value that was stored in the trie.
  ///
  /// Throws an [ArgumentError] if [normalizedPath] contains conflicting
  /// parameter definitions (e.g., adding `/users/:id` when `/users/:userId`
  /// exists at the same parameter level, or if a parameter name is empty).
  T addOrUpdateInPlace(
    final NormalizedPath normalizedPath,
    final T Function(T? old) action,
  ) {
    final currentNode = _build(normalizedPath);
    final value = action(currentNode.value);
    currentNode.value = value;
    return value;
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
        normalizedPath,
        'normalizedPath',
        'No value registered',
      );
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

  /// Sets the mapping to use on lookup for any path where [normalizedPath] is
  /// a prefix-path.
  ///
  /// If an existing mapping already exists then the new mapping will be the
  /// old composed with [map], otherwise [map] will be used directly.
  void use(final NormalizedPath normalizedPath, final T Function(T) map) {
    final currentNode = _build(normalizedPath);
    final oldMap = currentNode.map;
    currentNode.map = oldMap == null ? map : (final v) => oldMap(map(v));
  }

  /// Finds the [_TrieNode] that exactly matches the given [normalizedPath].
  _TrieNode<T>? _find(final NormalizedPath normalizedPath) {
    final segments = normalizedPath.segments;
    _TrieNode<T> currentNode = _root;

    // Helper function
    @pragma('vm:prefer-inline')
    _TrieNode<T>? nextIf<U extends _DynamicSegment<T>>(
      final _DynamicSegment<T>? dynamicSegment,
    ) {
      if (dynamicSegment != null && dynamicSegment is U) {
        return dynamicSegment.node;
      }
      return null;
    }

    for (final segment in segments) {
      var nextNode = currentNode.children[segment];
      if (nextNode == null) {
        final dynamicSegment = currentNode.dynamicSegment;
        if (segment == '**') {
          // Handle tail segment
          nextNode = nextIf<_Tail<T>>(dynamicSegment);
        } else if (segment == '*') {
          // Handle wildcard segment
          nextNode = nextIf<_Wildcard<T>>(dynamicSegment);
        } else if (segment.startsWith(':')) {
          // Handle parameter segment
          final parameter = dynamicSegment as _Parameter<T>?;
          if (parameter != null && parameter.name == segment.substring(1)) {
            nextNode = parameter.node;
          }
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

    // Helper function
    @pragma('vm:prefer-inline')
    void isA<U extends _DynamicSegment<T>>(
      final _DynamicSegment<T>? dynamicSegment,
      final int segmentNo,
    ) {
      if (dynamicSegment != null && dynamicSegment is! U) {
        normalizedPath.raiseInvalidSegment(
          segmentNo,
          'Conflicting segment type at the same level: '
          'Existing: ${dynamicSegment.runtimeType}, '
          'New: $U',
        );
      }
    }

    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final dynamicSegment = currentNode.dynamicSegment;

      if (segment.startsWith('**')) {
        // Handle tail segment
        if (segment != '**') {
          normalizedPath.raiseInvalidSegment(i, 'Starts with "**"');
        }
        if (i < segments.length - 1) {
          normalizedPath.raiseInvalidSegment(
            i,
            'Tail segment (**) must be the last segment in the path definition.',
          );
        }
        isA<_Tail<T>>(dynamicSegment, i);
        currentNode = (currentNode.dynamicSegment ??= _Tail()).node;
      } else if (segment.startsWith('*')) {
        // Handle wildcard segment
        if (segment != '*') {
          normalizedPath.raiseInvalidSegment(i, 'Starts with "*"');
        }
        isA<_Wildcard<T>>(dynamicSegment, i);
        currentNode = (currentNode.dynamicSegment ??= _Wildcard()).node;
      } else if (segment.startsWith(':')) {
        // Handle parameter segment
        isA<_Parameter<T>>(dynamicSegment, i);
        final paramName = segment.substring(1).trim();
        if (paramName.isEmpty) {
          normalizedPath.raiseInvalidSegment(
            i,
            'Parameter name cannot be empty',
          );
        }
        // Ensure parameter child exists and handle name conflicts
        var parameter = dynamicSegment as _Parameter<T>?;
        if (parameter == null) {
          parameter = _Parameter(paramName);
        } else if (parameter.name != paramName) {
          // Throw an error if a different parameter name already exists at this level.
          normalizedPath.raiseInvalidSegment(
            i,
            'Conflicting parameter names at the same level: '
            'Existing: ":${parameter.name}", '
            'New: ":$paramName"',
          );
        }
        currentNode.dynamicSegment = parameter;
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
  /// - Both nodes has an associated dynamic segment.
  /// - There are overlapping children between the nodes.
  void attach(final NormalizedPath normalizedPath, final PathTrie<T> trie) {
    final node = trie._root;
    final currentNode = _build(normalizedPath);

    if (currentNode.value != null && node.value != null) {
      throw ArgumentError('Conflicting values');
    }

    if (currentNode.dynamicSegment != null && node.dynamicSegment != null) {
      throw ArgumentError('Conflicting parameters');
    }

    final keys = currentNode.children.keys.toSet();
    final otherKeys = node.children.keys.toSet();
    if (keys.intersection(otherKeys).isNotEmpty) {
      throw ArgumentError('Conflicting children');
    }

    // No conflicts so safe to update
    currentNode.value ??= node.value;
    currentNode.dynamicSegment ??= node.dynamicSegment;
    final childMap = node.map;
    if (childMap != null) {
      final parentMap = currentNode.map;
      currentNode.map =
          parentMap == null ? childMap : (final v) => parentMap(childMap(v));
    }
    currentNode.children.addAll(node.children);
    trie._root = currentNode;
  }

  /// Looks up a path in the trie and extracts parameters.
  ///
  /// The [normalizedPath] is expected to be pre-normalized. Literal segments are
  /// prioritized over parameters during matching.
  ///
  /// Returns a [TrieMatch] containing the associated value and extracted
  /// parameters if a matching path is found, otherwise returns `null`.
  TrieMatch<T>? lookup(final NormalizedPath normalizedPath) {
    final segments = normalizedPath.segments;
    final parameters = <Symbol, String>{};

    var currentNode = _root;
    var currentMap = currentNode.map;

    // Helper function to update combinedMap when descending the trie
    void updateMap() {
      final cm = currentMap;
      final m = currentNode.map;
      currentMap =
          cm == null
              ? m // may also be null
              : (m == null
                  ? cm
                  : (final v) => cm(m(v))); // compose map function
    }

    int i = 0;
    for (; i < segments.length; i++) {
      final segment = segments[i];
      final child = currentNode.children[segment];
      if (child != null) {
        // Prioritize literal match
        currentNode = child;
        updateMap();
      } else {
        final dynamicSegment = currentNode.dynamicSegment;
        if (dynamicSegment == null) return null; // no match
        currentNode = dynamicSegment.node;
        updateMap();
        if (dynamicSegment case final _Parameter<T> parameter) {
          parameters[Symbol(parameter.name)] = segment;
        }
        if (dynamicSegment is _Tail<T>) break; // possible early match
      }
    }

    T? value = currentNode.value;
    final matchedPath = normalizedPath.subPath(0, i);
    final remainingPath = normalizedPath.subPath(i);

    // If no value found after iterating through all segments, check if
    // currentNode has a tail. If so proceed one more step. This handles cases
    // like /archive/** matching /archive, where remainingPath would be empty.
    if (value == null && i == segments.length) {
      final dynamicSegment = currentNode.dynamicSegment;
      if (dynamicSegment is _Tail<T>) {
        currentNode = dynamicSegment.node;
        value = currentNode.value;
      }
    }

    if (value == null) return null;
    value = currentMap?.call(value) ?? value;
    return TrieMatch(value, parameters, matchedPath, remainingPath);
  }

  /// Returns true if the path trie has no routes.
  bool get isEmpty => _root.isEmpty;
}

extension on NormalizedPath {
  Never raiseInvalidSegment(
    final int segmentNo,
    final String message, {
    final String name = 'normalizedPath',
  }) {
    throw ArgumentError.value(
      this,
      name,
      'Segment no $segmentNo: "${segments[segmentNo]}" is invalid. $message',
    );
  }
}
