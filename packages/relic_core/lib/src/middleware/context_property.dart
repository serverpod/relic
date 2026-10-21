import '../context/result.dart';

/// Manages a piece of data associated with a specific [Request].
///
/// `ContextProperty` allows middleware or other parts of the request handling
/// pipeline to store and retrieve data scoped to a single request. Each
/// property owns one slot in a list the [Request] carries. A value set on a
/// request is read back from that request and from copies made of it, never
/// from another request.
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
  /// The number of properties created.
  ///
  /// A request that sets a property grows its slot list to that property's
  /// slot, so a property made per request would leak.
  static int _count = 0;

  final int _slot = _nextSlot();

  static int _nextSlot() {
    assert(
      _count < 1024,
      'Over 1024 ContextProperty instances. Create them once, as globals, '
      'not per request or per handler.',
    );
    return _count++;
  }

  final String? _debugName;

  /// Creates a new `ContextProperty`.
  ///
  /// The optional [_debugName] names the property in the error [get] throws
  /// when no value is set.
  ContextProperty([this._debugName]);

  /// Retrieves the value associated with the given [request].
  ///
  /// Throws a [StateError] if no value is found for the [request]
  /// and the property has not been set. This ensures that accidental access
  /// to an uninitialized property is caught early.
  T get(final Request request) {
    return this[request] ??
        (throw StateError(
          'ContextProperty value not found. Property: ${_debugName ?? T.toString()}. '
          'Ensure middleware has set this value for the request.',
        ));
  }

  /// Retrieves the value associated with the given [request], or `null` if no value is set.
  ///
  /// This operator is a non-throwing alternative to [get].
  /// Use this when it's acceptable for the property to be absent.
  T? operator [](final Request request) {
    final slots = request.properties;
    return _slot < slots.length ? slots[_slot] as T? : null;
  }

  /// Sets the [value] for the given [request].
  ///
  /// Associates the [value] with the [request], allowing it
  /// to be retrieved later using [get] or `operator []`.
  void operator []=(final Request request, final T? value) {
    final slots = request.properties;
    if (_slot >= slots.length) {
      if (value == null) return;
      slots.length = _slot + 1;
    }
    slots[_slot] = value;
  }
}
