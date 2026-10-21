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
  /// When an adapter hands over a target and an authority instead, the
  /// first read builds it, so a route that never asks never parses it.
  Uri get url =>
      _url ??= _target!.toUri(scheme: _scheme, authority: _authority!);

  Uri? _url;
  final String? _authority;

  /// The scheme of a URL built from a target and an authority, which is
  /// what the adapter's listener speaks.
  final String _scheme;

  /// Information about the IP connection carrying the request.
  ///
  /// Be aware that this only contains information about the last leg of the
  /// overall HTTP connection, typically from the nearest load balancer to the
  /// server.
  ConnectionInfo get connectionInfo =>
      _connectionInfo ??= _lazyConnectionInfo?.call() ?? ConnectionInfo.empty;

  ConnectionInfo? _connectionInfo;

  /// What builds [connectionInfo] on first read, so an adapter does not
  /// build one per request that nothing reads.
  final ConnectionInfo Function()? _lazyConnectionInfo;

  /// Creates a new [Request].
  ///
  /// Takes [url], or [target] with [authority] and [scheme] for a url built
  /// on demand. [exchange] is what the request came in on, when an adapter
  /// has one.
  Request._(
    this.method,
    final Uri? url,
    this._exchange, {
    final Headers? headers,
    final HttpProtocol? protocol,
    final Body? body,
    final ConnectionInfo? connectionInfo,
    final ConnectionInfo Function()? lazyConnectionInfo,
    final List<Object?>? properties,
    final RequestTarget? target,
    final String? authority,
    final String scheme = 'http',
  }) : _url = url,
       _target = target,
       _authority = authority,
       _scheme = scheme,
       protocol = protocol ?? HttpProtocol.http11,
       _connectionInfo = connectionInfo,
       _lazyConnectionInfo = lazyConnectionInfo,
       _properties = properties ?? <Object?>[],
       super(body: body ?? Body.empty(), headers: headers ?? Headers.empty()) {
    if (url == null) {
      if (target == null || authority == null) {
        throw ArgumentError(
          'A request takes a url, or a target and an authority',
        );
      }
      // Building the URL on demand skips the check that parsing it gave for
      // free, so it runs here. A FormatException here is a 400.
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
  /// Whether an adapter can tell depends on the adapter. The dart:io one
  /// only sees a peer that left once something was written.
  Future<void> get cancelled => _exchange?.cancelled ?? _never;

  static final _never = Completer<void>().future;

  /// The path and query as received.
  ///
  /// Decoded on first use. The adapter checks that a target decodes before
  /// the request reaches a handler, and the core answers 400 when it does
  /// not.
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
      _exchange,
      headers: headers ?? this.headers,
      protocol: protocol,
      body: body ?? this.body,
      connectionInfo: _connectionInfo,
      lazyConnectionInfo: _lazyConnectionInfo,
      properties: _properties,
      target: url == null ? _target : null,
      authority: _authority,
      scheme: _scheme,
    );
  }

  /// The exchange the request came in on, or null for one built without
  /// an adapter.
  final AdapterExchange? _exchange;

  /// What [ContextProperty] stores for this request, one slot per property.
  ///
  /// A copy made with [copyWith] shares the list, so a value set on either
  /// is read from both.
  final List<Object?> _properties;
}

/// Internal extension methods for [Request].
/// This is hidden in barrel file (relic.dart)
extension RequestInternal on Request {
  /// Expose private constructor internally
  static const create = Request._;

  /// The exchange the request came in on, when an adapter made it.
  AdapterExchange? get exchange => _exchange;

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
