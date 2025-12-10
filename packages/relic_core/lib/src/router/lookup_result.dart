import 'method.dart';
import 'normalized_path.dart';
import 'path_trie.dart';

/// Represents the result of looking up a route in the router.
///
/// This is a sealed class hierarchy with three possible outcomes:
///
/// - [RouterMatch]: The route was found and matched successfully
/// - [PathMiss]: No route exists for the given path
/// - [MethodMiss]: A route exists for the path, but not for the HTTP method
sealed class LookupResult<T> {
  const LookupResult();
}

/// Base class for lookup failures.
///
/// A [Miss] indicates the lookup did not find a matching handler.
/// See [PathMiss] and [MethodMiss] for specific failure types.
sealed class Miss<T> extends LookupResult<T> {
  const Miss();
}

/// Indicates that no route exists for the requested path.
///
/// This typically results in a 404 Not Found response.
final class PathMiss<T> extends Miss<T> {
  /// The normalized path that was not found.
  final NormalizedPath path;

  const PathMiss(this.path);
}

/// Indicates that a route exists for the path, but not for the HTTP method.
///
/// This typically results in a 405 Method Not Allowed response with an
/// Allow header containing the [allowed] methods.
final class MethodMiss<T> extends Miss<T> {
  /// The set of HTTP methods that are allowed for this path.
  final Set<Method> allowed;

  const MethodMiss(this.allowed);
}

/// A successful route match containing the handler value and extracted parameters.
final class RouterMatch<T> extends TrieMatch<T> implements LookupResult<T> {
  RouterMatch(super.value, super.parameters, super.matched, super.remaining);
}

/// Extension providing convenient type casting for [LookupResult] instances.
extension LookupResultExtension<T> on LookupResult<T> {
  /// Casts this result to a [TrieMatch].
  ///
  /// Throws a [TypeError] if this is not a [RouterMatch].
  /// Only use this when you've already verified the lookup succeeded.
  TrieMatch<T> get asMatch => this as RouterMatch<T>;
}
