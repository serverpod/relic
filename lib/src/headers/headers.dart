import 'dart:io' as io;

import 'package:http_parser/http_parser.dart';
import 'package:relic/relic.dart';
import 'package:relic/src/headers/extension/string_list_extensions.dart';
import 'package:relic/src/headers/parser/headers_parser.dart';
import 'package:relic/src/headers/parser/common_types_parser.dart';
import 'package:relic/src/headers/typed/typed_header_interface.dart';
import 'package:relic/src/method/request_method.dart';

abstract base class Headers {
  /// Request Headers
  static const acceptHeader = "accept";
  static const acceptEncodingHeader = "accept-encoding";
  static const acceptLanguageHeader = "accept-language";
  static const authorizationHeader = "authorization";
  static const expectHeader = "expect";
  static const fromHeader = "from";
  static const hostHeader = "host";
  static const ifMatchHeader = "if-match";
  static const ifModifiedSinceHeader = "if-modified-since";
  static const ifNoneMatchHeader = "if-none-match";
  static const ifRangeHeader = "if-range";
  static const ifUnmodifiedSinceHeader = "if-unmodified-since";
  static const maxForwardsHeader = "max-forwards";
  static const proxyAuthorizationHeader = "proxy-authorization";
  static const rangeHeader = "range";
  static const teHeader = "te";
  static const upgradeHeader = "upgrade";
  static const userAgentHeader = "user-agent";
  static const accessControlRequestHeadersHeader =
      'access-control-request-headers';
  static const accessControlRequestMethodHeader =
      'access-control-request-method';

  /// Response Headers
  static const accessControlAllowCredentialsHeader =
      'access-control-allow-credentials';
  static const accessControlAllowOriginHeader = 'access-control-allow-origin';
  static const accessControlExposeHeadersHeader =
      'access-control-expose-headers';
  static const accessControlMaxAgeHeader = 'access-control-max-age';
  static const ageHeader = "age";
  static const allowHeader = "allow";
  static const cacheControlHeader = "cache-control";
  static const connectionHeader = "connection";
  static const contentDispositionHeader = "content-disposition";
  static const contentEncodingHeader = "content-encoding";
  static const contentLanguageHeader = "content-language";
  static const contentLocationHeader = "content-location";
  static const contentRangeHeader = "content-range";
  static const etagHeader = "etag";
  static const expiresHeader = "expires";
  static const lastModifiedHeader = "last-modified";
  static const locationHeader = "location";
  static const proxyAuthenticationHeader = "proxy-authenticate";
  static const retryAfterHeader = "retry-after";
  static const trailerHeader = "trailer";
  static const transferEncodingHeader = "transfer-encoding";
  static const varyHeader = "vary";
  static const wwwAuthenticateHeader = "www-authenticate";
  static const xPoweredByHeader = 'x-powered-by';

  /// Common Headers (Used in Both Requests and Responses)
  static const acceptRangesHeader = "accept-ranges";
  static const contentLengthHeader = "content-length";
  static const contentTypeHeader = "content-type";

  /// General Headers
  static const dateHeader = "date";
  static const originHeader = "origin";
  static const refererHeader = "referer";
  static const serverHeader = "server";
  static const viaHeader = "via";
  static const cookieHeader = "cookie";
  static const setCookieHeader = "set-cookie";

  /// Security and Modern Headers
  static const strictTransportSecurityHeader = "strict-transport-security";
  static const contentSecurityPolicyHeader = "content-security-policy";
  static const referrerPolicyHeader = "referrer-policy";
  static const permissionsPolicyHeader = "permissions-policy";
  static const accessControlAllowMethodsHeader = "access-control-allow-methods";
  static const accessControlAllowHeadersHeader = "access-control-allow-headers";
  static const clearSiteDataHeader = "clear-site-data";
  static const secFetchDestHeader = "sec-fetch-dest";
  static const secFetchModeHeader = "sec-fetch-mode";
  static const secFetchSiteHeader = "sec-fetch-site";
  static const crossOriginResourcePolicyHeader = "cross-origin-resource-policy";
  static const crossOriginEmbedderPolicyHeader = "cross-origin-embedder-policy";
  static const crossOriginOpenerPolicyHeader = "cross-origin-opener-policy";

  /// Define header properties

  /// Date-related headers`
  final _LazyInit<DateTime?> _date;
  DateTime? get date => _date.value;

  final _LazyInit<DateTime?> _expires;
  DateTime? get expires => _expires.value;

  final _LazyInit<DateTime?> _ifModifiedSince;
  DateTime? get ifModifiedSince => _ifModifiedSince.value;

  final _LazyInit<DateTime?> _lastModified;
  DateTime? get lastModified => _lastModified.value;

  /// General Headers
  final _LazyInit<Uri?> _origin;
  Uri? get origin => _origin.value;

  final _LazyInit<String?> _server;
  String? get server => _server.value;

  final _LazyInit<List<String>?> _via;
  List<String>? get via => _via.value;

  /// Request Headers
  final _LazyInit<CookieHeader?> _cookie;
  CookieHeader? get cookie => _cookie.value;

  final _LazyInit<FromHeader?> _from;
  FromHeader? get from => _from.value;

  final _LazyInit<Uri?> _host;
  Uri? get host => _host.value;

  final _LazyInit<AcceptEncodingHeader?> _acceptEncoding;
  AcceptEncodingHeader? get acceptEncoding => _acceptEncoding.value;

  final _LazyInit<AcceptLanguageHeader?> _acceptLanguage;
  AcceptLanguageHeader? get acceptLanguage => _acceptLanguage.value;

  final _LazyInit<List<String>?> _accessControlRequestHeaders;
  List<String>? get accessControlRequestHeaders =>
      _accessControlRequestHeaders.value;

  final _LazyInit<RequestMethod?> _accessControlRequestMethod;
  RequestMethod? get accessControlRequestMethod =>
      _accessControlRequestMethod.value;

  final _LazyInit<int?> _age;
  int? get age => _age.value;

  final _LazyInit<AuthorizationHeader?> _authorization;
  AuthorizationHeader? get authorization => _authorization.value;

  final _LazyInit<AuthorizationHeader?> _proxyAuthorization;
  AuthorizationHeader? get proxyAuthorization => _proxyAuthorization.value;

  final _LazyInit<ConnectionHeader?> _connection;
  ConnectionHeader? get connection => _connection.value;

  final _LazyInit<ExpectHeader?> _expect;
  ExpectHeader? get expect => _expect.value;

  final _LazyInit<IfMatchHeader?> _ifMatch;
  IfMatchHeader? get ifMatch => _ifMatch.value;

  final _LazyInit<IfNoneMatchHeader?> _ifNoneMatch;
  IfNoneMatchHeader? get ifNoneMatch => _ifNoneMatch.value;

  final _LazyInit<IfRangeHeader?> _ifRange;
  IfRangeHeader? get ifRange => _ifRange.value;

  final _LazyInit<int?> _maxForwards;
  int? get maxForwards => _maxForwards.value;

  final _LazyInit<RangeHeader?> _range;
  RangeHeader? get range => _range.value;

  final _LazyInit<Uri?> _referer;
  Uri? get referer => _referer.value;

  final _LazyInit<String?> _userAgent;
  String? get userAgent => _userAgent.value;

  final _LazyInit<TEHeader?> _te;
  TEHeader? get te => _te.value;

  final _LazyInit<UpgradeHeader?> _upgrade;
  UpgradeHeader? get upgrade => _upgrade.value;

  /// Response Headers
  final _LazyInit<SetCookieHeader?> _setCookie;
  SetCookieHeader? get setCookie => _setCookie.value;

  final _LazyInit<List<RequestMethod>?> _allow;
  List<RequestMethod>? get allow => _allow.value;

  final _LazyInit<Uri?> _location;
  Uri? get location => _location.value;

  final _LazyInit<bool?> _accessControlAllowCredentials;
  bool? get accessControlAllowCredentials =>
      _accessControlAllowCredentials.value;

  final _LazyInit<AccessControlAllowOriginHeader?> _accessControlAllowOrigin;
  AccessControlAllowOriginHeader? get accessControlAllowOrigin =>
      _accessControlAllowOrigin.value;

  final _LazyInit<AccessControlExposeHeadersHeader?>
      _accessControlExposeHeaders;
  AccessControlExposeHeadersHeader? get accessControlExposeHeaders =>
      _accessControlExposeHeaders.value;

  final _LazyInit<int?> _accessControlMaxAge;
  int? get accessControlMaxAge => _accessControlMaxAge.value;

  final _LazyInit<CacheControlHeader?> _cacheControl;
  CacheControlHeader? get cacheControl => _cacheControl.value;

  final _LazyInit<ContentEncodingHeader?> _contentEncoding;
  ContentEncodingHeader? get contentEncoding => _contentEncoding.value;

  final _LazyInit<ContentLanguageHeader?> _contentLanguage;
  ContentLanguageHeader? get contentLanguage => _contentLanguage.value;

  final _LazyInit<Uri?> _contentLocation;
  Uri? get contentLocation => _contentLocation.value;

  final _LazyInit<ContentRangeHeader?> _contentRange;
  ContentRangeHeader? get contentRange => _contentRange.value;

  final _LazyInit<ETagHeader?> _etag;
  ETagHeader? get etag => _etag.value;

  final _LazyInit<AuthenticationHeader?> _proxyAuthenticate;
  AuthenticationHeader? get proxyAuthenticate => _proxyAuthenticate.value;

  final _LazyInit<AuthenticationHeader?> _wwwAuthenticate;
  AuthenticationHeader? get wwwAuthenticate => _wwwAuthenticate.value;

  final _LazyInit<RetryAfterHeader?> _retryAfter;
  RetryAfterHeader? get retryAfter => _retryAfter.value;

  final _LazyInit<List<String>?> _trailer;
  List<String>? get trailer => _trailer.value;

  final _LazyInit<VaryHeader?> _vary;
  VaryHeader? get vary => _vary.value;

  final _LazyInit<ContentDispositionHeader?> _contentDisposition;
  ContentDispositionHeader? get contentDisposition => _contentDisposition.value;

  /// Security and Modern Headers
  final _LazyInit<StrictTransportSecurityHeader?> _strictTransportSecurity;
  StrictTransportSecurityHeader? get strictTransportSecurity =>
      _strictTransportSecurity.value;

  final _LazyInit<ContentSecurityPolicyHeader?> _contentSecurityPolicy;
  ContentSecurityPolicyHeader? get contentSecurityPolicy =>
      _contentSecurityPolicy.value;

  final _LazyInit<ReferrerPolicyHeader?> _referrerPolicy;
  ReferrerPolicyHeader? get referrerPolicy => _referrerPolicy.value;

  final _LazyInit<PermissionsPolicyHeader?> _permissionsPolicy;
  PermissionsPolicyHeader? get permissionsPolicy => _permissionsPolicy.value;

  final _LazyInit<AccessControlAllowMethodsHeader?> _accessControlAllowMethods;
  AccessControlAllowMethodsHeader? get accessControlAllowMethods =>
      _accessControlAllowMethods.value;

  final _LazyInit<AccessControlAllowHeadersHeader?> _accessControlAllowHeaders;
  AccessControlAllowHeadersHeader? get accessControlAllowHeaders =>
      _accessControlAllowHeaders.value;

  final _LazyInit<ClearSiteDataHeader?> _clearSiteData;
  ClearSiteDataHeader? get clearSiteData => _clearSiteData.value;

  final _LazyInit<SecFetchDestHeader?> _secFetchDest;
  SecFetchDestHeader? get secFetchDest => _secFetchDest.value;

  final _LazyInit<SecFetchModeHeader?> _secFetchMode;
  SecFetchModeHeader? get secFetchMode => _secFetchMode.value;

  final _LazyInit<SecFetchSiteHeader?> _secFetchSite;
  SecFetchSiteHeader? get secFetchSite => _secFetchSite.value;

  final _LazyInit<CrossOriginResourcePolicyHeader?> _crossOriginResourcePolicy;
  CrossOriginResourcePolicyHeader? get crossOriginResourcePolicy =>
      _crossOriginResourcePolicy.value;

  final _LazyInit<CrossOriginEmbedderPolicyHeader?> _crossOriginEmbedderPolicy;
  CrossOriginEmbedderPolicyHeader? get crossOriginEmbedderPolicy =>
      _crossOriginEmbedderPolicy.value;

  final _LazyInit<CrossOriginOpenerPolicyHeader?> _crossOriginOpenerPolicy;
  CrossOriginOpenerPolicyHeader? get crossOriginOpenerPolicy =>
      _crossOriginOpenerPolicy.value;

  /// Common Headers (Used in Both Requests and Responses)
  final _LazyInit<AcceptHeader?> _accept;
  AcceptHeader? get accept => _accept.value;

  final _LazyInit<AcceptRangesHeader?> _acceptRanges;
  AcceptRangesHeader? get acceptRanges => _acceptRanges.value;

  final _LazyInit<TransferEncodingHeader?> _transferEncoding;
  TransferEncodingHeader? get transferEncoding => _transferEncoding.value;

  final _LazyInit<String?> _xPoweredBy;
  String? get xPoweredBy => _xPoweredBy.value;

  /// Custom Headers
  final CustomHeaders custom;

  /// Failed headers to parse
  /// When 'strict' flag is disabled, we save the failed headers to parse
  final Map<String, List<String>> failedHeadersToParse;

  /// Managed headers
  /// Headers that are managed by the library
  static const _managedHeaders = <String>{
    dateHeader,
    expiresHeader,
    ifModifiedSinceHeader,
    ifUnmodifiedSinceHeader,
    lastModifiedHeader,

    // General Headers
    originHeader,
    serverHeader,
    viaHeader,

    // Request Headers
    acceptEncodingHeader,
    acceptLanguageHeader,
    accessControlRequestHeadersHeader,
    accessControlRequestMethodHeader,
    ageHeader,
    allowHeader,
    authorizationHeader,
    connectionHeader,
    expectHeader,
    fromHeader,
    hostHeader,
    ifMatchHeader,
    ifNoneMatchHeader,
    ifRangeHeader,
    maxForwardsHeader,
    proxyAuthorizationHeader,
    rangeHeader,
    refererHeader,
    teHeader,
    upgradeHeader,
    userAgentHeader,

    // Response Headers
    accessControlAllowCredentialsHeader,
    accessControlAllowOriginHeader,
    accessControlExposeHeadersHeader,
    accessControlMaxAgeHeader,
    cacheControlHeader,
    contentDispositionHeader,
    contentEncodingHeader,
    contentLanguageHeader,
    contentLocationHeader,
    contentRangeHeader,
    etagHeader,
    locationHeader,
    proxyAuthenticationHeader,
    retryAfterHeader,
    trailerHeader,
    transferEncodingHeader,
    varyHeader,
    wwwAuthenticateHeader,
    xPoweredByHeader,

    // Common Headers (Used in Both Requests and Responses)
    acceptHeader,
    acceptRangesHeader,
    contentLengthHeader,
    contentTypeHeader,
    cookieHeader,
    setCookieHeader,

    // Security and Modern Headers
    accessControlAllowHeadersHeader,
    accessControlAllowMethodsHeader,
    clearSiteDataHeader,
    contentSecurityPolicyHeader,
    crossOriginEmbedderPolicyHeader,
    crossOriginOpenerPolicyHeader,
    crossOriginResourcePolicyHeader,
    permissionsPolicyHeader,
    referrerPolicyHeader,
    secFetchDestHeader,
    secFetchModeHeader,
    secFetchSiteHeader,
    strictTransportSecurityHeader,
  };

  Headers._({
    // Date-related headers
    required _LazyInit<DateTime?> date,
    required _LazyInit<DateTime?> expires,
    required _LazyInit<DateTime?> ifModifiedSince,
    required _LazyInit<DateTime?> lastModified,

    // General Headers
    required _LazyInit<Uri?> origin,
    required _LazyInit<String?> server,
    required _LazyInit<List<String>?> via,

    // Request Headers
    required _LazyInit<CookieHeader?> cookie,
    required _LazyInit<FromHeader?> from,
    required _LazyInit<Uri?> host,
    required _LazyInit<AcceptEncodingHeader?> acceptEncoding,
    required _LazyInit<AcceptLanguageHeader?> acceptLanguage,
    required _LazyInit<List<String>?> accessControlRequestHeaders,
    required _LazyInit<RequestMethod?> accessControlRequestMethod,
    required _LazyInit<int?> age,
    required _LazyInit<AuthorizationHeader?> authorization,
    required _LazyInit<ConnectionHeader?> connection,
    required _LazyInit<ExpectHeader?> expect,
    required _LazyInit<IfMatchHeader?> ifMatch,
    required _LazyInit<IfNoneMatchHeader?> ifNoneMatch,
    required _LazyInit<IfRangeHeader?> ifRange,
    required _LazyInit<int?> maxForwards,
    required _LazyInit<AuthorizationHeader?> proxyAuthorization,
    required _LazyInit<RangeHeader?> range,
    required _LazyInit<Uri?> referer,
    required _LazyInit<String?> userAgent,
    required _LazyInit<TEHeader?> te,
    required _LazyInit<UpgradeHeader?> upgrade,

    // Response Headers
    required _LazyInit<SetCookieHeader?> setCookie,
    required _LazyInit<List<RequestMethod>?> allow,
    required _LazyInit<Uri?> location,
    required _LazyInit<bool?> accessControlAllowCredentials,
    required _LazyInit<AccessControlAllowOriginHeader?>
        accessControlAllowOrigin,
    required _LazyInit<AccessControlExposeHeadersHeader?>
        accessControlExposeHeaders,
    required _LazyInit<int?> accessControlMaxAge,
    required _LazyInit<CacheControlHeader?> cacheControl,
    required _LazyInit<ContentEncodingHeader?> contentEncoding,
    required _LazyInit<ContentLanguageHeader?> contentLanguage,
    required _LazyInit<Uri?> contentLocation,
    required _LazyInit<ContentRangeHeader?> contentRange,
    required _LazyInit<ETagHeader?> etag,
    required _LazyInit<AuthenticationHeader?> proxyAuthenticate,
    required _LazyInit<RetryAfterHeader?> retryAfter,
    required _LazyInit<List<String>?> trailer,
    required _LazyInit<VaryHeader?> vary,
    required _LazyInit<AuthenticationHeader?> wwwAuthenticate,
    required _LazyInit<ContentDispositionHeader?> contentDisposition,

    // Security and Modern Headers
    required _LazyInit<StrictTransportSecurityHeader?> strictTransportSecurity,
    required _LazyInit<ContentSecurityPolicyHeader?> contentSecurityPolicy,
    required _LazyInit<ReferrerPolicyHeader?> referrerPolicy,
    required _LazyInit<PermissionsPolicyHeader?> permissionsPolicy,
    required _LazyInit<AccessControlAllowMethodsHeader?>
        accessControlAllowMethods,
    required _LazyInit<AccessControlAllowHeadersHeader?>
        accessControlAllowHeaders,
    required _LazyInit<ClearSiteDataHeader?> clearSiteData,
    required _LazyInit<SecFetchDestHeader?> secFetchDest,
    required _LazyInit<SecFetchModeHeader?> secFetchMode,
    required _LazyInit<SecFetchSiteHeader?> secFetchSite,
    required _LazyInit<CrossOriginResourcePolicyHeader?>
        crossOriginResourcePolicy,
    required _LazyInit<CrossOriginEmbedderPolicyHeader?>
        crossOriginEmbedderPolicy,
    required _LazyInit<CrossOriginOpenerPolicyHeader?> crossOriginOpenerPolicy,

    // Common Headers (Used in Both Requests and Responses)
    required _LazyInit<AcceptHeader?> accept,
    required _LazyInit<AcceptRangesHeader?> acceptRanges,
    required _LazyInit<TransferEncodingHeader?> transferEncoding,
    required _LazyInit<String?> xPoweredBy,

    // Custom Headers
    CustomHeaders? custom,

    // Failed headers to parse
    required this.failedHeadersToParse,
  })  :
        // Date-related headers
        _date = date,
        _expires = expires,
        _ifModifiedSince = ifModifiedSince,
        _lastModified = lastModified,

        // General Headers
        _origin = origin,
        _server = server,
        _via = via,

        // Request Headers
        _cookie = cookie,
        _from = from,
        _host = host,
        _acceptEncoding = acceptEncoding,
        _acceptLanguage = acceptLanguage,
        _accessControlRequestHeaders = accessControlRequestHeaders,
        _accessControlRequestMethod = accessControlRequestMethod,
        _age = age,
        _authorization = authorization,
        _connection = connection,
        _expect = expect,
        _ifMatch = ifMatch,
        _ifNoneMatch = ifNoneMatch,
        _ifRange = ifRange,
        _maxForwards = maxForwards,
        _proxyAuthorization = proxyAuthorization,
        _range = range,
        _referer = referer,
        _userAgent = userAgent,
        _te = te,
        _upgrade = upgrade,

        // Response Headers
        _setCookie = setCookie,
        _allow = allow,
        _location = location,
        _accessControlAllowCredentials = accessControlAllowCredentials,
        _accessControlAllowOrigin = accessControlAllowOrigin,
        _accessControlExposeHeaders = accessControlExposeHeaders,
        _accessControlMaxAge = accessControlMaxAge,
        _cacheControl = cacheControl,
        _contentDisposition = contentDisposition,
        _contentEncoding = contentEncoding,
        _contentLanguage = contentLanguage,
        _contentLocation = contentLocation,
        _contentRange = contentRange,
        _etag = etag,
        _proxyAuthenticate = proxyAuthenticate,
        _retryAfter = retryAfter,
        _trailer = trailer,
        _vary = vary,
        _wwwAuthenticate = wwwAuthenticate,

        // Security and Modern Headers
        _strictTransportSecurity = strictTransportSecurity,
        _contentSecurityPolicy = contentSecurityPolicy,
        _referrerPolicy = referrerPolicy,
        _permissionsPolicy = permissionsPolicy,
        _accessControlAllowMethods = accessControlAllowMethods,
        _accessControlAllowHeaders = accessControlAllowHeaders,
        _clearSiteData = clearSiteData,
        _secFetchDest = secFetchDest,
        _secFetchMode = secFetchMode,
        _secFetchSite = secFetchSite,
        _crossOriginResourcePolicy = crossOriginResourcePolicy,
        _crossOriginEmbedderPolicy = crossOriginEmbedderPolicy,
        _crossOriginOpenerPolicy = crossOriginOpenerPolicy,

        // Common Headers (Used in Both Requests and Responses)
        _accept = accept,
        _acceptRanges = acceptRanges,
        _transferEncoding = transferEncoding,
        _xPoweredBy = xPoweredBy,

        // Request Headers
        custom = custom ?? CustomHeaders.empty();

  /// Create a new request headers instance from a Dart IO request
  factory Headers.fromHttpRequest(
    io.HttpRequest request, {
    bool strict = false,
    required String? xPoweredBy,
  }) {
    Map<String, List<String>> failedHeadersToParse = {};
    var dartIOHeaders = HeadersParser(
      headers: request.headers,
      strict: strict,
      onHeaderFailedToParse: (String key, List<String> value) {
        // We dont remove empty values because we want to save the
        // original value as it is, so we can see what was the invalid value
        value = value.splitTrimAndFilterUnique(
          emptyCheck: false,
        );
        if (failedHeadersToParse.containsKey(key)) {
          failedHeadersToParse[key]!.addAll(value);
        } else {
          failedHeadersToParse[key] = value;
        }
      },
    );

    return _HeadersImpl(
      // Date-related headers
      date: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          dateHeader,
          onParse: parseDate,
        ),
      ),
      expires: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          expiresHeader,
          onParse: parseDate,
        ),
      ),
      ifModifiedSince: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          ifModifiedSinceHeader,
          onParse: parseDate,
        ),
      ),
      lastModified: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          lastModifiedHeader,
          onParse: parseDate,
        ),
      ),

      // General Headers
      origin: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          originHeader,
          onParse: parseUri,
        ),
      ),
      server: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          serverHeader,
          onParse: parseString,
        ),
      ),
      via: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          viaHeader,
          onParse: parseStringList,
        ),
      ),

      // Request Headers
      cookie: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          cookieHeader,
          onParse: CookieHeader.parse,
        ),
      ),
      from: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          fromHeader,
          onParse: FromHeader.parse,
        ),
      ),
      host: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          hostHeader,
          onParse: parseUri,
        ),
      ),
      acceptEncoding: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          acceptEncodingHeader,
          onParse: AcceptEncodingHeader.parse,
        ),
      ),
      acceptLanguage: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          acceptLanguageHeader,
          onParse: AcceptLanguageHeader.parse,
        ),
      ),
      accessControlRequestHeaders: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          accessControlRequestHeadersHeader,
          onParse: parseStringList,
        ),
      ),
      accessControlRequestMethod: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          accessControlRequestMethodHeader,
          onParse: RequestMethod.parse,
        ),
      ),
      age: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          ageHeader,
          onParse: parsePositiveInt,
        ),
      ),

      authorization: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          authorizationHeader,
          onParse: AuthorizationHeader.parse,
        ),
      ),
      connection: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          connectionHeader,
          onParse: ConnectionHeader.parse,
        ),
      ),
      expect: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          expectHeader,
          onParse: ExpectHeader.parse,
        ),
      ),
      ifMatch: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          ifMatchHeader,
          onParse: IfMatchHeader.parse,
        ),
      ),
      ifNoneMatch: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          ifNoneMatchHeader,
          onParse: IfNoneMatchHeader.parse,
        ),
      ),
      ifRange: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          ifRangeHeader,
          onParse: IfRangeHeader.parse,
        ),
      ),
      maxForwards: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          maxForwardsHeader,
          onParse: parsePositiveInt,
        ),
      ),
      proxyAuthorization: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          proxyAuthorizationHeader,
          onParse: AuthorizationHeader.parse,
        ),
      ),
      range: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          rangeHeader,
          onParse: RangeHeader.parse,
        ),
      ),
      referer: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          refererHeader,
          onParse: parseUri,
        ),
      ),
      te: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          teHeader,
          onParse: TEHeader.parse,
        ),
      ),
      upgrade: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          upgradeHeader,
          onParse: UpgradeHeader.parse,
        ),
      ),
      userAgent: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          userAgentHeader,
          onParse: parseString,
        ),
      ),

      // Response Headers
      setCookie: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          setCookieHeader,
          onParse: SetCookieHeader.parse,
        ),
      ),
      allow: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          allowHeader,
          onParse: parseMethodList,
        ),
      ),
      location: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          locationHeader,
          onParse: parseUri,
        ),
      ),

      accessControlAllowCredentials: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          accessControlAllowCredentialsHeader,
          onParse: parsePositiveBool,
        ),
      ),
      accessControlAllowOrigin: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          accessControlAllowOriginHeader,
          onParse: AccessControlAllowOriginHeader.parse,
        ),
      ),
      accessControlExposeHeaders: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          accessControlExposeHeadersHeader,
          onParse: AccessControlExposeHeadersHeader.parse,
        ),
      ),
      accessControlMaxAge: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          accessControlMaxAgeHeader,
          onParse: parseInt,
        ),
      ),
      cacheControl: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          cacheControlHeader,
          onParse: CacheControlHeader.parse,
        ),
      ),
      contentDisposition: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          contentDispositionHeader,
          onParse: ContentDispositionHeader.parse,
        ),
      ),
      contentEncoding: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          contentEncodingHeader,
          onParse: ContentEncodingHeader.parse,
        ),
      ),
      contentLanguage: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          contentLanguageHeader,
          onParse: ContentLanguageHeader.parse,
        ),
      ),
      contentLocation: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          contentLocationHeader,
          onParse: parseUri,
        ),
      ),
      contentRange: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          contentRangeHeader,
          onParse: ContentRangeHeader.parse,
        ),
      ),
      etag: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          etagHeader,
          onParse: ETagHeader.parse,
        ),
      ),
      proxyAuthenticate: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          proxyAuthenticationHeader,
          onParse: AuthenticationHeader.parse,
        ),
      ),
      retryAfter: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          retryAfterHeader,
          onParse: RetryAfterHeader.parse,
        ),
      ),
      trailer: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          trailerHeader,
          onParse: parseStringList,
        ),
      ),
      vary: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          varyHeader,
          onParse: VaryHeader.parse,
        ),
      ),
      wwwAuthenticate: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          wwwAuthenticateHeader,
          onParse: AuthenticationHeader.parse,
        ),
      ),

      // Security and Modern Headers
      strictTransportSecurity: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          strictTransportSecurityHeader,
          onParse: StrictTransportSecurityHeader.parse,
        ),
      ),
      contentSecurityPolicy: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          contentSecurityPolicyHeader,
          onParse: ContentSecurityPolicyHeader.parse,
        ),
      ),
      referrerPolicy: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          referrerPolicyHeader,
          onParse: ReferrerPolicyHeader.parse,
        ),
      ),
      permissionsPolicy: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          permissionsPolicyHeader,
          onParse: PermissionsPolicyHeader.parse,
        ),
      ),
      accessControlAllowMethods: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          accessControlAllowMethodsHeader,
          onParse: AccessControlAllowMethodsHeader.parse,
        ),
      ),
      accessControlAllowHeaders: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          accessControlAllowHeadersHeader,
          onParse: AccessControlAllowHeadersHeader.parse,
        ),
      ),
      clearSiteData: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          clearSiteDataHeader,
          onParse: ClearSiteDataHeader.parse,
        ),
      ),
      secFetchDest: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          secFetchDestHeader,
          onParse: SecFetchDestHeader.parse,
        ),
      ),
      secFetchMode: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          secFetchModeHeader,
          onParse: SecFetchModeHeader.parse,
        ),
      ),
      secFetchSite: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          secFetchSiteHeader,
          onParse: SecFetchSiteHeader.parse,
        ),
      ),
      crossOriginResourcePolicy: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          crossOriginResourcePolicyHeader,
          onParse: CrossOriginResourcePolicyHeader.parse,
        ),
      ),
      crossOriginEmbedderPolicy: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          crossOriginEmbedderPolicyHeader,
          onParse: CrossOriginEmbedderPolicyHeader.parse,
        ),
      ),
      crossOriginOpenerPolicy: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          crossOriginOpenerPolicyHeader,
          onParse: CrossOriginOpenerPolicyHeader.parse,
        ),
      ),

      // Common Headers (Used in Both Requests and Responses)
      accept: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          acceptHeader,
          onParse: AcceptHeader.parse,
        ),
      ),
      acceptRanges: _LazyInit.lazy(
        init: () => dartIOHeaders.parseSingleValue(
          acceptRangesHeader,
          onParse: AcceptRangesHeader.parse,
        ),
      ),
      transferEncoding: _LazyInit.lazy(
        init: () => dartIOHeaders.parseMultipleValue(
          transferEncodingHeader,
          onParse: TransferEncodingHeader.parse,
        ),
      ),
      xPoweredBy: _LazyInit.lazy(
        init: () =>
            dartIOHeaders.parseSingleValue(
              xPoweredByHeader,
              onParse: parseString,
            ) ??
            xPoweredBy,
      ),

      // Custom Headers
      custom: parseCustomHeaders(
        dartIOHeaders.headers,
        excludedHeaders: _managedHeaders,
      ),

      // Failed Headers to Parse
      failedHeadersToParse: failedHeadersToParse,
    );
  }

  /// Create a new request headers instance
  factory Headers.request({
    // Date-related headers
    DateTime? date,
    DateTime? ifModifiedSince,

    // Request Headers
    String? xPoweredBy,
    FromHeader? from,
    Uri? host,
    AcceptEncodingHeader? acceptEncoding,
    AcceptLanguageHeader? acceptLanguage,
    List<String>? accessControlRequestHeaders,
    RequestMethod? accessControlRequestMethod,
    int? age,
    AuthorizationHeader? authorization,
    ConnectionHeader? connection,
    ExpectHeader? expect,
    IfMatchHeader? ifMatch,
    IfNoneMatchHeader? ifNoneMatch,
    IfRangeHeader? ifRange,
    int? maxForwards,
    AuthorizationHeader? proxyAuthorization,
    RangeHeader? range,
    Uri? referer,
    String? userAgent,
    CookieHeader? cookie,
    TEHeader? te,
    UpgradeHeader? upgrade,

    // Fetch Metadata Headers
    SecFetchDestHeader? secFetchDest,
    SecFetchModeHeader? secFetchMode,
    SecFetchSiteHeader? secFetchSite,

    // Common Headers (Used in Both Requests and Responses)
    AcceptHeader? accept,
    AcceptRangesHeader? acceptRanges,
    TransferEncodingHeader? transferEncoding,
    CustomHeaders? custom,
  }) {
    return _HeadersImpl(
      // Date-related headers
      date: _LazyInit.value(value: date),
      ifModifiedSince: _LazyInit.value(value: ifModifiedSince),
      expires: _LazyInit.nullValue(),
      lastModified: _LazyInit.nullValue(),

      // General Headers
      origin: _LazyInit.nullValue(),
      server: _LazyInit.nullValue(),
      via: _LazyInit.nullValue(),

      // Request Headers
      cookie: _LazyInit.value(value: cookie),
      from: _LazyInit.value(value: from),
      host: _LazyInit.value(value: host),
      acceptEncoding: _LazyInit.value(value: acceptEncoding),
      acceptLanguage: _LazyInit.value(value: acceptLanguage),
      accessControlRequestHeaders:
          _LazyInit.value(value: accessControlRequestHeaders),
      accessControlRequestMethod:
          _LazyInit.value(value: accessControlRequestMethod),
      age: _LazyInit.value(value: age),
      authorization: _LazyInit.value(value: authorization),
      connection: _LazyInit.value(value: connection),
      expect: _LazyInit.value(value: expect),
      ifMatch: _LazyInit.value(value: ifMatch),
      ifNoneMatch: _LazyInit.value(value: ifNoneMatch),
      ifRange: _LazyInit.value(value: ifRange),
      maxForwards: _LazyInit.value(value: maxForwards),
      proxyAuthorization: _LazyInit.value(value: proxyAuthorization),
      range: _LazyInit.value(value: range),
      referer: _LazyInit.value(value: referer),
      userAgent: _LazyInit.value(value: userAgent),
      te: _LazyInit.value(value: te),
      upgrade: _LazyInit.value(value: upgrade),

      // response headers
      setCookie: _LazyInit.nullValue(),
      location: _LazyInit.nullValue(),
      accessControlAllowCredentials: _LazyInit.nullValue(),
      accessControlAllowOrigin: _LazyInit.nullValue(),
      accessControlExposeHeaders: _LazyInit.nullValue(),
      accessControlMaxAge: _LazyInit.nullValue(),
      allow: _LazyInit.nullValue(),
      cacheControl: _LazyInit.nullValue(),
      contentEncoding: _LazyInit.nullValue(),
      contentLanguage: _LazyInit.nullValue(),
      contentLocation: _LazyInit.nullValue(),
      contentRange: _LazyInit.nullValue(),
      etag: _LazyInit.nullValue(),
      proxyAuthenticate: _LazyInit.nullValue(),
      retryAfter: _LazyInit.nullValue(),
      trailer: _LazyInit.nullValue(),
      vary: _LazyInit.nullValue(),
      wwwAuthenticate: _LazyInit.nullValue(),
      contentDisposition: _LazyInit.nullValue(),

      // Security and Modern Headers
      secFetchDest: _LazyInit.value(value: secFetchDest),
      secFetchMode: _LazyInit.value(value: secFetchMode),
      secFetchSite: _LazyInit.value(value: secFetchSite),
      crossOriginResourcePolicy: _LazyInit.nullValue(),
      crossOriginEmbedderPolicy: _LazyInit.nullValue(),
      crossOriginOpenerPolicy: _LazyInit.nullValue(),
      strictTransportSecurity: _LazyInit.nullValue(),
      contentSecurityPolicy: _LazyInit.nullValue(),
      referrerPolicy: _LazyInit.nullValue(),
      permissionsPolicy: _LazyInit.nullValue(),
      accessControlAllowMethods: _LazyInit.nullValue(),
      accessControlAllowHeaders: _LazyInit.nullValue(),
      clearSiteData: _LazyInit.nullValue(),

      //common headers
      accept: _LazyInit.value(value: accept),
      acceptRanges: _LazyInit.value(value: acceptRanges),
      transferEncoding: _LazyInit.value(value: transferEncoding),
      xPoweredBy: _LazyInit.value(value: xPoweredBy),

      // Custom headers
      custom: custom ?? CustomHeaders.empty(),

      // Security and Modern Headers
      failedHeadersToParse: {},
    );
  }

  factory Headers.response({
    // Date-related headers
    DateTime? date,
    DateTime? expires,
    DateTime? lastModified,

    // General Headers
    Uri? origin,
    String? server,
    List<String>? via,

    // Used from middleware
    FromHeader? from,

    // Response Headers
    List<RequestMethod>? allow,
    Uri? location,
    String? xPoweredBy,
    bool? accessControlAllowCredentials,
    AccessControlAllowOriginHeader? accessControlAllowOrigin,
    AccessControlExposeHeadersHeader? accessControlExposeHeaders,
    int? accessControlMaxAge,
    CacheControlHeader? cacheControl,
    ContentEncodingHeader? contentEncoding,
    ContentLanguageHeader? contentLanguage,
    Uri? contentLocation,
    ContentRangeHeader? contentRange,
    ETagHeader? etag,
    AuthenticationHeader? proxyAuthenticate,
    AuthenticationHeader? wwwAuthenticate,
    RetryAfterHeader? retryAfter,
    List<String>? trailer,
    VaryHeader? vary,
    ContentDispositionHeader? contentDisposition,

    // Common Headers (Used in Both Requests and Responses)
    AcceptHeader? accept,
    AcceptRangesHeader? acceptRanges,
    TransferEncodingHeader? transferEncoding,
    CustomHeaders? custom,

    // Security and Modern Headers
    SetCookieHeader? setCookie,
    StrictTransportSecurityHeader? strictTransportSecurity,
    ContentSecurityPolicyHeader? contentSecurityPolicy,
    ReferrerPolicyHeader? referrerPolicy,
    PermissionsPolicyHeader? permissionsPolicy,
    AccessControlAllowMethodsHeader? accessControlAllowMethods,
    AccessControlAllowHeadersHeader? accessControlAllowHeaders,
    ClearSiteDataHeader? clearSiteData,
    SecFetchDestHeader? secFetchDest,
    SecFetchModeHeader? secFetchMode,
    SecFetchSiteHeader? secFetchSite,
    CrossOriginResourcePolicyHeader? crossOriginResourcePolicy,
    CrossOriginEmbedderPolicyHeader? crossOriginEmbedderPolicy,
    CrossOriginOpenerPolicyHeader? crossOriginOpenerPolicy,
  }) {
    return _HeadersImpl(
      // Date-related headers
      date: _LazyInit.value(value: date ?? DateTime.now()),
      expires: _LazyInit.value(value: expires),
      lastModified: _LazyInit.value(value: lastModified),
      ifModifiedSince: _LazyInit.nullValue(),

      // General Headers
      origin: _LazyInit.value(value: origin),
      server: _LazyInit.value(value: server),
      via: _LazyInit.value(value: via),

      // This is a request header but is also used in middleware
      from: _LazyInit.value(value: from),

      // Request Headers
      cookie: _LazyInit.nullValue(),
      host: _LazyInit.nullValue(),
      acceptEncoding: _LazyInit.nullValue(),
      acceptLanguage: _LazyInit.nullValue(),
      accessControlRequestHeaders: _LazyInit.nullValue(),
      accessControlRequestMethod: _LazyInit.nullValue(),
      age: _LazyInit.nullValue(),
      authorization: _LazyInit.nullValue(),
      connection: _LazyInit.nullValue(),
      expect: _LazyInit.nullValue(),
      ifMatch: _LazyInit.nullValue(),
      ifNoneMatch: _LazyInit.nullValue(),
      ifRange: _LazyInit.nullValue(),
      maxForwards: _LazyInit.nullValue(),
      proxyAuthorization: _LazyInit.nullValue(),
      range: _LazyInit.nullValue(),
      referer: _LazyInit.nullValue(),
      userAgent: _LazyInit.nullValue(),
      te: _LazyInit.nullValue(),
      upgrade: _LazyInit.nullValue(),

      // response Headers
      allow: _LazyInit.value(value: allow),
      location: _LazyInit.value(value: location),
      accessControlAllowCredentials:
          _LazyInit.value(value: accessControlAllowCredentials),
      accessControlAllowOrigin:
          _LazyInit.value(value: accessControlAllowOrigin),
      accessControlExposeHeaders:
          _LazyInit.value(value: accessControlExposeHeaders),
      accessControlMaxAge: _LazyInit.value(value: accessControlMaxAge),
      cacheControl: _LazyInit.value(value: cacheControl),
      contentEncoding: _LazyInit.value(value: contentEncoding),
      contentLanguage: _LazyInit.value(value: contentLanguage),
      contentLocation: _LazyInit.value(value: contentLocation),
      contentRange: _LazyInit.value(value: contentRange),
      etag: _LazyInit.value(value: etag),
      proxyAuthenticate: _LazyInit.value(value: proxyAuthenticate),
      retryAfter: _LazyInit.value(value: retryAfter),
      trailer: _LazyInit.value(value: trailer),
      vary: _LazyInit.value(value: vary),
      wwwAuthenticate: _LazyInit.value(value: wwwAuthenticate),
      contentDisposition: _LazyInit.value(value: contentDisposition),
      setCookie: _LazyInit.value(value: setCookie),

      // Security and Modern Headers
      strictTransportSecurity: _LazyInit.value(value: strictTransportSecurity),
      contentSecurityPolicy: _LazyInit.value(value: contentSecurityPolicy),
      referrerPolicy: _LazyInit.value(value: referrerPolicy),
      permissionsPolicy: _LazyInit.value(value: permissionsPolicy),
      accessControlAllowMethods:
          _LazyInit.value(value: accessControlAllowMethods),
      accessControlAllowHeaders:
          _LazyInit.value(value: accessControlAllowHeaders),
      clearSiteData: _LazyInit.value(value: clearSiteData),
      secFetchDest: _LazyInit.value(value: secFetchDest),
      secFetchMode: _LazyInit.value(value: secFetchMode),
      secFetchSite: _LazyInit.value(value: secFetchSite),
      crossOriginResourcePolicy:
          _LazyInit.value(value: crossOriginResourcePolicy),
      crossOriginEmbedderPolicy:
          _LazyInit.value(value: crossOriginEmbedderPolicy),
      crossOriginOpenerPolicy: _LazyInit.value(value: crossOriginOpenerPolicy),

      // Common Headers (Used in Both Requests and Responses)
      accept: _LazyInit.value(value: accept),
      acceptRanges: _LazyInit.value(value: acceptRanges),
      transferEncoding: _LazyInit.value(value: transferEncoding),
      xPoweredBy: _LazyInit.value(value: xPoweredBy),

      // Custom headers
      custom: custom ?? CustomHeaders.empty(),

      // Failed headers to parse
      failedHeadersToParse: {},
    );
  }

  Headers copyWith({
    /// Date-related headers
    DateTime? date,
    DateTime? expires,
    DateTime? ifModifiedSince,
    DateTime? lastModified,

    /// General Headers
    Uri? origin,
    String? server,
    List<String>? via,

    /// Request Headers
    FromHeader? from,
    Uri? host,
    AcceptEncodingHeader? acceptEncoding,
    AcceptLanguageHeader? acceptLanguage,
    List<String>? accessControlRequestHeaders,
    RequestMethod? accessControlRequestMethod,
    int? age,
    AuthorizationHeader? authorization,
    ConnectionHeader? connection,
    ExpectHeader? expect,
    IfMatchHeader? ifMatch,
    IfNoneMatchHeader? ifNoneMatch,
    IfRangeHeader? ifRange,
    int? maxForwards,
    AuthorizationHeader? proxyAuthorization,
    RangeHeader? range,
    Uri? referer,
    String? userAgent,
    TEHeader? te,
    UpgradeHeader? upgrade,

    /// Response Headers
    Uri? location,
    String? xPoweredBy,
    bool? accessControlAllowCredentials,
    AccessControlAllowOriginHeader? accessControlAllowOrigin,
    AccessControlExposeHeadersHeader? accessControlExposeHeaders,
    int? accessControlMaxAge,
    List<RequestMethod>? allow,
    CacheControlHeader? cacheControl,
    ContentEncodingHeader? contentEncoding,
    ContentLanguageHeader? contentLanguage,
    Uri? contentLocation,
    ContentRangeHeader? contentRange,
    ETagHeader? etag,
    AuthenticationHeader? proxyAuthenticate,
    RetryAfterHeader? retryAfter,
    List<String>? trailer,
    VaryHeader? vary,
    List<String>? wwwAuthenticate,
    ContentDispositionHeader? contentDisposition,

    /// Common Headers (Used in Both Requests and Responses)
    AcceptHeader? accept,
    AcceptRangesHeader? acceptRanges,
    TransferEncodingHeader? transferEncoding,
    CookieHeader? cookie,
    CookieHeader? setCookie,
    CustomHeaders? custom,

    /// Security and Modern Headers
    StrictTransportSecurityHeader? strictTransportSecurity,
    ContentSecurityPolicyHeader? contentSecurityPolicy,
    ReferrerPolicyHeader? referrerPolicy,
    PermissionsPolicyHeader? permissionsPolicy,
    AccessControlAllowMethodsHeader? accessControlAllowMethods,
    AccessControlAllowHeadersHeader? accessControlAllowHeaders,
    ClearSiteDataHeader? clearSiteData,
    SecFetchDestHeader? secFetchDest,
    SecFetchModeHeader? secFetchMode,
    SecFetchSiteHeader? secFetchSite,
    CrossOriginResourcePolicyHeader? crossOriginResourcePolicy,
    CrossOriginEmbedderPolicyHeader? crossOriginEmbedderPolicy,
    CrossOriginOpenerPolicyHeader? crossOriginOpenerPolicy,
  });

  /// Convert headers to a map
  Map<String, Object> toMap();
}

/// Headers implementation
final class _HeadersImpl extends Headers {
  _HeadersImpl({
    /// Date-related headers
    required super.date,
    required super.expires,
    required super.ifModifiedSince,
    required super.lastModified,

    /// General Headers
    required super.origin,
    required super.server,
    required super.via,

    /// Request Headers
    required super.cookie,
    required super.from,
    required super.host,
    required super.acceptEncoding,
    required super.acceptLanguage,
    required super.accessControlRequestHeaders,
    required super.accessControlRequestMethod,
    required super.age,
    required super.authorization,
    required super.connection,
    required super.expect,
    required super.ifMatch,
    required super.ifNoneMatch,
    required super.ifRange,
    required super.maxForwards,
    required super.proxyAuthorization,
    required super.range,
    required super.referer,
    required super.userAgent,
    required super.te,
    required super.upgrade,

    /// Response Headers
    required super.setCookie,
    required super.location,
    required super.accessControlAllowCredentials,
    required super.accessControlAllowOrigin,
    required super.accessControlExposeHeaders,
    required super.accessControlMaxAge,
    required super.allow,
    required super.cacheControl,
    required super.contentEncoding,
    required super.contentLanguage,
    required super.contentLocation,
    required super.contentRange,
    required super.etag,
    required super.proxyAuthenticate,
    required super.retryAfter,
    required super.trailer,
    required super.vary,
    required super.wwwAuthenticate,
    required super.contentDisposition,

    /// Security and Modern Headers
    required super.strictTransportSecurity,
    required super.contentSecurityPolicy,
    required super.referrerPolicy,
    required super.permissionsPolicy,
    required super.accessControlAllowMethods,
    required super.accessControlAllowHeaders,
    required super.clearSiteData,
    required super.secFetchDest,
    required super.secFetchMode,
    required super.secFetchSite,
    required super.crossOriginResourcePolicy,
    required super.crossOriginEmbedderPolicy,
    required super.crossOriginOpenerPolicy,

    /// Common Headers (Used in Both Requests and Responses)
    required super.accept,
    required super.acceptRanges,
    required super.transferEncoding,
    required super.xPoweredBy,

    // Custom headers
    super.custom,
    // Failed headers to parse
    required super.failedHeadersToParse,
  }) : super._();

  @override
  Headers copyWith({
    Object? date = _Undefined,
    Object? expires = _Undefined,
    Object? ifModifiedSince = _Undefined,
    Object? lastModified = _Undefined,

    /// General Headers
    Object? origin = _Undefined,
    Object? server = _Undefined,
    Object? via = _Undefined,

    /// Request Headers
    Object? from = _Undefined,
    Object? host = _Undefined,
    Object? acceptEncoding = _Undefined,
    Object? acceptLanguage = _Undefined,
    Object? accessControlRequestHeaders = _Undefined,
    Object? accessControlRequestMethod = _Undefined,
    Object? age = _Undefined,
    Object? authorization = _Undefined,
    Object? connection = _Undefined,
    Object? expect = _Undefined,
    Object? ifMatch = _Undefined,
    Object? ifNoneMatch = _Undefined,
    Object? ifRange = _Undefined,
    Object? maxForwards = _Undefined,
    Object? proxyAuthorization = _Undefined,
    Object? range = _Undefined,
    Object? referer = _Undefined,
    Object? userAgent = _Undefined,
    Object? te = _Undefined,
    Object? upgrade = _Undefined,

    /// Response Headers
    Object? location = _Undefined,
    Object? xPoweredBy = _Undefined,
    Object? accessControlAllowCredentials = _Undefined,
    Object? accessControlAllowOrigin = _Undefined,
    Object? accessControlExposeHeaders = _Undefined,
    Object? accessControlMaxAge = _Undefined,
    Object? allow = _Undefined,
    Object? cacheControl = _Undefined,
    Object? contentEncoding = _Undefined,
    Object? contentLanguage = _Undefined,
    Object? contentLocation = _Undefined,
    Object? contentRange = _Undefined,
    Object? etag = _Undefined,
    Object? proxyAuthenticate = _Undefined,
    Object? retryAfter = _Undefined,
    Object? trailer = _Undefined,
    Object? vary = _Undefined,
    Object? wwwAuthenticate = _Undefined,
    Object? contentDisposition = _Undefined,

    /// Common Headers (Used in Both Requests and Responses)
    Object? accept = _Undefined,
    Object? acceptRanges = _Undefined,
    Object? transferEncoding = _Undefined,
    Object? cookie = _Undefined,
    Object? setCookie = _Undefined,
    CustomHeaders? custom,

    /// Security and Modern Headers
    Object? strictTransportSecurity = _Undefined,
    Object? contentSecurityPolicy = _Undefined,
    Object? referrerPolicy = _Undefined,
    Object? permissionsPolicy = _Undefined,
    Object? accessControlAllowMethods = _Undefined,
    Object? accessControlAllowHeaders = _Undefined,
    Object? clearSiteData = _Undefined,
    Object? secFetchDest = _Undefined,
    Object? secFetchMode = _Undefined,
    Object? secFetchSite = _Undefined,
    Object? crossOriginResourcePolicy = _Undefined,
    Object? crossOriginEmbedderPolicy = _Undefined,
    Object? crossOriginOpenerPolicy = _Undefined,
  }) {
    return _HeadersImpl(
      date: date is DateTime? ? _LazyInit.value(value: date) : _date,
      expires:
          expires is DateTime? ? _LazyInit.value(value: expires) : _expires,
      ifModifiedSince: ifModifiedSince is DateTime?
          ? _LazyInit.value(value: ifModifiedSince)
          : _ifModifiedSince,
      lastModified: lastModified is DateTime?
          ? _LazyInit.value(value: lastModified)
          : _lastModified,

      /// General Headers
      origin: origin is Uri? ? _LazyInit.value(value: origin) : _origin,
      server: server is String? ? _LazyInit.value(value: server) : _server,
      via: via is List<String>? ? _LazyInit.value(value: via) : _via,

      /// Request Headers
      cookie:
          cookie is CookieHeader? ? _LazyInit.value(value: cookie) : _cookie,
      from: from is FromHeader? ? _LazyInit.value(value: from) : _from,
      host: host is Uri? ? _LazyInit.value(value: host) : _host,
      acceptEncoding: acceptEncoding is AcceptEncodingHeader?
          ? _LazyInit.value(value: acceptEncoding)
          : _acceptEncoding,
      acceptLanguage: acceptLanguage is AcceptLanguageHeader?
          ? _LazyInit.value(value: acceptLanguage)
          : _acceptLanguage,
      accessControlRequestHeaders: accessControlRequestHeaders is List<String>?
          ? _LazyInit.value(value: accessControlRequestHeaders)
          : _accessControlRequestHeaders,
      accessControlRequestMethod: accessControlRequestMethod is RequestMethod?
          ? _LazyInit.value(value: accessControlRequestMethod)
          : _accessControlRequestMethod,
      age: age is int? ? _LazyInit.value(value: age) : _age,
      authorization: authorization is AuthorizationHeader?
          ? _LazyInit.value(value: authorization)
          : _authorization,
      connection: connection is ConnectionHeader?
          ? _LazyInit.value(value: connection)
          : _connection,
      expect:
          expect is ExpectHeader? ? _LazyInit.value(value: expect) : _expect,
      ifMatch: ifMatch is IfMatchHeader?
          ? _LazyInit.value(value: ifMatch)
          : _ifMatch,
      ifNoneMatch: ifNoneMatch is IfNoneMatchHeader?
          ? _LazyInit.value(value: ifNoneMatch)
          : _ifNoneMatch,
      ifRange: ifRange is IfRangeHeader?
          ? _LazyInit.value(value: ifRange)
          : _ifRange,
      maxForwards: maxForwards is int?
          ? _LazyInit.value(value: maxForwards)
          : _maxForwards,
      proxyAuthorization: proxyAuthorization is AuthorizationHeader?
          ? _LazyInit.value(value: proxyAuthorization)
          : _proxyAuthorization,
      range: range is RangeHeader? ? _LazyInit.value(value: range) : _range,
      referer: referer is Uri? ? _LazyInit.value(value: referer) : _referer,
      userAgent:
          userAgent is String? ? _LazyInit.value(value: userAgent) : _userAgent,
      te: te is TEHeader? ? _LazyInit.value(value: te) : _te,
      upgrade: upgrade is UpgradeHeader?
          ? _LazyInit.value(value: upgrade)
          : _upgrade,

      /// Response Headers
      setCookie: setCookie is SetCookieHeader?
          ? _LazyInit.value(value: setCookie)
          : _setCookie,
      location: location is Uri? ? _LazyInit.value(value: location) : _location,
      accessControlAllowCredentials: accessControlAllowCredentials is bool?
          ? _LazyInit.value(value: accessControlAllowCredentials)
          : _accessControlAllowCredentials,
      accessControlAllowOrigin:
          accessControlAllowOrigin is AccessControlAllowOriginHeader?
              ? _LazyInit.value(value: accessControlAllowOrigin)
              : _accessControlAllowOrigin,
      accessControlExposeHeaders:
          accessControlExposeHeaders is AccessControlExposeHeadersHeader?
              ? _LazyInit.value(value: accessControlExposeHeaders)
              : _accessControlExposeHeaders,
      accessControlMaxAge: accessControlMaxAge is int?
          ? _LazyInit.value(value: accessControlMaxAge)
          : _accessControlMaxAge,
      allow: allow is List<RequestMethod>?
          ? _LazyInit.value(value: allow)
          : _allow,
      cacheControl: cacheControl is CacheControlHeader?
          ? _LazyInit.value(value: cacheControl)
          : _cacheControl,
      contentEncoding: contentEncoding is ContentEncodingHeader?
          ? _LazyInit.value(value: contentEncoding)
          : _contentEncoding,
      contentLanguage: contentLanguage is ContentLanguageHeader?
          ? _LazyInit.value(value: contentLanguage)
          : _contentLanguage,
      contentLocation: contentLocation is Uri?
          ? _LazyInit.value(value: contentLocation)
          : _contentLocation,
      contentRange: contentRange is ContentRangeHeader?
          ? _LazyInit.value(value: contentRange)
          : _contentRange,
      etag: etag is ETagHeader? ? _LazyInit.value(value: etag) : _etag,
      proxyAuthenticate: proxyAuthenticate is AuthenticationHeader?
          ? _LazyInit.value(value: proxyAuthenticate)
          : _proxyAuthenticate,
      retryAfter: retryAfter is RetryAfterHeader?
          ? _LazyInit.value(value: retryAfter)
          : _retryAfter,
      trailer:
          trailer is List<String>? ? _LazyInit.value(value: trailer) : _trailer,
      vary: vary is VaryHeader? ? _LazyInit.value(value: vary) : _vary,
      wwwAuthenticate: wwwAuthenticate is AuthenticationHeader?
          ? _LazyInit.value(value: wwwAuthenticate)
          : _wwwAuthenticate,
      contentDisposition: contentDisposition is ContentDispositionHeader?
          ? _LazyInit.value(value: contentDisposition)
          : _contentDisposition,

      /// Security and Modern Headers
      strictTransportSecurity:
          strictTransportSecurity is StrictTransportSecurityHeader?
              ? _LazyInit.value(value: strictTransportSecurity)
              : _strictTransportSecurity,
      contentSecurityPolicy:
          contentSecurityPolicy is ContentSecurityPolicyHeader?
              ? _LazyInit.value(value: contentSecurityPolicy)
              : _contentSecurityPolicy,
      referrerPolicy: referrerPolicy is ReferrerPolicyHeader?
          ? _LazyInit.value(value: referrerPolicy)
          : _referrerPolicy,
      permissionsPolicy: permissionsPolicy is PermissionsPolicyHeader?
          ? _LazyInit.value(value: permissionsPolicy)
          : _permissionsPolicy,
      accessControlAllowMethods:
          accessControlAllowMethods is AccessControlAllowMethodsHeader?
              ? _LazyInit.value(value: accessControlAllowMethods)
              : _accessControlAllowMethods,
      accessControlAllowHeaders:
          accessControlAllowHeaders is AccessControlAllowHeadersHeader?
              ? _LazyInit.value(value: accessControlAllowHeaders)
              : _accessControlAllowHeaders,
      clearSiteData: clearSiteData is ClearSiteDataHeader?
          ? _LazyInit.value(value: clearSiteData)
          : _clearSiteData,
      secFetchDest: secFetchDest is SecFetchDestHeader?
          ? _LazyInit.value(value: secFetchDest)
          : _secFetchDest,
      secFetchMode: secFetchMode is SecFetchModeHeader?
          ? _LazyInit.value(value: secFetchMode)
          : _secFetchMode,
      secFetchSite: secFetchSite is SecFetchSiteHeader?
          ? _LazyInit.value(value: secFetchSite)
          : _secFetchSite,
      crossOriginResourcePolicy:
          crossOriginResourcePolicy is CrossOriginResourcePolicyHeader?
              ? _LazyInit.value(value: crossOriginResourcePolicy)
              : _crossOriginResourcePolicy,
      crossOriginEmbedderPolicy:
          crossOriginEmbedderPolicy is CrossOriginEmbedderPolicyHeader?
              ? _LazyInit.value(value: crossOriginEmbedderPolicy)
              : _crossOriginEmbedderPolicy,
      crossOriginOpenerPolicy:
          crossOriginOpenerPolicy is CrossOriginOpenerPolicyHeader?
              ? _LazyInit.value(value: crossOriginOpenerPolicy)
              : _crossOriginOpenerPolicy,

      /// Common Headers (Used in Both Requests and Responses)
      accept:
          accept is AcceptHeader? ? _LazyInit.value(value: accept) : _accept,
      acceptRanges: acceptRanges is AcceptRangesHeader?
          ? _LazyInit.value(value: acceptRanges)
          : _acceptRanges,
      transferEncoding: transferEncoding is TransferEncodingHeader?
          ? _LazyInit.value(value: transferEncoding)
          : _transferEncoding,
      xPoweredBy: xPoweredBy is String?
          ? _LazyInit.value(value: xPoweredBy)
          : _xPoweredBy,

      // Custom headers
      custom: custom ?? this.custom,

      // Failed headers to parse
      failedHeadersToParse: failedHeadersToParse,
    );
  }

  /// Convert headers to a map
  @override
  Map<String, Object> toMap() {
    var map = <String, Object>{};

    // Date-related headers
    var dateHeaders = _dateHeadersMap;
    for (var entry in dateHeaders.entries) {
      var key = entry.key;
      var value = entry.value;
      if (value != null) {
        map[key] = formatHttpDate(value);
      }
    }

    // Number-related headers
    var numberHeaders = _numberHeadersMap;
    for (var entry in numberHeaders.entries) {
      var key = entry.key;
      var value = entry.value;
      if (value != null) {
        map[key] = value;
      }
    }

    // String-related headers
    var stringHeaders = _stringHeadersMap;
    for (var entry in stringHeaders.entries) {
      var key = entry.key;
      var value = entry.value;
      if (value != null) {
        map[key] = value;
      }
    }

    // List<String>-related headers
    var listStringHeaders = _listStringHeadersMap;
    for (var entry in listStringHeaders.entries) {
      var key = entry.key;
      var value = entry.value;
      if (value != null) {
        map[key] = value;
      }
    }

    // Uri-related headers
    var uriHeaders = _uriHeadersMap;
    for (var entry in uriHeaders.entries) {
      var key = entry.key;
      var value = entry.value;
      if (value != null) {
        map[key] = value.toString();
      }
    }

    // TypedHeader-related headers
    var typedHeaders = _typedHeadersMap;
    for (var entry in typedHeaders.entries) {
      var key = entry.key;
      var value = entry.value;
      if (value != null) {
        map[key] = value.toHeaderString();
      }
    }

    // Custom headers
    for (var entry in custom.entries) {
      map[entry.key] = entry.value;
    }

    return map;
  }

  /// Date related headers
  Map<String, DateTime?> get _dateHeadersMap => {
        Headers.dateHeader: date ?? DateTime.now().toUtc(),
        Headers.expiresHeader: expires,
        Headers.ifModifiedSinceHeader: ifModifiedSince,
        Headers.lastModifiedHeader: lastModified,
      };

  /// Number-related headers
  Map<String, int?> get _numberHeadersMap => <String, int?>{
        Headers.ageHeader: age,
        Headers.maxForwardsHeader: maxForwards,
        Headers.accessControlMaxAgeHeader: accessControlMaxAge,
      };

  /// String-related headers
  Map<String, String?> get _stringHeadersMap => <String, String?>{
        Headers.serverHeader: server,
        Headers.userAgentHeader: userAgent,
        Headers.xPoweredByHeader: xPoweredBy,
        Headers.accessControlRequestMethodHeader:
            accessControlRequestMethod?.value,
      };

  /// String list related headers
  Map<String, List<String>?> get _listStringHeadersMap =>
      <String, List<String>?>{
        Headers.viaHeader: via,
        Headers.allowHeader: allow?.map((m) => m.value).toList(),
        Headers.accessControlRequestHeadersHeader: accessControlRequestHeaders,
        Headers.trailerHeader: trailer,
      };

  /// Uri related headers
  Map<String, Uri?> get _uriHeadersMap => <String, Uri?>{
        Headers.locationHeader: location,
        Headers.refererHeader: referer,
        Headers.contentLocationHeader: contentLocation,
        Headers.originHeader: origin,
        Headers.hostHeader: host,
      };

  /// TypedHeader related headers
  Map<String, TypedHeader?> get _typedHeadersMap => <String, TypedHeader?>{
        Headers.fromHeader: from,
        Headers.acceptEncodingHeader: acceptEncoding,
        Headers.acceptLanguageHeader: acceptLanguage,
        Headers.authorizationHeader: authorization,
        Headers.connectionHeader: connection,
        Headers.expectHeader: expect,
        Headers.ifMatchHeader: ifMatch,
        Headers.ifNoneMatchHeader: ifNoneMatch,
        Headers.ifRangeHeader: ifRange,
        Headers.proxyAuthorizationHeader: proxyAuthorization,
        Headers.rangeHeader: range,
        Headers.teHeader: te,
        Headers.upgradeHeader: upgrade,
        Headers.accessControlAllowOriginHeader: accessControlAllowOrigin,
        Headers.accessControlExposeHeadersHeader: accessControlExposeHeaders,
        Headers.cacheControlHeader: cacheControl,
        Headers.contentEncodingHeader: contentEncoding,
        Headers.contentLanguageHeader: contentLanguage,
        Headers.contentRangeHeader: contentRange,
        Headers.etagHeader: etag,
        Headers.proxyAuthenticationHeader: proxyAuthenticate,
        Headers.retryAfterHeader: retryAfter,
        Headers.transferEncodingHeader: transferEncoding,
        Headers.varyHeader: vary,
        Headers.wwwAuthenticateHeader: wwwAuthenticate,
        Headers.contentDispositionHeader: contentDisposition,
        Headers.cookieHeader: cookie,
        Headers.setCookieHeader: setCookie,
        Headers.strictTransportSecurityHeader: strictTransportSecurity,
        Headers.contentSecurityPolicyHeader: contentSecurityPolicy,
        Headers.referrerPolicyHeader: referrerPolicy,
        Headers.permissionsPolicyHeader: permissionsPolicy,
        Headers.accessControlAllowMethodsHeader: accessControlAllowMethods,
        Headers.accessControlAllowHeadersHeader: accessControlAllowHeaders,
        Headers.clearSiteDataHeader: clearSiteData,
        Headers.secFetchDestHeader: secFetchDest,
        Headers.secFetchModeHeader: secFetchMode,
        Headers.secFetchSiteHeader: secFetchSite,
        Headers.crossOriginResourcePolicyHeader: crossOriginResourcePolicy,
        Headers.crossOriginEmbedderPolicyHeader: crossOriginEmbedderPolicy,
        Headers.crossOriginOpenerPolicyHeader: crossOriginOpenerPolicy,
        Headers.acceptHeader: accept,
        Headers.acceptRangesHeader: acceptRanges,
      };
}

class _Undefined {}

typedef _LazyInitializer<T> = T Function();

class _LazyInit<T> {
  final _LazyInitializer<T>? _init;
  bool _isInitialized = false;
  T? _value;

  _LazyInit._({
    _LazyInitializer<T>? init,
    T? value,
    bool isInitialized = false,
  })  : _init = init,
        _value = value,
        _isInitialized = isInitialized;

  factory _LazyInit.value({
    required T value,
  }) {
    return _LazyInit._(
      value: value,
      isInitialized: true,
    );
  }

  factory _LazyInit.lazy({
    required _LazyInitializer<T> init,
  }) {
    return _LazyInit._(
      init: init,
      isInitialized: false,
    );
  }

  factory _LazyInit.nullValue() {
    return _LazyInit._(
      isInitialized: true,
    );
  }

  T? get value {
    if (!_isInitialized) {
      _value = _init?.call();
      _isInitialized = true;
    }
    return _value;
  }
}
