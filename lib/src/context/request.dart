part of 'result.dart';

/// An HTTP request to be processed by a Relic Server application.
///
/// The [Request] object provides access to all information about an incoming
/// HTTP request, including the method, URL, headers, query parameters, and body.
///
/// ## Usage Examples
///
/// ```dart
/// // Basic request handling
/// router.get('/users/:id', (req) {
///   // Access path parameters
///   final id = req.pathParameters[#id];
///
///   // Access HTTP method
///   print(req.method); // Method.get
///
///   // Access query parameters
///   final sort = req.url.queryParameters['sort'];
///   final filter = req.url.queryParameters['filter'];
///
///   // Multiple values for same parameter
///   // URL: /tags?tag=dart&tag=server
///   final tags = req.url.queryParametersAll['tag'];
///   // tags = ['dart', 'server']
///
///   // Access headers
///   final userAgent = req.headers.userAgent;
///
///   return Response.ok(
///     body: Body.fromString('User request'),
///   );
/// });
///
/// // Reading request body
/// router.post('/api/data', (req) async {
///   // Check if body exists
///   if (req.isEmpty) {
///     return Response.badRequest();
///   }
///
///   // Read as string
///   final bodyText = await req.readAsString();
///
///   // Parse JSON
///   final data = jsonDecode(bodyText);
///   return Response.ok();
/// });
/// ```
class Request extends Message {
  /// The HTTP request method, such as "GET" or "POST".
  final Method method;

  /// The HTTP protocol version used in the request, either "1.0" or "1.1".
  final String protocolVersion;

  /// The original [Uri] for the request.
  final Uri url;

  /// Creates a new [Request].
  Request._(
    this.method,
    this.url,
    this._token, {
    final Headers? headers,
    final String? protocolVersion,
    final Body? body,
  }) : protocolVersion = protocolVersion ?? '1.1',
       super(body: body ?? Body.empty(), headers: headers ?? Headers.empty()) {
    try {
      // Trigger URI parsing methods that may throw format exception (in Request
      // constructor or in handlers / routing).
      url.pathSegments;
      url.queryParametersAll;
    } on FormatException catch (e) {
      throw ArgumentError.value(url, 'url', 'URI parsing failed: $e');
    }

    if (!url.isAbsolute) {
      throw ArgumentError.value(url, 'url', 'must be an absolute URL.');
    }

    if (url.fragment.isNotEmpty) {
      throw ArgumentError.value(url, 'url', 'may not have a fragment.');
    }
  }

  /// Creates a new [Request] by copying existing values and applying specified
  /// changes.
  ///
  /// All parameters are optional. If not provided, the original values are used.
  @override
  Request copyWith({final Headers? headers, final Uri? url, final Body? body}) {
    return Request._(
      method,
      url ?? this.url,
      token,
      headers: headers ?? this.headers,
      protocolVersion: protocolVersion,
      body: body ?? this.body,
    );
  }

  final Object _token;
}

/// Internal extension methods for [Request].
/// This is hidden in barrel file (relic.dart)
extension RequestInternal on Request {
  /// Expose private constructor internally
  static const create = Request._;

  /// Expose token internally
  Object get token => _token;
}

/// Extension methods for [Uri] used in tests and internal utilities.
extension UriEx on Uri {
  /// Returns a relative [Uri] containing only the path and query components
  /// of this [Uri], omitting scheme, host, and port.
  ///
  /// Example:
  /// ```dart
  /// final absolute = Uri.parse('http://localhost:8080/foo/bar?x=1');
  /// final relative = absolute.pathAndQuery; // Uri(path: '/foo/bar', query: 'x=1')
  /// ```
  Uri get pathAndQuery => Uri(path: path, query: query);
}
