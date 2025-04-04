import 'dart:collection';
import 'dart:io' as io; // TODO: Get rid of this dependency

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

  // TODO: Move this functionality out of Headers so that we can avoid the dart:io dependency
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
  static const date = HeaderAccessor<DateTime>(
    Headers.dateHeader,
    HeaderCodec.single(parseDate),
  );

  static const expires = HeaderAccessor<DateTime>(
    Headers.expiresHeader,
    HeaderCodec.single(parseDate),
  );

  static const lastModified = HeaderAccessor<DateTime>(
    Headers.lastModifiedHeader,
    HeaderCodec.single(parseDate),
  );

  static const ifModifiedSince = HeaderAccessor<DateTime>(
    Headers.ifModifiedSinceHeader,
    HeaderCodec.single(parseDate),
  );

  static const ifUnmodifiedSince = HeaderAccessor<DateTime>(
    Headers.ifUnmodifiedSinceHeader,
    HeaderCodec.single(parseDate),
  );

// General Headers
  static const origin = HeaderAccessor<Uri>(
    Headers.originHeader,
    HeaderCodec.single(parseUri),
  );

  static const server = HeaderAccessor<String>(
    Headers.serverHeader,
    HeaderCodec.single(parseString),
  );

  static const via = HeaderAccessor<List<String>>(
    Headers.viaHeader,
    HeaderCodec(parseStringList),
  );

  /// Request Headers
  static const from = HeaderAccessor<FromHeader>(
    Headers.fromHeader,
    HeaderCodec(FromHeader.parse),
  );

  static const host = HeaderAccessor<Uri>(
    Headers.hostHeader,
    HeaderCodec.single(parseUri),
  );

  static const acceptEncoding = HeaderAccessor<AcceptEncodingHeader>(
    Headers.acceptEncodingHeader,
    HeaderCodec(AcceptEncodingHeader.parse),
  );

  static const acceptLanguage = HeaderAccessor<AcceptLanguageHeader>(
    Headers.acceptLanguageHeader,
    HeaderCodec(AcceptLanguageHeader.parse),
  );

  static const accessControlRequestHeaders = HeaderAccessor<List<String>>(
    Headers.accessControlRequestHeadersHeader,
    HeaderCodec(parseStringList),
  );

  static const accessControlRequestMethod = HeaderAccessor<RequestMethod>(
    Headers.accessControlRequestMethodHeader,
    HeaderCodec.single(RequestMethod.parse),
  );

  static const age = HeaderAccessor<int>(
    Headers.ageHeader,
    HeaderCodec.single(parsePositiveInt),
  );

  static const authorization = HeaderAccessor<AuthorizationHeader>(
    Headers.authorizationHeader,
    HeaderCodec.single(AuthorizationHeader.parse),
  );

  static const connection = HeaderAccessor<ConnectionHeader>(
    Headers.connectionHeader,
    HeaderCodec(ConnectionHeader.parse),
  );

  static const contentLength = HeaderAccessor<int>(
    Headers.contentLengthHeader,
    HeaderCodec.single(parseInt),
  );

  static const expect = HeaderAccessor<ExpectHeader>(
    Headers.expectHeader,
    HeaderCodec.single(ExpectHeader.parse),
  );

  static const ifMatch = HeaderAccessor<IfMatchHeader>(
    Headers.ifMatchHeader,
    HeaderCodec(IfMatchHeader.parse),
  );

  static const ifNoneMatch = HeaderAccessor<IfNoneMatchHeader>(
    Headers.ifNoneMatchHeader,
    HeaderCodec(IfNoneMatchHeader.parse),
  );

  static const ifRange = HeaderAccessor<IfRangeHeader>(
    Headers.ifRangeHeader,
    HeaderCodec.single(IfRangeHeader.parse),
  );

  static const maxForwards = HeaderAccessor<int>(
    Headers.maxForwardsHeader,
    HeaderCodec.single(parsePositiveInt),
  );

  static const proxyAuthorization = HeaderAccessor<AuthorizationHeader>(
    Headers.proxyAuthorizationHeader,
    HeaderCodec.single(AuthorizationHeader.parse),
  );

  static const range = HeaderAccessor<RangeHeader>(
    Headers.rangeHeader,
    HeaderCodec.single(RangeHeader.parse),
  );

  static const referer = HeaderAccessor<Uri>(
    Headers.refererHeader,
    HeaderCodec.single(parseUri),
  );

  static const userAgent = HeaderAccessor<String>(
    Headers.userAgentHeader,
    HeaderCodec.single(parseString),
  );

  static const te = HeaderAccessor<TEHeader>(
    Headers.teHeader,
    HeaderCodec(TEHeader.parse),
  );

  static const upgrade = HeaderAccessor<UpgradeHeader>(
    Headers.upgradeHeader,
    HeaderCodec(UpgradeHeader.parse),
  );

  /// Response Headers

  static const location = HeaderAccessor<Uri>(
    Headers.locationHeader,
    HeaderCodec.single(parseUri),
  );

  static const xPoweredBy = HeaderAccessor<String>(
    Headers.xPoweredByHeader,
    HeaderCodec.single(parseString),
  );

  static const accessControlAllowOrigin =
      HeaderAccessor<AccessControlAllowOriginHeader>(
    Headers.accessControlAllowOriginHeader,
    HeaderCodec.single(AccessControlAllowOriginHeader.parse),
  );

  static const accessControlExposeHeaders =
      HeaderAccessor<AccessControlExposeHeadersHeader>(
    Headers.accessControlExposeHeadersHeader,
    HeaderCodec(AccessControlExposeHeadersHeader.parse),
  );

  static const accessControlMaxAge = HeaderAccessor<int>(
    Headers.accessControlMaxAgeHeader,
    HeaderCodec.single(parseInt),
  );

  static const allow = HeaderAccessor<List<RequestMethod>>(
    Headers.allowHeader,
    HeaderCodec(parseMethodList),
  );

  static const cacheControl = HeaderAccessor<CacheControlHeader>(
    Headers.cacheControlHeader,
    HeaderCodec(CacheControlHeader.parse),
  );

  static const contentEncoding = HeaderAccessor<ContentEncodingHeader>(
    Headers.contentEncodingHeader,
    HeaderCodec(ContentEncodingHeader.parse),
  );

  static const contentLanguage = HeaderAccessor<ContentLanguageHeader>(
    Headers.contentLanguageHeader,
    HeaderCodec(ContentLanguageHeader.parse),
  );

  static const contentLocation = HeaderAccessor<Uri>(
    Headers.contentLocationHeader,
    HeaderCodec.single(parseUri),
  );

  static const contentRange = HeaderAccessor<ContentRangeHeader>(
    Headers.contentRangeHeader,
    HeaderCodec.single(ContentRangeHeader.parse),
  );

  static const etag = HeaderAccessor<ETagHeader>(
    Headers.etagHeader,
    HeaderCodec.single(ETagHeader.parse),
  );

  static const proxyAuthenticate = HeaderAccessor<AuthenticationHeader>(
    Headers.proxyAuthenticateHeader,
    HeaderCodec.single(AuthenticationHeader.parse),
  );

  static const retryAfter = HeaderAccessor<RetryAfterHeader>(
    Headers.retryAfterHeader,
    HeaderCodec.single(RetryAfterHeader.parse),
  );

  static const trailer = HeaderAccessor<List<String>>(
    Headers.trailerHeader,
    HeaderCodec(parseStringList),
  );

  static const vary = HeaderAccessor<VaryHeader>(
    Headers.varyHeader,
    HeaderCodec(VaryHeader.parse),
  );

  static const wwwAuthenticate = HeaderAccessor<AuthenticationHeader>(
    Headers.wwwAuthenticateHeader,
    HeaderCodec.single(AuthenticationHeader.parse),
  );

  static const contentDisposition = HeaderAccessor<ContentDispositionHeader>(
    Headers.contentDispositionHeader,
    HeaderCodec.single(ContentDispositionHeader.parse),
  );

  /// Common Headers (Used in Both Requests and Responses)

  static const accept = HeaderAccessor<AcceptHeader>(
    Headers.acceptHeader,
    HeaderCodec(AcceptHeader.parse),
  );

  static const acceptRanges = HeaderAccessor<AcceptRangesHeader>(
    Headers.acceptRangesHeader,
    HeaderCodec.single(AcceptRangesHeader.parse),
  );

  static const transferEncoding = HeaderAccessor<TransferEncodingHeader>(
    Headers.transferEncodingHeader,
    HeaderCodec(TransferEncodingHeader.parse),
  );

  static const cookie = HeaderAccessor<CookieHeader>(
    Headers.cookieHeader,
    HeaderCodec.single(CookieHeader.parse),
  );

  static const setCookie = HeaderAccessor<SetCookieHeader>(
    Headers.setCookieHeader,
    HeaderCodec.single(SetCookieHeader.parse),
  );

  /// Security and Modern Headers

  static const strictTransportSecurity =
      HeaderAccessor<StrictTransportSecurityHeader>(
    Headers.strictTransportSecurityHeader,
    HeaderCodec.single(StrictTransportSecurityHeader.parse),
  );

  static const contentSecurityPolicy =
      HeaderAccessor<ContentSecurityPolicyHeader>(
    Headers.contentSecurityPolicyHeader,
    HeaderCodec.single(ContentSecurityPolicyHeader.parse),
  );

  static const referrerPolicy = HeaderAccessor<ReferrerPolicyHeader>(
    Headers.referrerPolicyHeader,
    HeaderCodec.single(ReferrerPolicyHeader.parse),
  );

  static const permissionsPolicy = HeaderAccessor<PermissionsPolicyHeader>(
    Headers.permissionsPolicyHeader,
    HeaderCodec.single(PermissionsPolicyHeader.parse),
  );

  static const accessControlAllowCredentials = HeaderAccessor<bool>(
    Headers.accessControlAllowCredentialsHeader,
    HeaderCodec.single(parsePositiveBool),
  );

  static const accessControlAllowMethods =
      HeaderAccessor<AccessControlAllowMethodsHeader>(
    Headers.accessControlAllowMethodsHeader,
    HeaderCodec(AccessControlAllowMethodsHeader.parse),
  );

  static const accessControlAllowHeaders =
      HeaderAccessor<AccessControlAllowHeadersHeader>(
    Headers.accessControlAllowHeadersHeader,
    HeaderCodec(AccessControlAllowHeadersHeader.parse),
  );

  static const clearSiteData = HeaderAccessor<ClearSiteDataHeader>(
    Headers.clearSiteDataHeader,
    HeaderCodec(ClearSiteDataHeader.parse),
  );

  static const secFetchDest = HeaderAccessor<SecFetchDestHeader>(
    Headers.secFetchDestHeader,
    HeaderCodec.single(SecFetchDestHeader.parse),
  );

  static const secFetchMode = HeaderAccessor<SecFetchModeHeader>(
    Headers.secFetchModeHeader,
    HeaderCodec.single(SecFetchModeHeader.parse),
  );

  static const secFetchSite = HeaderAccessor<SecFetchSiteHeader>(
    Headers.secFetchSiteHeader,
    HeaderCodec.single(SecFetchSiteHeader.parse),
  );

  static const crossOriginResourcePolicy =
      HeaderAccessor<CrossOriginResourcePolicyHeader>(
    Headers.crossOriginResourcePolicyHeader,
    HeaderCodec.single(CrossOriginResourcePolicyHeader.parse),
  );

  static const crossOriginEmbedderPolicy =
      HeaderAccessor<CrossOriginEmbedderPolicyHeader>(
    Headers.crossOriginEmbedderPolicyHeader,
    HeaderCodec.single(CrossOriginEmbedderPolicyHeader.parse),
  );

  static const crossOriginOpenerPolicy =
      HeaderAccessor<CrossOriginOpenerPolicyHeader>(
    Headers.crossOriginOpenerPolicyHeader,
    HeaderCodec.single(CrossOriginOpenerPolicyHeader.parse),
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
