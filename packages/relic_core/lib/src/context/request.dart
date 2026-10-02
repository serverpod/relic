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

  /// The HTTP version the request arrived with.
  final HttpProtocol protocol;

  /// The original [Uri] for the request.
  ///
  /// Absolute, with the scheme and authority the request was addressed to.
  /// An adapter that hands over the target and the authority instead has
  /// it built on first read, so a route that never asks never parses it.
  Uri get url =>
      _url ??= _target!.toUri(scheme: _scheme, authority: _authority!);

  Uri? _url;
  final String? _authority;

  /// The native adapter speaks plain HTTP. An adapter with TLS hands over
  /// a Uri.
  static const _scheme = 'http';

  /// Information about the IP connection carrying the request.
  ///
  /// Be aware that this only contains information about the last leg of the
  /// overall HTTP connection, typically from the nearest load balancer to the
  /// server.
  final ConnectionInfo connectionInfo;

  /// Creates a new [Request].
  /// Takes [url], or [target] with [authority] for a url built on demand.
  Request._(
    this.method,
    final Uri? url,
    this._token, {
    final Headers? headers,
    final HttpProtocol? protocol,
    final Body? body,
    final ConnectionInfo? connectionInfo,
    final List<Object?>? properties,
    final RequestTarget? target,
    final String? authority,
  }) : _url = url,
       _target = target,
       _authority = authority,
       protocol = protocol ?? HttpProtocol.http11,
       connectionInfo = connectionInfo ?? ConnectionInfo.empty,
       _properties = properties ?? <Object?>[],
       super(body: body ?? Body.empty(), headers: headers ?? Headers.empty()) {
    if (url == null) {
      if (target == null || authority == null) {
        throw ArgumentError(
          'A request takes a url, or a target and an authority',
        );
      }
      // The URL is built on demand, so this is the check that used to come
      // free with parsing it. A FormatException here is a 400.
      Host.checkAuthority(authority);
      return;
    }
    // Cheap shape checks only. Whether the path and query decode is the
    // adapter's job, before the request reaches a handler.
    if (!url.isAbsolute) {
      throw ArgumentError.value(url, 'url', 'must be an absolute URL.');
    }
    if (url.fragment.isNotEmpty) {
      throw ArgumentError.value(url, 'url', 'may not have a fragment.');
    }
  }

  RequestTarget? _target;

  /// Completes when the peer went away before the response finished.
  ///
  /// A long-running handler can stop work it no longer has a reader for.
  /// Whether an adapter can tell depends on the adapter: the dart:io one
  /// only sees a peer that left once something was written.
  Future<void> get cancelled => switch (_token) {
    final AdapterExchange exchange => exchange.cancelled,
    _ => _never,
  };

  static final _never = Completer<void>().future;

  /// The path and query as received. Decoded on first use.
  ///
  /// The adapter checks that a target decodes before the request reaches a
  /// handler, and the core answers 400 when it does not.
  RequestTarget get target => _target ??= RequestTarget.fromUri(url);

  /// Creates a new [Request] by copying existing values and applying specified
  /// changes.
  ///
  /// All parameters are optional. If not provided, the original values are used.
  @override
  Request copyWith({final Uri? url, final Headers? headers, final Body? body}) {
    return Request._(
      method,
      url ?? _url,
      token,
      headers: headers ?? this.headers,
      protocol: protocol,
      body: body ?? this.body,
      connectionInfo: connectionInfo,
      properties: _properties,
      target: url == null ? _target : null,
      authority: _authority,
    );
  }

  final Object _token;

  /// What [ContextProperty] stores for this request, one slot per property.
  /// A copy made with [copyWith] shares the list, so a value set on either
  /// is read from both.
  final List<Object?> _properties;
}

/// Internal extension methods for [Request].
/// This is hidden in barrel file (relic.dart)
extension RequestInternal on Request {
  /// Expose private constructor internally
  static const create = Request._;

  /// Expose token internally
  Object get token => _token;

  /// The [ContextProperty] slots, indexed by the property.
  List<Object?> get properties => _properties;
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
