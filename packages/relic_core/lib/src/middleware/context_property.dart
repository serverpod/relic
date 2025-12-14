import '../context/result.dart';

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
///   _currentUserProperty[context] = user;
/// }
///
/// // Later, in a handler, retrieve the user.
/// User? getCurrentUser(Request context) {
///   return _currentUserProperty[context];
/// }
///
/// // Maybe create an extension method for convenience.
/// extension on Request {
///   User get currentUser => _currentUserProperty.get(this);
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
  T get(final Request request) {
    return this[request] ??
        (throw StateError(
          'ContextProperty value not found. Property: ${_debugName ?? T.toString()}. '
          'Ensure middleware has set this value for the request token.',
        ));
  }

  /// Retrieves the value associated with the given [request], or `null` if no value is set.
  ///
  /// This operator is a non-throwing alternative to [get].
  /// Use this when it's acceptable for the property to be absent.
  T? operator [](final Request request) => _storage[request.token];

  /// Sets the [value] for the given [request].
  ///
  /// Associates the [value] with the [request]'s token, allowing it
  /// to be retrieved later using [get] or `operator []`.
  void operator []=(final Request request, final T? value) =>
      _storage[request.token] = value;
}
