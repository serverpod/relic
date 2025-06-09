/// Extends any type [T] with a `pipe` method for fluent function application.
extension Pipe<T> on T {
  /// Applies the given function [next] to this value.
  ///
  /// Returns the result of applying [next] to `this`.
  /// This allows for a chainable, readable way to apply a sequence of functions.
  ///
  /// Example:
  /// ```dart
  /// final result = 5
  ///   .pipe((x) => x + 3)
  ///   .pipe((x) => x * 2); // result is 16
  /// ```
  R pipe<R>(final R Function(T) next) => next(this);
}

/// Extends a function type [R Function(T)] with a `compose` method.
extension Compose<R, T> on R Function(T) {
  /// Composes this function with an [inner] function.
  ///
  /// Returns a new function that takes an argument of type [U],
  /// first applies the [inner] function ( `T Function(U)` ) to it,
  /// and then applies this function ( `R Function(T)` ) to the result.
  ///
  /// The resulting function has the signature `R Function(U)`.
  /// This is equivalent to `g(f(x))` if `this` is `g` and [inner] is `f`.
  ///
  /// Example:
  /// ```dart
  /// final intToString = (int i) => i.toString();
  /// final addPrefix = (String s) => 'Number: $s';
  /// final intToPrefixedString = addPrefix.compose(intToString);
  /// final result = intToPrefixedString(5); // "Number: 5"
  /// ```
  R Function(U) compose<U>(final T Function(U) inner) =>
      (final u) => this(inner(u));
}

// === Apply section ===

/// Extends a function of one argument [R Function(T)] with an `apply` method.
extension Apply1<T, R> on R Function(T) {
  /// Applies this function to the given argument [x].
  ///
  /// This method primarily offers a consistent naming pattern with other `Apply`
  /// extensions for partial application, though for a single-argument function
  /// it's equivalent to a direct call.
  ///
  /// Returns the result of `this(x)`.
  R apply(final T x) => this(x);
}

/// Extends a function of two arguments [R Function(T, U)] with an `apply` method
/// for partial application.
extension Apply2<R, T, U> on R Function(T, U) {
  /// Partially applies the first argument [t] to this two-argument function.
  ///
  /// Returns a new function that takes the remaining argument [U] and,
  /// when called, executes this function with [t] and the provided [U].
  ///
  /// Example:
  /// ```dart
  /// final sum = (int a, int b) => a + b;
  /// final add5 = sum.apply(5);
  /// final result = add5(3); // result is 8
  /// ```
  R Function(U) apply(final T t) => (final U u) => this(t, u);
}

/// Extends a function of three arguments [R Function(T, U, V)] with an `apply` method
/// for partial application.
extension Apply3<R, T, U, V> on R Function(T, U, V) {
  /// Partially applies the first argument [t] to this three-argument function.
  ///
  /// Returns a new function that takes the remaining two arguments ([U], [V]) and,
  /// when called, executes this function with [t] and the provided [U] and [V].
  ///
  /// Example:
  /// ```dart
  /// final concat = (String a, String b, String c) => a + b + c;
  /// final greet = concat.apply('Hello, ');
  /// final result = greet('World', '!'); // "Hello, World!"
  /// ```
  R Function(U, V) apply(final T t) => (final U u, final V v) => this(t, u, v);
}

/// Extends a function of four arguments [R Function(T, U, V, X)] with an `apply` method
/// for partial application.
extension Apply4<R, T, U, V, X> on R Function(T, U, V, X) {
  /// Partially applies the first argument [t] to this four-argument function.
  ///
  /// Returns a new function that takes the remaining three arguments ([U], [V], [X]) and,
  /// when called, executes this function with [t] and the provided [U], [V], and [X].
  ///
  /// Example:
  /// ```dart
  /// final sumFour = (int a, int b, int c, int d) => a + b + c + d;
  /// final add1 = sumFour.apply(1);
  /// final result = add1(2, 3, 4); // result is 10
  /// ```
  R Function(U, V, X) apply(final T t) =>
      (final U u, final V v, final X x) => this(t, u, v, x);
}

// === Pack section ===

/// Extends a function of one argument [R Function(T)] with a `pack` getter.
extension Pack1<R, T> on R Function(T) {
  /// A getter that returns a new function accepting a 1-element record (tuple).
  ///
  /// The returned function takes a single argument `(T,)` and applies this
  /// original function to its element.
  ///
  /// Example:
  /// ```dart
  /// final square = (int x) => x * x;
  /// final packedSquare = square.pack;
  /// final result = packedSquare((5,)); // result is 25
  /// ```
  R Function((T,)) get pack => (final (T,) x) => this(x.$1);
}

/// Extends a function of two arguments [R Function(T, U)] with a `pack` getter.
extension Pack2<R, T, U> on R Function(T, U) {
  /// A getter that returns a new function accepting a 2-element record (tuple).
  ///
  /// The returned function takes a single argument `(T, U)` and applies this
  /// original function to its elements.
  ///
  /// Example:
  /// ```dart
  /// final sum = (int a, int b) => a + b;
  /// final packedSum = sum.pack;
  /// final result = packedSum((5, 3)); // result is 8
  /// ```
  R Function((T, U)) get pack => (final (T, U) x) => this(x.$1, x.$2);
}

/// Extends a function of three arguments [R Function(T, U, V)] with a `pack` getter.
extension Pack3<R, T, U, V> on R Function(T, U, V) {
  /// A getter that returns a new function accepting a 3-element record (tuple).
  ///
  /// The returned function takes a single argument `(T, U, V)` and applies this
  /// original function to its elements.
  /// Example:
  /// ```dart
  /// final joinStrings = (String s1, String s2, String s3) => '$s1 $s2 $s3';
  /// final packedJoin = joinStrings.pack;
  /// final result = packedJoin(('Hello', 'functional', 'world')); // "Hello functional world"
  /// ```
  R Function((T, U, V)) get pack =>
      (final (T, U, V) x) => this(x.$1, x.$2, x.$3);
}

/// Extends a function of four arguments [R Function(T, U, V, X)] with a `pack` getter.
extension Pack4<R, T, U, V, X> on R Function(T, U, V, X) {
  /// A getter that returns a new function accepting a 4-element record (tuple).
  ///
  /// The returned function takes a single argument `(T, U, V, X)` and applies this
  /// original function to its elements.
  /// Example:
  /// ```dart
  /// final sumFour = (int a, int b, int c, int d) => a + b + c + d;
  /// final packedSum = sumFour.pack;
  /// final result = packedSum((1,2,3,4)); // result is 10
  /// ```
  R Function((T, U, V, X)) get pack =>
      (final (T, U, V, X) x) => this(x.$1, x.$2, x.$3, x.$4);
}
