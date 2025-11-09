import '../accessor/accessor.dart';
import '../context/result.dart';
import '../middleware/context_property.dart';

typedef RawQueryParam = String;

/// A read-only accessor for extracting typed query parameters.
///
/// Query parameters are the key-value pairs after `?` in a URL.
/// Use this with [QueryParameters] to extract typed values.
///
/// Example:
/// ```dart
/// const pageParam = IntQueryParam('page');
/// handler(req) {
///   final page = req.queryParameters(pageParam); // typed as int
///   return Response.ok();
/// }
/// ```
class QueryParam<T extends Object>
    extends ReadOnlyAccessor<T, String, RawQueryParam> {
  const QueryParam(super.key, super.decode);
}

/// Holds query parameters extracted from the request URL.
///
/// This is an [AccessorState] specialized for query parameters,
/// where keys are [String]s and raw values are [String]s.
class QueryParameters extends AccessorState<String, RawQueryParam> {
  QueryParameters(super.raw);
}

final _queryParameters = ContextProperty<QueryParameters>();

extension QueryParametersRequestEx on Request {
  /// Typed query parameters extracted from the request URL.
  ///
  /// Query parameters are the key-value pairs after `?` in a URL.
  /// Access with [QueryParam].
  ///
  /// Example:
  /// ```dart
  /// const pageParam = IntQueryParam('page');
  /// handler(req) {
  ///   int page = req.queryParameters(pageParam); // typed as int
  ///   return Response.ok();
  /// }
  /// ```
  QueryParameters get queryParameters =>
      _queryParameters[this] ??= QueryParameters(url.queryParameters);
}

final class NumQueryParam extends QueryParam<num> {
  const NumQueryParam(final String key) : super(key, num.parse);
}

final class IntQueryParam extends QueryParam<int> {
  const IntQueryParam(final String key) : super(key, int.parse);
}

final class DoubleQueryParam extends QueryParam<double> {
  const DoubleQueryParam(final String key) : super(key, double.parse);
}
