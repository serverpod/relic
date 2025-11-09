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
///   final params = PathParameters(req.pathParameters);
///   final id = params(idParam); // typed as int
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
