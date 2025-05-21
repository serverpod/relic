extension Pipe<T> on T {
  R pipe<R>(final R Function(T) next) => next(this);
}

extension Compose<R, T> on R Function(T) {
  R Function(U) compose<U>(final T Function(U) inner) =>
      (final u) => this(inner(u));
}

// === Apply section ===
extension Apply1<T, R> on R Function(T) {
  R apply(final T x) => this(x);
}

extension Apply2<R, T, U> on R Function(T, U) {
  R Function(U) apply(final T t) => (final U u) => this(t, u);
}

extension Apply3<R, T, U, V> on R Function(T, U, V) {
  R Function(U, V) apply(final T t) => (final U u, final V v) => this(t, u, v);
}

extension Apply4<R, T, U, V, X> on R Function(T, U, V, X) {
  R Function(U, V, X) apply(final T t) =>
      (final U u, final V v, final X x) => this(t, u, v, x);
}

// === Pack section ===
extension Pack1<R, T> on R Function(T) {
  R Function((T,)) get pack => (final (T,) x) => this(x.$1);
}

extension Pack2<R, T, U> on R Function(T, U) {
  R Function((T, U)) get pack => (final (T, U) x) => this(x.$1, x.$2);
}

extension Pack3<R, T, U, V> on R Function(T, U, V) {
  R Function((T, U, V)) get pack =>
      (final (T, U, V) x) => this(x.$1, x.$2, x.$3);
}

extension Pack4<R, T, U, V, X> on R Function(T, U, V, X) {
  R Function((T, U, V, X)) get pack =>
      (final (T, U, V, X) x) => this(x.$1, x.$2, x.$3, x.$4);
}
