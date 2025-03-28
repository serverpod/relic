import 'dart:collection';
import 'dart:io' as io; // TODO: Get rid of this dependen

import 'package:http_parser/http_parser.dart';
import 'package:relic/relic.dart';

import '../method/request_method.dart';
import 'parser/common_types_parser.dart';

part 'mutable_headers.dart';

typedef _BackingStore = CaseInsensitiveMap<Iterable<String>>;

class HeadersBase extends UnmodifiableMapView<String, Iterable<String>> {
  final _BackingStore _backing;
  HeadersBase._(this._backing) : super(_backing);
}

/// [Headers] is a case-insensitive, unmodifiable map that stores headers
class Headers extends HeadersBase {
  factory Headers.fromMap(Map<String, Iterable<String>>? values) {
    if (values == null || values.isEmpty) {
      return _emptyHeaders;
    } else if (values is Headers) {
      return values;
    } else {
      return Headers._fromEntries(values.entries);
    }
  }

  factory Headers.empty() => _emptyHeaders;

  factory Headers.build(void Function(MutableHeaders) update) =>
      Headers.empty().transform(update);

  // cannot be made const before: <insert link to dart CL
  Headers._empty() : this._fromEntries(const {});

  Headers._fromEntries(Iterable<MapEntry<String, Iterable<String>>> entries)
      : this._(CaseInsensitiveMap.from(Map.fromEntries(
          entries
              .where((e) => e.value.isNotEmpty)
              .map((e) => MapEntry(e.key, List.unmodifiable(e.value))),
        )));

  Headers._(super.backing) : super._();

  Headers transform(void Function(MutableHeaders) update) {
    final mutable = MutableHeaders._from(this);
    update(mutable);
    return mutable._freeze();
  }

  // TODO: Should die
  factory Headers.fromHttpRequest(
    io.HttpRequest request, {
    bool strict = false,
    required String? xPoweredBy,
    DateTime? date,
  }) {
    return Headers.build((mh) {
      request.headers.forEach((k, v) => mh[k] = v);
    });
  }

  /// Date-related headers
  static const date = HeaderFlyweight<DateTime>(
    Headers.dateHeader,
    HeaderDecoderSingle(parseDate),
  );

  static const expires = HeaderFlyweight<DateTime>(
    Headers.expiresHeader,
    HeaderDecoderSingle(parseDate),
  );

  static const lastModified = HeaderFlyweight<DateTime>(
    Headers.lastModifiedHeader,
    HeaderDecoderSingle(parseDate),
  );

  static const ifModifiedSince = HeaderFlyweight<DateTime>(
    Headers.ifModifiedSinceHeader,
    HeaderDecoderSingle(parseDate),
  );

  static const ifUnmodifiedSince = HeaderFlyweight<DateTime>(
    Headers.ifUnmodifiedSinceHeader,
    HeaderDecoderSingle(parseDate),
  );

// General Headers
  static const origin = HeaderFlyweight<Uri>(
    Headers.originHeader,
    HeaderDecoderSingle(parseUri),
  );

  static const server = HeaderFlyweight<String>(
    Headers.serverHeader,
    HeaderDecoderSingle(parseString),
  );

  static const via = HeaderFlyweight<List<String>>(
    Headers.viaHeader,
    HeaderDecoderMulti(parseStringList),
  );

  /// Request Headers
  static const from = HeaderFlyweight<FromHeader>(
    Headers.fromHeader,
    HeaderDecoderMulti(FromHeader.parse),
  );

  static const host = HeaderFlyweight<Uri>(
    Headers.hostHeader,
    HeaderDecoderSingle(parseUri),
  );

  static const acceptEncoding = HeaderFlyweight<AcceptEncodingHeader>(
    Headers.acceptEncodingHeader,
    HeaderDecoderMulti(AcceptEncodingHeader.parse),
  );

  static const acceptLanguage = HeaderFlyweight<AcceptLanguageHeader>(
    Headers.acceptLanguageHeader,
    HeaderDecoderMulti(AcceptLanguageHeader.parse),
  );

  static const accessControlRequestHeaders = HeaderFlyweight<List<String>>(
    Headers.accessControlRequestHeadersHeader,
    HeaderDecoderMulti(parseStringList),
  );

  static const accessControlRequestMethod = HeaderFlyweight<RequestMethod>(
    Headers.accessControlRequestMethodHeader,
    HeaderDecoderSingle(RequestMethod.parse),
  );

  static const age = HeaderFlyweight<int>(
    Headers.ageHeader,
    HeaderDecoderSingle(parsePositiveInt),
  );

  static const authorization = HeaderFlyweight<AuthorizationHeader>(
    Headers.authorizationHeader,
    HeaderDecoderSingle(AuthorizationHeader.parse),
  );

  static const connection = HeaderFlyweight<ConnectionHeader>(
    Headers.connectionHeader,
    HeaderDecoderMulti(ConnectionHeader.parse),
  );

  static const contentLength = HeaderFlyweight<int>(
    Headers.contentLengthHeader,
    HeaderDecoderSingle(parseInt),
  );

  static const expect = HeaderFlyweight<ExpectHeader>(
    Headers.expectHeader,
    HeaderDecoderSingle(ExpectHeader.parse),
  );

  static const ifMatch = HeaderFlyweight<IfMatchHeader>(
    Headers.ifMatchHeader,
    HeaderDecoderMulti(IfMatchHeader.parse),
  );

  static const ifNoneMatch = HeaderFlyweight<IfNoneMatchHeader>(
    Headers.ifNoneMatchHeader,
    HeaderDecoderMulti(IfNoneMatchHeader.parse),
  );

  static const ifRange = HeaderFlyweight<IfRangeHeader>(
    Headers.ifRangeHeader,
    HeaderDecoderSingle(IfRangeHeader.parse),
  );

  static const maxForwards = HeaderFlyweight<int>(
    Headers.maxForwardsHeader,
    HeaderDecoderSingle(parsePositiveInt),
  );

  static const proxyAuthorization = HeaderFlyweight<AuthorizationHeader>(
    Headers.proxyAuthorizationHeader,
    HeaderDecoderSingle(AuthorizationHeader.parse),
  );

  static const range = HeaderFlyweight<RangeHeader>(
    Headers.rangeHeader,
    HeaderDecoderSingle(RangeHeader.parse),
  );

  static const referer = HeaderFlyweight<Uri>(
    Headers.refererHeader,
    HeaderDecoderSingle(parseUri),
  );

  static const userAgent = HeaderFlyweight<String>(
    Headers.userAgentHeader,
    HeaderDecoderSingle(parseString),
  );

  static const te = HeaderFlyweight<TEHeader>(
    Headers.teHeader,
    HeaderDecoderMulti(TEHeader.parse),
  );

  static const upgrade = HeaderFlyweight<UpgradeHeader>(
    Headers.upgradeHeader,
    HeaderDecoderMulti(UpgradeHeader.parse),
  );

  /// Response Headers

  static const location = HeaderFlyweight<Uri>(
    Headers.locationHeader,
    HeaderDecoderSingle(parseUri),
  );

  static const xPoweredBy = HeaderFlyweight<String>(
    Headers.xPoweredByHeader,
    HeaderDecoderSingle(parseString),
  );

  static const accessControlAllowOrigin =
      HeaderFlyweight<AccessControlAllowOriginHeader>(
    Headers.accessControlAllowOriginHeader,
    HeaderDecoderSingle(AccessControlAllowOriginHeader.parse),
  );

  static const accessControlExposeHeaders =
      HeaderFlyweight<AccessControlExposeHeadersHeader>(
    Headers.accessControlExposeHeadersHeader,
    HeaderDecoderMulti(AccessControlExposeHeadersHeader.parse),
  );

  static const accessControlMaxAge = HeaderFlyweight<int>(
    Headers.accessControlMaxAgeHeader,
    HeaderDecoderSingle(parseInt),
  );

  static const allow = HeaderFlyweight<List<RequestMethod>>(
    Headers.allowHeader,
    HeaderDecoderMulti(parseMethodList),
  );

  static const cacheControl = HeaderFlyweight<CacheControlHeader>(
    Headers.cacheControlHeader,
    HeaderDecoderMulti(CacheControlHeader.parse),
  );

  static const contentEncoding = HeaderFlyweight<ContentEncodingHeader>(
    Headers.contentEncodingHeader,
    HeaderDecoderMulti(ContentEncodingHeader.parse),
  );

  static const contentLanguage = HeaderFlyweight<ContentLanguageHeader>(
    Headers.contentLanguageHeader,
    HeaderDecoderMulti(ContentLanguageHeader.parse),
  );

  static const contentLocation = HeaderFlyweight<Uri>(
    Headers.contentLocationHeader,
    HeaderDecoderSingle(parseUri),
  );

  static const contentRange = HeaderFlyweight<ContentRangeHeader>(
    Headers.contentRangeHeader,
    HeaderDecoderSingle(ContentRangeHeader.parse),
  );

  static const etag = HeaderFlyweight<ETagHeader>(
    Headers.etagHeader,
    HeaderDecoderSingle(ETagHeader.parse),
  );

  static const proxyAuthenticate = HeaderFlyweight<AuthenticationHeader>(
    Headers.proxyAuthenticateHeader,
    HeaderDecoderSingle(AuthenticationHeader.parse),
  );

  static const retryAfter = HeaderFlyweight<RetryAfterHeader>(
    Headers.retryAfterHeader,
    HeaderDecoderSingle(RetryAfterHeader.parse),
  );

  static const trailer = HeaderFlyweight<List<String>>(
    Headers.trailerHeader,
    HeaderDecoderMulti(parseStringList),
  );

  static const vary = HeaderFlyweight<VaryHeader>(
    Headers.varyHeader,
    HeaderDecoderMulti(VaryHeader.parse),
  );

  static const wwwAuthenticate = HeaderFlyweight<AuthenticationHeader>(
    Headers.wwwAuthenticateHeader,
    HeaderDecoderSingle(AuthenticationHeader.parse),
  );

  static const contentDisposition = HeaderFlyweight<ContentDispositionHeader>(
    Headers.contentDispositionHeader,
    HeaderDecoderSingle(ContentDispositionHeader.parse),
  );

  /// Common Headers (Used in Both Requests and Responses)

  static const accept = HeaderFlyweight<AcceptHeader>(
    Headers.acceptHeader,
    HeaderDecoderMulti(AcceptHeader.parse),
  );

  static const acceptRanges = HeaderFlyweight<AcceptRangesHeader>(
    Headers.acceptRangesHeader,
    HeaderDecoderSingle(AcceptRangesHeader.parse),
  );

  static const transferEncoding = HeaderFlyweight<TransferEncodingHeader>(
    Headers.transferEncodingHeader,
    HeaderDecoderMulti(TransferEncodingHeader.parse),
  );

  static const cookie = HeaderFlyweight<CookieHeader>(
    Headers.cookieHeader,
    HeaderDecoderSingle(CookieHeader.parse),
  );

  static const setCookie = HeaderFlyweight<SetCookieHeader>(
    Headers.setCookieHeader,
    HeaderDecoderSingle(SetCookieHeader.parse),
  );

  /// Security and Modern Headers

  static const strictTransportSecurity =
      HeaderFlyweight<StrictTransportSecurityHeader>(
    Headers.strictTransportSecurityHeader,
    HeaderDecoderSingle(StrictTransportSecurityHeader.parse),
  );

  static const contentSecurityPolicy =
      HeaderFlyweight<ContentSecurityPolicyHeader>(
    Headers.contentSecurityPolicyHeader,
    HeaderDecoderSingle(ContentSecurityPolicyHeader.parse),
  );

  static const referrerPolicy = HeaderFlyweight<ReferrerPolicyHeader>(
    Headers.referrerPolicyHeader,
    HeaderDecoderSingle(ReferrerPolicyHeader.parse),
  );

  static const permissionsPolicy = HeaderFlyweight<PermissionsPolicyHeader>(
    Headers.permissionsPolicyHeader,
    HeaderDecoderSingle(PermissionsPolicyHeader.parse),
  );

  static const accessControlAllowCredentials = HeaderFlyweight<bool>(
    Headers.accessControlAllowCredentialsHeader,
    HeaderDecoderSingle(parsePositiveBool),
  );

  static const accessControlAllowMethods =
      HeaderFlyweight<AccessControlAllowMethodsHeader>(
    Headers.accessControlAllowMethodsHeader,
    HeaderDecoderMulti(AccessControlAllowMethodsHeader.parse),
  );

  static const accessControlAllowHeaders =
      HeaderFlyweight<AccessControlAllowHeadersHeader>(
    Headers.accessControlAllowHeadersHeader,
    HeaderDecoderMulti(AccessControlAllowHeadersHeader.parse),
  );

  static const clearSiteData = HeaderFlyweight<ClearSiteDataHeader>(
    Headers.clearSiteDataHeader,
    HeaderDecoderMulti(ClearSiteDataHeader.parse),
  );

  static const secFetchDest = HeaderFlyweight<SecFetchDestHeader>(
    Headers.secFetchDestHeader,
    HeaderDecoderSingle(SecFetchDestHeader.parse),
  );

  static const secFetchMode = HeaderFlyweight<SecFetchModeHeader>(
    Headers.secFetchModeHeader,
    HeaderDecoderSingle(SecFetchModeHeader.parse),
  );

  static const secFetchSite = HeaderFlyweight<SecFetchSiteHeader>(
    Headers.secFetchSiteHeader,
    HeaderDecoderSingle(SecFetchSiteHeader.parse),
  );

  static const crossOriginResourcePolicy =
      HeaderFlyweight<CrossOriginResourcePolicyHeader>(
    Headers.crossOriginResourcePolicyHeader,
    HeaderDecoderSingle(CrossOriginResourcePolicyHeader.parse),
  );

  static const crossOriginEmbedderPolicy =
      HeaderFlyweight<CrossOriginEmbedderPolicyHeader>(
    Headers.crossOriginEmbedderPolicyHeader,
    HeaderDecoderSingle(CrossOriginEmbedderPolicyHeader.parse),
  );

  static const crossOriginOpenerPolicy =
      HeaderFlyweight<CrossOriginOpenerPolicyHeader>(
    Headers.crossOriginOpenerPolicyHeader,
    HeaderDecoderSingle(CrossOriginOpenerPolicyHeader.parse),
  );

  static const _common = {
    cacheControl,
    connection,
    contentDisposition,
    contentEncoding,
    contentLanguage,
    contentLength,
    contentLocation,
    // contentType, // Huh?
    date,
    referrerPolicy,
    trailer,
    transferEncoding,
    upgrade,
    via,
  };

  static const _requestOnly = {
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
  };

  static const _responseOnly = {
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

  static const response = {..._common, ..._requestOnly};
  static const request = {..._common, ..._responseOnly};
  static const all = {..._common, ..._requestOnly, ..._responseOnly};

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
  static const proxyAuthenticateHeader = "proxy-authenticate";
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
}

final _emptyHeaders = Headers._empty();
