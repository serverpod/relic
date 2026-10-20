import '../../relic_core.dart';

part 'mutable_headers.dart';

/// Typed reads over header values, shared by [Headers] and [MutableHeaders].
typedef HeaderValues = AccessorStateMixin<HeaderName, Iterable<String>>;

/// [Headers] is an immutable, case-insensitive view over a [HeaderStore].
///
/// Read a header through its accessor, the way path, query and form
/// parameters are read, or by name for a header Relic has no accessor for.
///
/// ## Accessing Headers
///
/// ```dart
/// router.get('/info', (req) {
///   final headers = req.headers;
///
///   // Typed accessors, as getters
///   final userAgent = headers.userAgent;
///   final contentLength = headers.contentLength;
///
///   // The same through accessors. headers(...) is null when absent.
///   final length = headers(Headers.contentLength);
///   // get throws when absent.
///   final host = headers.get(Headers.host);
///
///   // Content-Type lives on the body
///   final mimeType = req.mimeType;
///
///   // Raw access
///   final custom = headers['X-Custom-Header'];
///
///   return Response.ok();
/// });
/// ```
///
/// ## Setting Headers
///
/// ```dart
/// final headers = Headers.build((h) {
///   // Set standard headers
///   h.cacheControl = CacheControlHeader(
///     maxAge: 3600,
///     publicCache: true,
///   );
///
///   // Set custom headers
///   h['X-API-Version'] = ['2.0'];
///   h['X-Request-ID'] = ['abc123'];
/// });
///
/// // Content-Type comes from the body
/// Response.ok(
///   headers: headers,
///   body: Body.fromString('{}', mimeType: MimeType.json),
/// );
/// ```
///
/// ## Common Type-Safe Headers
///
/// ```dart
/// // Request headers
/// headers.authorization; // AuthorizationHeader?
/// headers.cookie;        // List<Cookie>
/// headers.accept;        // List<MediaType>
/// headers.userAgent;     // String?
/// headers.host;          // HostHeader?
///
/// // Response headers
/// headers.cacheControl;  // CacheControlHeader?
/// headers.setCookie;     // SetCookieHeader?
/// headers.location;      // Uri?
/// ```
final class Headers extends HeaderStore
    with AccessorStateMixin<HeaderName, Iterable<String>>, _StoreReads {
  @override
  final HeaderStore _store;

  Headers._(this._store);

  /// A view over [store], or [store] itself when it already is one.
  factory Headers.fromStore(final HeaderStore store) =>
      store is Headers ? store : Headers._(store);

  factory Headers.fromMap(final Map<String, Iterable<String>>? values) {
    if (values == null || values.isEmpty) {
      return _emptyHeaders;
    } else {
      return Headers._(MapHeaderStore.from(values));
    }
  }

  factory Headers.empty() => _emptyHeaders;

  factory Headers.build(final void Function(MutableHeaders) update) =>
      Headers.empty().transform(update);

  /// The store behind this view, for an adapter that knows what to do with
  /// its own kind.
  HeaderStore get store => _store;

  Headers transform(final void Function(MutableHeaders) update) {
    final mutable = MutableHeaders._(_store.toMutable())..adoptCache(this);
    update(mutable);
    return Headers._(mutable._store)..adoptCache(mutable);
  }

  @override
  String toString() => 'Headers(${toMap()})';

  /// Date-related headers
  static const date = HeaderAccessor(HeaderName.date, dateTimeHeaderCodec);

  static const expires = HeaderAccessor(
    HeaderName.expires,
    dateTimeHeaderCodec,
  );

  static const lastModified = HeaderAccessor(
    HeaderName.lastModified,
    dateTimeHeaderCodec,
  );

  static const ifModifiedSince = HeaderAccessor(
    HeaderName.ifModifiedSince,
    dateTimeHeaderCodec,
  );

  static const ifUnmodifiedSince = HeaderAccessor(
    HeaderName.ifUnmodifiedSince,
    dateTimeHeaderCodec,
  );

  /// General Headers
  static const origin = HeaderAccessor(HeaderName.origin, uriHeaderCodec);

  static const server = HeaderAccessor(HeaderName.server, stringHeaderCodec);

  static const via = HeaderAccessor(HeaderName.via, stringListCodec);

  /// Request Headers
  static const from = HeaderAccessor(HeaderName.from, FromHeader.codec);

  static const host = HeaderAccessor(HeaderName.host, HostHeader.codec);

  static const acceptEncoding = HeaderAccessor(
    HeaderName.acceptEncoding,
    AcceptEncodingHeader.codec,
  );

  static const acceptLanguage = HeaderAccessor(
    HeaderName.acceptLanguage,
    AcceptLanguageHeader.codec,
  );

  static const accessControlRequestHeaders = HeaderAccessor(
    HeaderName.accessControlRequestHeaders,
    stringListCodec,
  );

  static const accessControlRequestMethod = HeaderAccessor(
    HeaderName.accessControlRequestMethod,
    methodCodec,
  );

  static const age = HeaderAccessor(HeaderName.age, positiveIntHeaderCodec);

  static const authorization = HeaderAccessor(
    HeaderName.authorization,
    AuthorizationHeader.codec,
  );

  static const connection = HeaderAccessor(
    HeaderName.connection,
    ConnectionHeader.codec,
  );

  static const contentLength = HeaderAccessor(
    HeaderName.contentLength,
    intHeaderCodec,
  );

  static const contentType = HeaderAccessor(
    HeaderName.contentType,
    ContentTypeHeader.codec,
  );

  static const expect = HeaderAccessor(HeaderName.expect, ExpectHeader.codec);

  static const ifMatch = HeaderAccessor(
    HeaderName.ifMatch,
    IfMatchHeader.codec,
  );

  static const ifNoneMatch = HeaderAccessor(
    HeaderName.ifNoneMatch,
    IfNoneMatchHeader.codec,
  );

  static const ifRange = HeaderAccessor(
    HeaderName.ifRange,
    IfRangeHeader.codec,
  );

  static const maxForwards = HeaderAccessor(
    HeaderName.maxForwards,
    positiveIntHeaderCodec,
  );

  static const proxyAuthorization = HeaderAccessor(
    HeaderName.proxyAuthorization,
    AuthorizationHeader.codec,
  );

  static const range = HeaderAccessor(HeaderName.range, RangeHeader.codec);

  static const referer = HeaderAccessor(HeaderName.referer, uriHeaderCodec);

  static const userAgent = HeaderAccessor(
    HeaderName.userAgent,
    stringHeaderCodec,
  );

  static const te = HeaderAccessor(HeaderName.te, TEHeader.codec);

  static const upgrade = HeaderAccessor(
    HeaderName.upgrade,
    UpgradeHeader.codec,
  );

  /// Response Headers
  static const location = HeaderAccessor(HeaderName.location, uriHeaderCodec);

  static const xPoweredBy = HeaderAccessor(
    HeaderName.xPoweredBy,
    stringHeaderCodec,
  );

  static const accessControlAllowOrigin = HeaderAccessor(
    HeaderName.accessControlAllowOrigin,
    AccessControlAllowOriginHeader.codec,
  );

  static const accessControlExposeHeaders = HeaderAccessor(
    HeaderName.accessControlExposeHeaders,
    AccessControlExposeHeadersHeader.codec,
  );

  static const accessControlMaxAge = HeaderAccessor(
    HeaderName.accessControlMaxAge,
    intHeaderCodec,
  );

  static const allow = HeaderAccessor(
    HeaderName.allow,
    HeaderCodec(parseMethodSet, encodeMethodList),
  );

  static const cacheControl = HeaderAccessor(
    HeaderName.cacheControl,
    CacheControlHeader.codec,
  );

  static const contentEncoding = HeaderAccessor(
    HeaderName.contentEncoding,
    ContentEncodingHeader.codec,
  );

  static const contentLanguage = HeaderAccessor(
    HeaderName.contentLanguage,
    ContentLanguageHeader.codec,
  );

  static const contentLocation = HeaderAccessor(
    HeaderName.contentLocation,
    uriHeaderCodec,
  );

  static const contentRange = HeaderAccessor(
    HeaderName.contentRange,
    ContentRangeHeader.codec,
  );

  static const etag = HeaderAccessor(HeaderName.etag, ETagHeader.codec);

  static const proxyAuthenticate = HeaderAccessor(
    HeaderName.proxyAuthenticate,
    AuthenticationHeader.codec,
  );

  static const retryAfter = HeaderAccessor(
    HeaderName.retryAfter,
    RetryAfterHeader.codec,
  );

  static const trailer = HeaderAccessor(HeaderName.trailer, stringListCodec);

  static const vary = HeaderAccessor(HeaderName.vary, VaryHeader.codec);

  static const wwwAuthenticate = HeaderAccessor(
    HeaderName.wwwAuthenticate,
    AuthenticationHeader.codec,
  );

  static const contentDisposition = HeaderAccessor(
    HeaderName.contentDisposition,
    ContentDispositionHeader.codec,
  );

  /// Common Headers (Used in Both Requests and Responses)
  static const accept = HeaderAccessor(HeaderName.accept, AcceptHeader.codec);

  static const acceptRanges = HeaderAccessor(
    HeaderName.acceptRanges,
    AcceptRangesHeader.codec,
  );

  static const transferEncoding = HeaderAccessor(
    HeaderName.transferEncoding,
    TransferEncodingHeader.codec,
  );

  static const cookie = HeaderAccessor(HeaderName.cookie, CookieHeader.codec);

  static const setCookie = HeaderAccessor(
    HeaderName.setCookie,
    SetCookieHeader.codec,
  );

  /// Security and Modern Headers
  static const strictTransportSecurity = HeaderAccessor(
    HeaderName.strictTransportSecurity,
    StrictTransportSecurityHeader.codec,
  );

  static const contentSecurityPolicy = HeaderAccessor(
    HeaderName.contentSecurityPolicy,
    ContentSecurityPolicyHeader.codec,
  );

  static const referrerPolicy = HeaderAccessor(
    HeaderName.referrerPolicy,
    ReferrerPolicyHeader.codec,
  );

  static const permissionsPolicy = HeaderAccessor(
    HeaderName.permissionsPolicy,
    PermissionsPolicyHeader.codec,
  );

  static const accessControlAllowCredentials = HeaderAccessor(
    HeaderName.accessControlAllowCredentials,
    positiveBoolHeaderCodec,
  );

  static const accessControlAllowMethods = HeaderAccessor(
    HeaderName.accessControlAllowMethods,
    AccessControlAllowMethodsHeader.codec,
  );

  static const accessControlAllowHeaders = HeaderAccessor(
    HeaderName.accessControlAllowHeaders,
    AccessControlAllowHeadersHeader.codec,
  );

  static const clearSiteData = HeaderAccessor(
    HeaderName.clearSiteData,
    ClearSiteDataHeader.codec,
  );

  static const secFetchDest = HeaderAccessor(
    HeaderName.secFetchDest,
    SecFetchDestHeader.codec,
  );

  static const secFetchMode = HeaderAccessor(
    HeaderName.secFetchMode,
    SecFetchModeHeader.codec,
  );

  static const secFetchSite = HeaderAccessor(
    HeaderName.secFetchSite,
    SecFetchSiteHeader.codec,
  );

  static const forwarded = HeaderAccessor(
    HeaderName.forwarded,
    ForwardedHeader.codec,
  );

  static const xForwardedFor = HeaderAccessor(
    HeaderName.xForwardedFor,
    XForwardedForHeader.codec,
  );

  static const crossOriginResourcePolicy = HeaderAccessor(
    HeaderName.crossOriginResourcePolicy,
    CrossOriginResourcePolicyHeader.codec,
  );

  static const crossOriginEmbedderPolicy = HeaderAccessor(
    HeaderName.crossOriginEmbedderPolicy,
    CrossOriginEmbedderPolicyHeader.codec,
  );

  static const crossOriginOpenerPolicy = HeaderAccessor(
    HeaderName.crossOriginOpenerPolicy,
    CrossOriginOpenerPolicyHeader.codec,
  );

  static const _common = <HeaderAccessor>{
    cacheControl,
    connection,
    contentDisposition,
    contentEncoding,
    contentLanguage,
    contentLength,
    contentLocation,
    date,
    referrerPolicy,
    trailer,
    transferEncoding,
    upgrade,
    via,
  };

  static const _requestOnly = <HeaderAccessor>{
    accept,
    acceptEncoding,
    acceptLanguage,
    authorization,
    cookie,
    expect,
    from,
    host,
    ifMatch,
    ifModifiedSince,
    ifNoneMatch,
    ifRange,
    ifUnmodifiedSince,
    maxForwards,
    origin,
    proxyAuthorization,
    range,
    referer,
    te,
    userAgent,
    accessControlRequestHeaders,
    accessControlRequestMethod,
    secFetchDest,
    secFetchMode,
    secFetchSite,
    forwarded,
    xForwardedFor,
  };

  static const _responseOnly = <HeaderAccessor>{
    acceptRanges,
    accessControlAllowCredentials,
    accessControlAllowHeaders,
    accessControlAllowMethods,
    accessControlAllowOrigin,
    accessControlExposeHeaders,
    accessControlMaxAge,
    age,
    allow,
    clearSiteData,
    contentRange,
    contentSecurityPolicy,
    crossOriginEmbedderPolicy,
    crossOriginOpenerPolicy,
    etag,
    expires,
    lastModified,
    location,
    permissionsPolicy,
    proxyAuthenticate,
    retryAfter,
    server,
    setCookie,
    strictTransportSecurity,
    vary,
    wwwAuthenticate,
    xPoweredBy,
  };

  static const response = {..._common, ..._responseOnly};
  static const request = {..._common, ..._requestOnly};
  static const all = {..._common, ..._requestOnly, ..._responseOnly};

  /// Request Headers
  static const acceptHeader = 'accept';
  static const acceptEncodingHeader = 'accept-encoding';
  static const acceptLanguageHeader = 'accept-language';
  static const authorizationHeader = 'authorization';
  static const expectHeader = 'expect';
  static const fromHeader = 'from';
  static const hostHeader = 'host';
  static const ifMatchHeader = 'if-match';
  static const ifModifiedSinceHeader = 'if-modified-since';
  static const ifNoneMatchHeader = 'if-none-match';
  static const ifRangeHeader = 'if-range';
  static const ifUnmodifiedSinceHeader = 'if-unmodified-since';
  static const maxForwardsHeader = 'max-forwards';
  static const proxyAuthorizationHeader = 'proxy-authorization';
  static const rangeHeader = 'range';
  static const teHeader = 'te';
  static const upgradeHeader = 'upgrade';
  static const userAgentHeader = 'user-agent';
  static const accessControlRequestHeadersHeader =
      'access-control-request-headers';
  static const accessControlRequestMethodHeader =
      'access-control-request-method';
  static const forwardedHeader = 'forwarded';
  static const xForwardedForHeader = 'x-forwarded-for';

  /// Response Headers
  static const accessControlAllowCredentialsHeader =
      'access-control-allow-credentials';
  static const accessControlAllowOriginHeader = 'access-control-allow-origin';
  static const accessControlExposeHeadersHeader =
      'access-control-expose-headers';
  static const accessControlMaxAgeHeader = 'access-control-max-age';
  static const ageHeader = 'age';
  static const allowHeader = 'allow';
  static const cacheControlHeader = 'cache-control';
  static const connectionHeader = 'connection';
  static const contentDispositionHeader = 'content-disposition';
  static const contentEncodingHeader = 'content-encoding';
  static const contentLanguageHeader = 'content-language';
  static const contentLocationHeader = 'content-location';
  static const contentRangeHeader = 'content-range';
  static const etagHeader = 'etag';
  static const expiresHeader = 'expires';
  static const lastModifiedHeader = 'last-modified';
  static const locationHeader = 'location';
  static const proxyAuthenticateHeader = 'proxy-authenticate';
  static const retryAfterHeader = 'retry-after';
  static const trailerHeader = 'trailer';
  static const transferEncodingHeader = 'transfer-encoding';
  static const varyHeader = 'vary';
  static const wwwAuthenticateHeader = 'www-authenticate';
  static const xPoweredByHeader = 'x-powered-by';

  /// Common Headers (Used in Both Requests and Responses)
  static const acceptRangesHeader = 'accept-ranges';
  static const contentLengthHeader = 'content-length';
  static const contentTypeHeader = 'content-type';

  /// General Headers
  static const dateHeader = 'date';
  static const originHeader = 'origin';
  static const refererHeader = 'referer';
  static const serverHeader = 'server';
  static const viaHeader = 'via';
  static const cookieHeader = 'cookie';
  static const setCookieHeader = 'set-cookie';

  /// Security and Modern Headers
  static const strictTransportSecurityHeader = 'strict-transport-security';
  static const contentSecurityPolicyHeader = 'content-security-policy';
  static const referrerPolicyHeader = 'referrer-policy';
  static const permissionsPolicyHeader = 'permissions-policy';
  static const accessControlAllowMethodsHeader = 'access-control-allow-methods';
  static const accessControlAllowHeadersHeader = 'access-control-allow-headers';
  static const clearSiteDataHeader = 'clear-site-data';
  static const secFetchDestHeader = 'sec-fetch-dest';
  static const secFetchModeHeader = 'sec-fetch-mode';
  static const secFetchSiteHeader = 'sec-fetch-site';
  static const crossOriginResourcePolicyHeader = 'cross-origin-resource-policy';
  static const crossOriginEmbedderPolicyHeader = 'cross-origin-embedder-policy';
  static const crossOriginOpenerPolicyHeader = 'cross-origin-opener-policy';
}

/// The read side [Headers] and [MutableHeaders] share.
///
/// It delegates the [HeaderStore] members to the store behind the view,
/// and its typed reads decode from the wire bytes when the codec can.
base mixin _StoreReads on HeaderStore, HeaderValues {
  HeaderStore get _store;

  @override
  Iterable<HeaderName> get names => _store.names;

  @override
  Iterable<String> values(final HeaderName name) => _store.values(name);

  @override
  String? value(final HeaderName name) => _store.value(name);

  @override
  bool contains(final HeaderName name) => _store.contains(name);

  @override
  int get fieldCount => _store.fieldCount;

  @override
  void forEach(final void Function(HeaderName name, String value) visit) =>
      _store.forEach(visit);

  @override
  MutableHeaderStore toMutable() => _store.toMutable();

  @override
  Iterable<String>? lookup(final HeaderName key) {
    final found = _store.values(key);
    return found.isEmpty ? null : found;
  }

  /// The raw values for [key], a [HeaderName], a name as text, or an
  /// accessor.
  ///
  /// Null when absent, or when the text is not a header name at all.
  @override
  Iterable<String>? operator [](final Object key) => _lookupAny(this, key);

  /// Decodes from the wire bytes when the accessor's codec can and the store
  /// is a [ByteHeaderSource], else from the text.
  @override
  T? call<T extends Object>(
    final ReadOnlyAccessor<T, HeaderName, Iterable<String>> accessor,
  ) {
    if (accessor is HeaderAccessor<T>) {
      final codec = accessor.codec;
      // Typed as Object so the is-test promotes. HeaderStore does not
      // implement ByteHeaderSource, a store that keeps its bytes does.
      final Object store = _store;
      if (codec.decodeBytes != null && store is ByteHeaderSource) {
        final bytes = store.rawValue(accessor.key);
        if (bytes != null) {
          final value = decodeCached<Object>(
            accessor,
            bytes,
            () => accessor.decodeBytes(bytes) ?? _undecoded,
          );
          if (!identical(value, _undecoded)) return value as T;
        }
      }
      if (codec.isSingle) {
        // The first value alone, so a lazy store decodes one field and
        // builds no list of every value for the name.
        final first = _store.value(accessor.key);
        if (first == null) return null;
        return decodeCached(accessor, first, () => accessor.decode([first]));
      }
    }
    return super.call(accessor);
  }

  /// The decoded value for [accessor].
  ///
  /// Throws [MissingHeaderException] when absent and
  /// [InvalidHeaderException] when it does not decode.
  @override
  T get<T extends Object>(
    final ReadOnlyAccessor<T, HeaderName, Iterable<String>> accessor,
  ) =>
      call(accessor) ??
      (throw MissingHeaderException('', headerType: accessor.key.lower));

  /// The fields as a map from lowercase name to values.
  Map<String, List<String>> toMap() => {
    for (final name in names) name.lower: values(name).toList(),
  };
}

/// The Map view the previous [Headers] had, for code that iterates it.
extension HeadersEntries on Headers {
  /// Every field as a map entry from lowercase name to values.
  @Deprecated('Use names and values, or forEach')
  Iterable<MapEntry<String, Iterable<String>>> get entries => [
    for (final name in names) MapEntry(name.lower, values(name)),
  ];
}

Iterable<String>? _lookupAny(final HeaderValues headers, final Object key) {
  switch (key) {
    case final HeaderName name:
      return headers.lookup(name);
    case final ReadOnlyAccessor<dynamic, HeaderName, Iterable<String>> a:
      return headers.lookup(a.key);
    case final String text:
      final HeaderName name;
      try {
        name = HeaderName.lookup(text);
      } on FormatException {
        return null;
      }
      return headers.lookup(name);
    default:
      throw ArgumentError.value(key, 'key', 'Not a header name');
  }
}

final _emptyHeaders = Headers._(MapHeaderStore());

/// The cached result of a byte decode the codec declined, so the text path
/// runs and the decline is remembered.
final _undecoded = Object();
