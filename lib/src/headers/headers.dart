import 'dart:collection';
import 'dart:io' as io; // TODO: Get rid of this dependency

import 'package:http_parser/http_parser.dart';
import 'package:relic/relic.dart';

import '../method/request_method.dart';
import 'codecs/common_types_codecs.dart';

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
  static const date = HeaderAccessor(Headers.dateHeader, dateTimeHeaderCodec);

  static const expires =
      HeaderAccessor(Headers.expiresHeader, dateTimeHeaderCodec);

  static const lastModified =
      HeaderAccessor(Headers.lastModifiedHeader, dateTimeHeaderCodec);

  static const ifModifiedSince =
      HeaderAccessor(Headers.ifModifiedSinceHeader, dateTimeHeaderCodec);

  static const ifUnmodifiedSince =
      HeaderAccessor(Headers.ifUnmodifiedSinceHeader, dateTimeHeaderCodec);

// General Headers
  static const origin = HeaderAccessor(Headers.originHeader, uriHeaderCodec);

  static const server = HeaderAccessor(Headers.serverHeader, stringHeaderCodec);

  static const via = HeaderAccessor(Headers.viaHeader, stringListCodec);

  /// Request Headers
  static const from = HeaderAccessor(Headers.fromHeader, FromHeader.codec);

  static const host = HeaderAccessor(Headers.hostHeader, uriHeaderCodec);

  static const acceptEncoding =
      HeaderAccessor(Headers.acceptEncodingHeader, AcceptEncodingHeader.codec);

  static const acceptLanguage =
      HeaderAccessor(Headers.acceptLanguageHeader, AcceptLanguageHeader.codec);

  static const accessControlRequestHeaders = HeaderAccessor(
      Headers.accessControlRequestHeadersHeader, stringListCodec);

  static const accessControlRequestMethod = HeaderAccessor(
      Headers.accessControlRequestMethodHeader, RequestMethod.codec);

  static const age = HeaderAccessor(
    Headers.ageHeader,
    positiveIntHeaderCodec,
  );

  static const authorization =
      HeaderAccessor(Headers.authorizationHeader, AuthorizationHeader.codec);

  static const connection =
      HeaderAccessor(Headers.connectionHeader, ConnectionHeader.codec);

  static const contentLength =
      HeaderAccessor(Headers.contentLengthHeader, intHeaderCodec);

  static const expect =
      HeaderAccessor(Headers.expectHeader, ExpectHeader.codec);

  static const ifMatch =
      HeaderAccessor(Headers.ifMatchHeader, IfMatchHeader.codec);

  static const ifNoneMatch =
      HeaderAccessor(Headers.ifNoneMatchHeader, IfNoneMatchHeader.codec);

  static const ifRange =
      HeaderAccessor(Headers.ifRangeHeader, IfRangeHeader.codec);

  static const maxForwards =
      HeaderAccessor(Headers.maxForwardsHeader, positiveIntHeaderCodec);

  static const proxyAuthorization = HeaderAccessor(
      Headers.proxyAuthorizationHeader, AuthorizationHeader.codec);

  static const range = HeaderAccessor(Headers.rangeHeader, RangeHeader.codec);

  static const referer = HeaderAccessor(Headers.refererHeader, uriHeaderCodec);

  static const userAgent =
      HeaderAccessor(Headers.userAgentHeader, stringHeaderCodec);

  static const te = HeaderAccessor(Headers.teHeader, TEHeader.codec);

  static const upgrade =
      HeaderAccessor(Headers.upgradeHeader, UpgradeHeader.codec);

  /// Response Headers

  static const location =
      HeaderAccessor(Headers.locationHeader, uriHeaderCodec);

  static const xPoweredBy =
      HeaderAccessor(Headers.xPoweredByHeader, stringHeaderCodec);

  static const accessControlAllowOrigin = HeaderAccessor(
      Headers.accessControlAllowOriginHeader,
      AccessControlAllowOriginHeader.codec);

  static const accessControlExposeHeaders = HeaderAccessor(
      Headers.accessControlExposeHeadersHeader,
      AccessControlExposeHeadersHeader.codec);

  static const accessControlMaxAge =
      HeaderAccessor(Headers.accessControlMaxAgeHeader, intHeaderCodec);

  static const allow = HeaderAccessor(
    Headers.allowHeader,
    HeaderCodec(parseMethodList, encodeMethodList),
  );

  static const cacheControl =
      HeaderAccessor(Headers.cacheControlHeader, CacheControlHeader.codec);

  static const contentEncoding = HeaderAccessor(
      Headers.contentEncodingHeader, ContentEncodingHeader.codec);

  static const contentLanguage = HeaderAccessor(
      Headers.contentLanguageHeader, ContentLanguageHeader.codec);

  static const contentLocation =
      HeaderAccessor(Headers.contentLocationHeader, uriHeaderCodec);

  static const contentRange =
      HeaderAccessor(Headers.contentRangeHeader, ContentRangeHeader.codec);

  static const etag = HeaderAccessor(Headers.etagHeader, ETagHeader.codec);

  static const proxyAuthenticate = HeaderAccessor(
      Headers.proxyAuthenticateHeader, AuthenticationHeader.codec);

  static const retryAfter =
      HeaderAccessor(Headers.retryAfterHeader, RetryAfterHeader.codec);

  static const trailer = HeaderAccessor(Headers.trailerHeader, stringListCodec);

  static const vary = HeaderAccessor(Headers.varyHeader, VaryHeader.codec);

  static const wwwAuthenticate =
      HeaderAccessor(Headers.wwwAuthenticateHeader, AuthenticationHeader.codec);

  static const contentDisposition = HeaderAccessor(
      Headers.contentDispositionHeader, ContentDispositionHeader.codec);

  /// Common Headers (Used in Both Requests and Responses)

  static const accept =
      HeaderAccessor(Headers.acceptHeader, AcceptHeader.codec);

  static const acceptRanges =
      HeaderAccessor(Headers.acceptRangesHeader, AcceptRangesHeader.codec);

  static const transferEncoding = HeaderAccessor(
      Headers.transferEncodingHeader, TransferEncodingHeader.codec);

  static const cookie =
      HeaderAccessor(Headers.cookieHeader, CookieHeader.codec);

  static const setCookie =
      HeaderAccessor(Headers.setCookieHeader, SetCookieHeader.codec);

  /// Security and Modern Headers

  static const strictTransportSecurity = HeaderAccessor(
      Headers.strictTransportSecurityHeader,
      StrictTransportSecurityHeader.codec);

  static const contentSecurityPolicy = HeaderAccessor(
      Headers.contentSecurityPolicyHeader, ContentSecurityPolicyHeader.codec);

  static const referrerPolicy =
      HeaderAccessor(Headers.referrerPolicyHeader, ReferrerPolicyHeader.codec);

  static const permissionsPolicy = HeaderAccessor(
      Headers.permissionsPolicyHeader, PermissionsPolicyHeader.codec);

  static const accessControlAllowCredentials = HeaderAccessor(
      Headers.accessControlAllowCredentialsHeader, positiveBoolHeaderCodec);

  static const accessControlAllowMethods = HeaderAccessor(
      Headers.accessControlAllowMethodsHeader,
      AccessControlAllowMethodsHeader.codec);

  static const accessControlAllowHeaders = HeaderAccessor(
      Headers.accessControlAllowHeadersHeader,
      AccessControlAllowHeadersHeader.codec);

  static const clearSiteData =
      HeaderAccessor(Headers.clearSiteDataHeader, ClearSiteDataHeader.codec);

  static const secFetchDest =
      HeaderAccessor(Headers.secFetchDestHeader, SecFetchDestHeader.codec);

  static const secFetchMode =
      HeaderAccessor(Headers.secFetchModeHeader, SecFetchModeHeader.codec);

  static const secFetchSite =
      HeaderAccessor(Headers.secFetchSiteHeader, SecFetchSiteHeader.codec);

  static const crossOriginResourcePolicy = HeaderAccessor(
      Headers.crossOriginResourcePolicyHeader,
      CrossOriginResourcePolicyHeader.codec);

  static const crossOriginEmbedderPolicy = HeaderAccessor(
      Headers.crossOriginEmbedderPolicyHeader,
      CrossOriginEmbedderPolicyHeader.codec);

  static const crossOriginOpenerPolicy = HeaderAccessor(
      Headers.crossOriginOpenerPolicyHeader,
      CrossOriginOpenerPolicyHeader.codec);

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
