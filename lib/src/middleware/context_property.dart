import '../../relic.dart';

/// Manages a piece of data associated with a specific [RequestContext].
///
/// `ContextProperty` allows middleware or other parts of the request handling
/// pipeline to store and retrieve data scoped to a single request. It uses an
/// [Expando] internally, keyed by a token from the [RequestContext], to ensure
/// that data does not leak between requests.
///
/// This is useful for passing information like authenticated user objects,
/// request-specific configurations, or other contextual data through different
/// layers of an application.
///
/// Example:
/// ```dart
/// // Define a context property for a user object.
/// final _currentUserProperty = ContextProperty<User>('currentUser');
///
/// // In a middleware, set the user for the current request.
/// void authMiddleware(RequestContext context, User user) {
///   currentUserProperty[context] = user;
/// }
///
/// // Later, in a handler, retrieve the user.
/// User? getCurrentUser(RequestContext context) {
///   return currentUserProperty.getOrNull(context);
/// }
/// ```
class ContextProperty<T extends Object> {
  final Expando<T> _storage; // Use token from RequestContext as anchor
  final String? _debugName; // Optional: for Expando's name

  /// Creates a new `ContextProperty`.
  ///
  /// The optional [_debugName] can be used to identify the property in
  /// debugging scenarios. It is also used as the name for the underlying
  /// [Expando].
  ContextProperty([this._debugName]) : _storage = Expando<T>(_debugName);

  /// Retrieves the value associated with the given [requestContext].
  ///
  /// Throws a [StateError] if no value is found for the [requestContext]'s token
  /// and the property has not been set. This ensures that accidental access
  /// to an uninitialized property is caught early.
  T operator [](final RequestContext requestContext) {
    return _storage[requestContext.token] ??
        (throw StateError(
            'ContextProperty value not found. Property: ${_debugName ?? T.toString()}. '
            'Ensure middleware has set this value for the request token.'));
  }

  /// Retrieves the value associated with the given [requestContext], or `null` if no value is set.
  ///
  /// This method is a non-throwing alternative to the `operator []`.
  /// Use this when it's acceptable for the property to be absent.
  T? getOrNull(final RequestContext requestContext) {
    return _storage[requestContext.token];
  }

  /// Sets the [value] for the given [requestContext].
  ///
  /// Associates the [value] with the [requestContext]'s token, allowing it
  /// to be retrieved later using `operator []` or `getOrNull`.
  void operator []=(final RequestContext requestContext, final T value) {
    _storage[requestContext.token] = value;
  }

  /// Checks if a value exists for the given [requestContext].
  ///
  /// Returns `true` if a non-null value has been set for the [requestContext]'s
  /// token, `false` otherwise.
  bool exists(final RequestContext requestContext) {
    return _storage[requestContext.token] != null;
  }

  /// Clears the value associated with the given [requestContext].
  ///
  /// This effectively removes the association in the underlying [Expando],
  /// causing subsequent gets for this [requestContext] (and this property)
  /// to return `null` (for `getOrNull`) or throw (for `operator []`).
  void clear(final RequestContext requestContext) {
    _storage[requestContext.token] = null; // Clears the association in Expando
  }
}
