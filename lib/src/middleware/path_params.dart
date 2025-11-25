part of 'routing_middleware.dart';

typedef RawPathParam = String;

/// A read-only accessor for extracting typed path parameters.
///
/// Path parameters are defined in route patterns using `:` prefix (e.g., `:id`).
/// Use this with [PathParameters] to extract typed values from the request path.
///
/// Example:
/// ```dart
/// const idParam = IntPathParam(#id);
/// router.get('/users/:id', (req) {
///   int id = req.pathParameters(idParam); // typed as int
///   return Response.ok();
/// });
/// ```
class PathParam<T extends Object>
    extends ReadOnlyAccessor<T, Symbol, RawPathParam> {
  const PathParam(super.key, super.decode);
}

/// Holds path parameters extracted from a matched route.
///
/// This is an [AccessorState] specialized for path parameters,
/// where keys are [Symbol]s and raw values are [String]s.
class PathParameters extends AccessorState<Symbol, RawPathParam> {
  PathParameters(super.raw);
}

final class NumPathParam extends PathParam<num> {
  const NumPathParam(final Symbol key) : super(key, num.parse);
}

final class IntPathParam extends PathParam<int> {
  const IntPathParam(final Symbol key) : super(key, int.parse);
}

final class DoublePathParam extends PathParam<double> {
  const DoublePathParam(final Symbol key) : super(key, double.parse);
}

final _pathParameters = ContextProperty<PathParameters>();

extension PathParametersRequestEx on Request {
  /// Typed path parameters extracted from the matched route.
  ///
  /// Parameters are defined in route patterns using `:` prefix (e.g., `:id`).
  /// Access with [PathParam].
  ///
  /// Example:
  /// ```dart
  /// const idParam = IntPathParam(#id);
  /// router.get('/users/:id', (req) {
  ///   int id = req.pathParameters(idParam); // typed as int
  ///   return Response.ok();
  /// });
  /// ```
  PathParameters get pathParameters =>
      _pathParameters[this] ??= PathParameters(rawPathParameters);
}
