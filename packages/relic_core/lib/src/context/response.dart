part of 'result.dart';

/// The response returned by a [Handler].
///
/// A [Response] encapsulates the HTTP status code, headers, and body content
/// that will be sent back to the client.
///
/// ## Success Responses
///
/// ```dart
/// // 200 OK - Standard success
/// Response.ok(body: Body.fromString('Success!'))
///
/// // 204 No Content - Success without body
/// Response.noContent()
/// ```
///
/// ## Redirect Responses
///
/// ```dart
/// // 301 Moved Permanently
/// Response.movedPermanently(Uri.parse('/new-location'))
///
/// // 302 Found - Temporary redirect
/// Response.found(Uri.parse('/temporary'))
///
/// // 303 See Other - Redirect after POST
/// Response.seeOther(Uri.parse('/success'))
/// ```
///
/// ## Client Error Responses
///
/// ```dart
/// // 400 Bad Request
/// Response.badRequest(body: Body.fromString('Invalid input'))
///
/// // 401 Unauthorized
/// Response.unauthorized(body: Body.fromString('Please log in'))
///
/// // 403 Forbidden
/// Response.forbidden(body: Body.fromString('Access denied'))
///
/// // 404 Not Found
/// Response.notFound(body: Body.fromString('Page not found'))
/// ```
///
/// ## Server Error Responses
///
/// ```dart
/// // 500 Internal Server Error
/// Response.internalServerError(body: Body.fromString('Server error'))
///
/// // 501 Not Implemented
/// Response.notImplemented(body: Body.fromString('Coming soon'))
/// ```
///
/// ## JSON Response
///
/// ```dart
/// final data = {'name': 'Alice', 'age': 30};
/// Response.ok(
///   body: Body.fromString(
///     jsonEncode(data),
///     mimeType: MimeType.json,
///   ),
/// )
/// ```
///
/// ## HTML Response
///
/// ```dart
/// Response.ok(
///   body: Body.fromString(
///     '<html><body><h1>Hello!</h1></body></html>',
///     mimeType: MimeType.html,
///   ),
/// )
/// ```
class Response extends Message implements Result {
  /// The HTTP status code of the response.
  final int statusCode;

  /// Constructs a 200 OK response.
  ///
  /// This indicates that the request has succeeded.
  ///
  /// {@template relic_response_body_and_encoding_param}
  /// [body] is the response body. It may be a [Body] instance or `null` to
  /// indicate no body. Use [Body.fromString], [Body.fromBytes], or
  /// [Body.fromDataStream] to create the body with the appropriate content type
  /// and encoding.
  ///
  /// [headers] must contain values that are either `String` or `List<String>`.
  /// An empty list will cause the header to be omitted.
  /// {@endtemplate}
  Response.ok({final Body? body, final Headers? headers})
    : this(
        200,
        body: body ?? Body.empty(),
        headers: headers ?? Headers.empty(),
      );

  /// Constructs a 301 Moved Permanently response.
  ///
  /// This indicates that the requested resource has moved permanently to a new
  /// URI. [location] is that URI; it can be either a [String] or a [Uri]. It's
  /// automatically set as the Location header in [headers].
  ///
  /// {@macro relic_response_body_and_encoding_param}
  Response.movedPermanently(
    final Uri location, {
    final Body? body,
    final Headers? headers,
  }) : this._redirect(301, location, body, headers);

  /// Constructs a 302 Found response.
  ///
  /// This indicates that the requested resource has moved temporarily to a new
  /// URI. [location] is that URI; it can be either a [String] or a [Uri]. It's
  /// automatically set as the Location header in [headers].
  ///
  /// {@macro relic_response_body_and_encoding_param}
  Response.found(final Uri location, {final Body? body, final Headers? headers})
    : this._redirect(302, location, body, headers);

  /// Constructs a 303 See Other response.
  ///
  /// This indicates that the response to the request should be retrieved using
  /// a GET request to a new URI. [location] is that URI; it can be either a
  /// [String] or a [Uri]. It's automatically set as the Location header in
  /// [headers].
  ///
  /// {@macro relic_response_body_and_encoding_param}
  Response.seeOther(
    final Uri location, {
    final Body? body,
    final Headers? headers,
  }) : this._redirect(303, location, body, headers);

  /// A helper constructor for redirect responses.
  Response._redirect(
    final int statusCode,
    final Uri location,
    final Body? body,
    final Headers? headers,
  ) : this(
        statusCode,
        body: body ?? Body.empty(),
        headers: (headers ?? Headers.empty()).transform(
          (final mh) => mh.location = location,
        ),
      );

  /// Constructs a 204 No Content response.
  ///
  /// This indicates that the request has succeeded but that the server has no
  /// further information to send in the response body.
  ///
  /// {@macro relic_response_body_and_encoding_param}
  Response.noContent({final Headers? headers})
    : this(204, body: Body.empty(), headers: headers ?? Headers.empty());

  /// Constructs a 304 Not Modified response.
  ///
  /// This is used to respond to a conditional GET request that provided
  /// information used to determine whether the requested resource has changed
  /// since the last request. It indicates that the resource has not changed and
  /// the old value should be used.
  ///
  /// [headers] must contain values that are either `String` or `List<String>`.
  /// An empty list will cause the header to be omitted.
  ///
  /// If [headers] contains a value for `content-length` it will be removed.
  Response.notModified({final Headers? headers})
    : this(304, body: Body.empty(), headers: headers ?? Headers.empty());

  /// Constructs a 400 Bad Request response.
  ///
  /// This indicates that the server has received a malformed request.
  ///
  /// {@macro relic_response_body_and_encoding_param}
  Response.badRequest({final Body? body, final Headers? headers})
    : this(
        400,
        headers: headers ?? Headers.empty(),
        body: body ?? Body.fromString('Bad Request'),
      );

  /// Constructs a 401 Unauthorized response.
  ///
  /// This indicates indicates that the client request has not been completed
  /// because it lacks valid authentication credentials.
  ///
  /// {@macro relic_response_body_and_encoding_param}
  Response.unauthorized({final Body? body, final Headers? headers})
    : this(
        401,
        headers: headers ?? Headers.empty(),
        body: body ?? Body.fromString('Unauthorized'),
      );

  /// Constructs a 403 Forbidden response.
  ///
  /// This indicates that the server is refusing to fulfill the request.
  ///
  /// {@macro relic_response_body_and_encoding_param}
  Response.forbidden({final Body? body, final Headers? headers})
    : this(
        403,
        headers: headers ?? Headers.empty(),
        body: body ?? Body.fromString('Forbidden'),
      );

  /// Constructs a 404 Not Found response.
  ///
  /// This indicates that the server didn't find any resource matching the
  /// requested URI.
  ///
  /// {@macro relic_response_body_and_encoding_param}
  Response.notFound({final Body? body, final Headers? headers})
    : this(
        404,
        headers: headers ?? Headers.empty(),
        body: body ?? Body.fromString('Not Found'),
      );

  /// Constructs a 500 Internal Server Error response.
  ///
  /// This indicates that the server had an internal error that prevented it
  /// from fulfilling the request.
  ///
  /// {@macro relic_response_body_and_encoding_param}
  Response.internalServerError({final Body? body, final Headers? headers})
    : this(
        500,
        headers: headers ?? Headers.empty(),
        body: body ?? Body.fromString('Internal Server Error'),
      );

  /// Constructs a 501 Not Implemented response.
  ///
  /// This indicates that the server does not support the functionality required
  /// to fulfill the request.
  ///
  /// {@macro relic_response_body_and_encoding_param}
  Response.notImplemented({final Body? body, final Headers? headers})
    : this(
        501,
        headers: headers ?? Headers.empty(),
        body: body ?? Body.fromString('Not Implemented'),
      );

  /// Constructs a 413 Content Too Large response.
  ///
  /// This indicates that the request entity is larger than the server is willing
  /// or able to process.
  ///
  /// {@macro relic_response_body_and_encoding_param}
  Response.contentTooLarge({final Body? body, final Headers? headers})
    : this(
        413,
        headers: (headers ?? Headers.empty()).transform(
          (final mh) => mh.connection = const ConnectionHeader.directives([
            ConnectionHeaderType.close,
          ]),
        ),
        body: body ?? Body.fromString('Content Too Large'),
      );

  /// Constructs an HTTP response with the given [statusCode].
  ///
  /// [statusCode] must be greater than or equal to 100.
  ///
  /// {@macro relic_response_body_and_encoding_param}
  Response(this.statusCode, {final Body? body, final Headers? headers})
    : super(body: body ?? Body.empty(), headers: headers ?? Headers.empty()) {
    if (statusCode < 100) {
      throw ArgumentError('Invalid status code: $statusCode.');
    }
  }

  /// Creates a new [Response] by copying existing values and applying specified
  /// changes.
  ///
  /// [body] is the response body. It may be either a [String], a [List<int>], a
  /// [Stream<List<int>>], or `<int>[]` (empty list) to indicate no body.
  @override
  Response copyWith({final Headers? headers, final Body? body}) {
    return Response(
      statusCode,
      body: body ?? this.body,
      headers: headers ?? this.headers,
    );
  }
}
