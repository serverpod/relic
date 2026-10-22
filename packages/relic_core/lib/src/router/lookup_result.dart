part of 'router.dart';

/// Represents the result of looking up a route in the router.
///
/// This is a sealed class hierarchy with three possible outcomes:
///
/// - [RouterMatch]: The route was found and matched successfully
/// - [PathMiss]: No route exists for the given path
/// - [MethodMiss]: A route exists for the path, but not for the HTTP method
sealed class LookupResult<T extends Object> {
  const LookupResult();
}

/// Base class for lookup failures.
///
/// A [Miss] indicates the lookup did not find a matching handler.
/// See [PathMiss] and [MethodMiss] for specific failure types.
sealed class Miss<T extends Object> extends LookupResult<T> {
  const Miss();
}

/// Indicates that no route exists for the requested path.
///
/// This typically results in a 404 Not Found response.
final class PathMiss<T extends Object> extends Miss<T> {
  /// The normalized path that was not found.
  final NormalizedPath path;

  const PathMiss(this.path);
}

/// Indicates that a route exists for the path, but not for the HTTP method.
///
/// This typically results in a 405 Method Not Allowed response with an
/// Allow header containing the [allowed] methods.
final class MethodMiss<T extends Object> extends Miss<T> {
  /// The set of HTTP methods that are allowed for this path.
  final Set<Method> allowed;

  const MethodMiss(this.allowed);
}

/// A successful route match: the route a request takes and what the path
/// lookup extracted.
final class RouterMatch<T extends Object>
    implements LookupResult<T>, TrieMatch<T> {
  final TrieMatch<_RouterEntry<T>> _match;

  /// The method the lookup was for.
  final Method method;

  @override
  final T value;

  RouterMatch._(this._match, this.method, this.value);

  @override
  Parameters get parameters => _match.parameters;

  @override
  NormalizedPath get matched => _match.matched;

  @override
  NormalizedPath get remaining => _match.remaining;

  /// Whether a HEAD request matched the GET route of its path (RFC 9110
  /// 9.1), for lack of a HEAD route.
  bool get headFallback =>
      method == Method.head && _match.value.find(method) == null;

  /// The methods with a route of their own on the matched path.
  Set<Method> get registered => _match.value.registered;
}

/// Extension providing convenient type casting for [LookupResult] instances.
extension LookupResultExtension<T extends Object> on LookupResult<T> {
  /// Casts this result to a [TrieMatch].
  ///
  /// Throws a [TypeError] if this is not a [RouterMatch].
  /// Only use this when you've already verified the lookup succeeded.
  TrieMatch<T> get asMatch => this as RouterMatch<T>;
}
