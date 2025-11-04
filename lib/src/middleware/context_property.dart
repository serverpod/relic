import '../context/context.dart';

/// Manages a piece of data associated with a specific [Request].
///
/// `ContextProperty` allows middleware or other parts of the request handling
/// pipeline to store and retrieve data scoped to a single request. It uses an
/// [Expando] internally, keyed by a token from the [Request], to ensure
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
/// void authMiddleware(Request context, User user) {
///   currentUserProperty[context] = user;
/// }
///
/// // Later, in a handler, retrieve the user.
/// User? getCurrentUser(Request context) {
///   return currentUserProperty.getOrNull(context);
/// }
/// ```
class ContextProperty<T extends Object> {
  final Expando<T> _storage; // Use token from Request as anchor
  final String? _debugName; // Optional: for Expando's name

  /// Creates a new `ContextProperty`.
  ///
  /// The optional [_debugName] can be used to identify the property in
  /// debugging scenarios. It is also used as the name for the underlying
  /// [Expando].
  ContextProperty([this._debugName]) : _storage = Expando<T>(_debugName);

  /// Retrieves the value associated with the given [request].
  ///
  /// Throws a [StateError] if no value is found for the [request]'s token
  /// and the property has not been set. This ensures that accidental access
  /// to an uninitialized property is caught early.
  T operator [](final Request request) {
    return _storage[request.token] ??
        (throw StateError(
          'ContextProperty value not found. Property: ${_debugName ?? T.toString()}. '
          'Ensure middleware has set this value for the request token.',
        ));
  }

  /// Retrieves the value associated with the given [request], or `null` if no value is set.
  ///
  /// This method is a non-throwing alternative to the `operator []`.
  /// Use this when it's acceptable for the property to be absent.
  T? getOrNull(final Request request) {
    return _storage[request.token];
  }

  /// Sets the [value] for the given [request].
  ///
  /// Associates the [value] with the [request]'s token, allowing it
  /// to be retrieved later using `operator []` or `getOrNull`.
  void operator []=(final Request request, final T value) {
    _storage[request.token] = value;
  }

  /// Checks if a value exists for the given [request].
  ///
  /// Returns `true` if a non-null value has been set for the [request]'s
  /// token, `false` otherwise.
  bool exists(final Request request) {
    return _storage[request.token] != null;
  }

  /// Clears the value associated with the given [request].
  ///
  /// This effectively removes the association in the underlying [Expando],
  /// causing subsequent gets for this [request] (and this property)
  /// to return `null` (for `getOrNull`) or throw (for `operator []`).
  void clear(final Request request) {
    _storage[request.token] = null; // Clears the association in Expando
  }
}
