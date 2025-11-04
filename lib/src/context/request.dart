part of 'context.dart';

/// An HTTP request to be processed by a Relic Server application.
///
/// The [Request] object provides access to all information about an incoming
/// HTTP request, including the method, URL, headers, query parameters, and body.
///
/// ## Usage Examples
///
/// ```dart
/// // Basic request handling
/// router.get('/users/:id', (ctx) {
///   final request = ctx;
///
///   // Access path parameters
///   final id = ctx.pathParameters[#id];
///
///   // Access HTTP method
///   print(request.method); // Method.get
///
///   // Access query parameters
///   final sort = request.url.queryParameters['sort'];
///   final filter = request.url.queryParameters['filter'];
///
///   // Multiple values for same parameter
///   // URL: /tags?tag=dart&tag=server
///   final tags = request.url.queryParametersAll['tag'];
///   // tags = ['dart', 'server']
///
///   // Access headers
///   final userAgent = request.headers.userAgent;
///
///   return ctx.respond(Response.ok(
///     body: Body.fromString('User request'),
///   ));
/// });
///
/// // Reading request body
/// router.post('/api/data', (ctx) async {
///   final request = ctx;
///
///   // Check if body exists
///   if (request.isEmpty) {
///     return ctx.respond(Response.badRequest());
///   }
///
///   // Read as string
///   final bodyText = await request.readAsString();
///
///   // Parse JSON
///   final data = jsonDecode(bodyText);
///   return ctx.respond(Response.ok());
/// });
/// ```
/// ```
class Request extends Message {
  /// The URL path from the current handler to the requested resource, relative
  /// to [handlerPath], plus any query parameters.
  ///
  /// This should be used by handlers for determining which resource to serve,
  /// in preference to [requestedUri]. This allows handlers to do the right
  /// thing when they're mounted anywhere in the application. Routers should be
  /// sure to update this when dispatching to a nested handler, using the
  /// `path` parameter to [copyWith].
  ///
  /// [url]'s path is always relative. It may be empty, if [requestedUri] ends
  /// at this handler. [url] will always have the same query parameters as
  /// [requestedUri].
  ///
  /// [handlerPath] and [url]'s path combine to create [requestedUri]'s path.
  final Uri url;

  /// The HTTP request method, such as "GET" or "POST".
  final Method method;

  /// The URL path to the current handler.
  ///
  /// This allows a handler to know its location within the URL-space of an
  /// application. Routers should be sure to update this when dispatching to a
  /// nested handler, using the `path` parameter to [copyWith].
  ///
  /// [handlerPath] is always a root-relative URL path; that is, it always
  /// starts with `/`. It will also end with `/` whenever [url]'s path is
  /// non-empty, or if [requestedUri]'s path ends with `/`.
  ///
  /// [handlerPath] and [url]'s path combine to create [requestedUri]'s path.
  final String handlerPath;

  /// The HTTP protocol version used in the request, either "1.0" or "1.1".
  final String protocolVersion;

  /// The original [Uri] for the request.
  final Uri requestedUri;

  /// Creates a new [Request].
  ///
  /// [handlerPath] must be root-relative. [url]'s path must be fully relative,
  /// and it must have the same query parameters as [requestedUri].
  /// [handlerPath] and [url]'s path must combine to be the path component of
  /// [requestedUri]. If they're not passed, [handlerPath] will default to `/`
  /// and [url] to `requestedUri.path` without the initial `/`. If only one is
  /// passed, the other will be inferred.
  ///
  /// [body] is the request body. It may be either a [String], a [List<int>], a
  /// [Stream<List<int>>], or `null` to indicate no body. If it's a [String],
  /// [encoding] is used to encode it to a [Stream<List<int>>]. The default
  /// encoding is UTF-8.
  ///
  /// If [encoding] is passed, the "encoding" field of the Content-Type header
  /// in [headers] will be set appropriately. If there is no existing
  /// Content-Type header, it will be set to "application/octet-stream".
  /// [headers] must contain values that are either `String` or `List<String>`.
  /// An empty list will cause the header to be omitted.
  ///
  /// The default value for [protocolVersion] is '1.1'.
  Request(
    final Method method,
    final Uri requestedUri, {
    final String? protocolVersion,
    final Headers? headers,
    final String? handlerPath,
    final Uri? url,
    final Body? body,
  }) : this._(
         method,
         requestedUri,
         Object(),
         headers ?? Headers.empty(),
         protocolVersion: protocolVersion,
         url: url,
         handlerPath: handlerPath,
         body: body,
       );

  /// This constructor has the same signature as [Request.new] except that
  /// accepts [onHijack] as [_OnHijack].
  ///
  /// Any [Request] created by calling [copyWith] will pass [_onHijack] from the
  /// source [Request] to ensure that [hijack] can only be called once, even
  /// from a changed [Request].
  Request._(
    this.method,
    this.requestedUri,
    this._token,
    final Headers headers, {
    final String? protocolVersion,
    final String? handlerPath,
    final Uri? url,
    final Body? body,
  }) : protocolVersion = protocolVersion ?? '1.1',
       url = _computeUrl(requestedUri, handlerPath, url),
       handlerPath = _computeHandlerPath(requestedUri, handlerPath, url),
       super(body: body ?? Body.empty(), headers: headers) {
    try {
      // Trigger URI parsing methods that may throw format exception (in Request
      // constructor or in handlers / routing).
      requestedUri.pathSegments;
      requestedUri.queryParametersAll;
    } on FormatException catch (e) {
      throw ArgumentError.value(
        requestedUri,
        'requestedUri',
        'URI parsing failed: $e',
      );
    }

    if (!requestedUri.isAbsolute) {
      throw ArgumentError.value(
        requestedUri,
        'requestedUri',
        'must be an absolute URL.',
      );
    }

    if (requestedUri.fragment.isNotEmpty) {
      throw ArgumentError.value(
        requestedUri,
        'requestedUri',
        'may not have a fragment.',
      );
    }

    // Notice that because relative paths must encode colon (':') as %3A we
    // cannot actually combine this.handlerPath and this.url.path, but we can
    // compare the pathSegments. In practice exposing this.url.path as a Uri
    // and not a String is probably the underlying flaw here.
    final handlerPart = Uri(path: this.handlerPath).pathSegments.join('/');
    final rest = this.url.pathSegments.join('/');
    final join = this.url.path.startsWith('/') ? '/' : '';
    final pathSegments = '$handlerPart$join$rest';
    if (pathSegments != requestedUri.pathSegments.join('/')) {
      throw ArgumentError.value(
        requestedUri,
        'requestedUri',
        'handlerPath "${this.handlerPath}" and url "${this.url}" must '
            'combine to equal requestedUri path "${requestedUri.path}".',
      );
    }
  }

  /// Creates a new [Request] by copying existing values and applying specified
  /// changes.
  ///
  /// [body] is the request body. It may be either a [String], a [List<int>], a
  /// [Stream<List<int>>], or `null` to indicate no body.
  ///
  /// [path] is used to update both [handlerPath] and [url]. It's designed for
  /// routing middleware, and represents the path from the current handler to
  /// the next handler. It must be a prefix of [url]; [handlerPath] becomes
  /// `handlerPath + "/" + path`, and [url] becomes relative to that. For
  /// example:
  /// ```dart
  /// print(request.handlerPath); // => /static/
  /// print(request.url);        // => dir/file.html

  /// request = request.change(path: "dir");
  /// print(request.handlerPath); // => /static/dir/
  /// print(request.url);        // => file.html
  /// ```
  @override
  Request copyWith({
    final Headers? headers,
    final Uri? requestedUri,
    final String? path,
    Body? body,
  }) {
    body ??= this.body;

    var handlerPath = this.handlerPath;
    if (path != null) handlerPath += path;

    return Request._(
      method,
      requestedUri ?? this.requestedUri,
      token,
      headers ?? this.headers,
      protocolVersion: protocolVersion,
      handlerPath: handlerPath,
      body: body,
    );
  }

  Object _token;
  Object get token => _token;
}

/// Computes `url` from the provided [Request] constructor arguments.
///
/// If [url] is `null`, the value is inferred from [requestedUri] and
/// [handlerPath] if available. Otherwise [url] is returned.
Uri _computeUrl(final Uri requestedUri, String? handlerPath, final Uri? url) {
  if (handlerPath != null &&
      handlerPath != requestedUri.path &&
      !handlerPath.endsWith('/')) {
    handlerPath += '/';
  }

  if (url != null) {
    if (url.scheme.isNotEmpty || url.hasAuthority || url.fragment.isNotEmpty) {
      throw ArgumentError(
        'url "$url" may contain only a path and query '
        'parameters.',
      );
    }

    if (!requestedUri.path.endsWith(url.path)) {
      throw ArgumentError(
        'url "$url" must be a suffix of requestedUri '
        '"$requestedUri".',
      );
    }

    if (requestedUri.query != url.query) {
      throw ArgumentError(
        'url "$url" must have the same query parameters '
        'as requestedUri "$requestedUri".',
      );
    }

    if (url.path.startsWith('/')) {
      throw ArgumentError('url "$url" must be relative.');
    }

    final startOfUrl = requestedUri.path.length - url.path.length;
    if (url.path.isNotEmpty &&
        requestedUri.path.substring(startOfUrl - 1, startOfUrl) != '/') {
      throw ArgumentError(
        'url "$url" must be on a path boundary in '
        'requestedUri "$requestedUri".',
      );
    }

    return url;
  } else if (handlerPath != null) {
    return Uri(
      path: requestedUri.path.substring(handlerPath.length),
      query: requestedUri.query,
    );
  } else {
    // Skip the initial "/".
    final path = requestedUri.path.substring(1);
    return Uri(path: path, query: requestedUri.query);
  }
}

/// Computes `handlerPath` from the provided [Request] constructor arguments.
///
/// If [handlerPath] is `null`, the value is inferred from [requestedUri] and
/// [url] if available. Otherwise [handlerPath] is returned.
String _computeHandlerPath(
  final Uri requestedUri,
  String? handlerPath,
  final Uri? url,
) {
  if (handlerPath != null &&
      handlerPath != requestedUri.path &&
      !handlerPath.endsWith('/')) {
    handlerPath += '/';
  }

  if (handlerPath != null) {
    if (!requestedUri.path.startsWith(handlerPath)) {
      throw ArgumentError(
        'handlerPath "$handlerPath" must be a prefix of '
        'requestedUri path "${requestedUri.path}"',
      );
    }

    if (!handlerPath.startsWith('/')) {
      throw ArgumentError('handlerPath "$handlerPath" must be root-relative.');
    }

    return handlerPath;
  } else if (url != null) {
    if (url.path.isEmpty) return requestedUri.path;

    final index = requestedUri.path.indexOf(url.path);
    return requestedUri.path.substring(0, index);
  } else {
    return '/';
  }
}

/// Internal extension methods for [Request].
extension RequestInternal on Request {
  void setToken(final Object value) => _token = value;
}
