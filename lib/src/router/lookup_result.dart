import 'normalized_path.dart';
import 'path_trie.dart';

/// Represents the result of a route lookup.
final class LookupResult<T> {
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

  /// Creates a [LookupResult] with the given [value] and [parameters].
  const LookupResult(this.value, this.parameters, this.matched, this.remaining);
}
