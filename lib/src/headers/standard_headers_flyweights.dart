import 'package:relic/src/method/request_method.dart';

import 'header_flyweight.dart';
import 'headers.dart';
import 'parser/common_types_parser.dart';
import 'typed/typed_headers.dart';

/// Date-related headers
const date = HeaderFlyweight<DateTime>(
  Headers.dateHeader,
  HeaderDecoderSingle(parseDate),
);

const expires = HeaderFlyweight<DateTime>(
  Headers.expiresHeader,
  HeaderDecoderSingle(parseDate),
);

const lastModified = HeaderFlyweight<DateTime>(
  Headers.lastModifiedHeader,
  HeaderDecoderSingle(parseDate),
);

const ifModifiedSince = HeaderFlyweight<DateTime>(
  Headers.ifModifiedSinceHeader,
  HeaderDecoderSingle(parseDate),
);

const ifUnmodifiedSince = HeaderFlyweight<DateTime>(
  Headers.ifUnmodifiedSinceHeader,
  HeaderDecoderSingle(parseDate),
);

// General Headers
const origin = HeaderFlyweight<Uri>(
  Headers.originHeader,
  HeaderDecoderSingle(parseUri),
);

const server = HeaderFlyweight<String>(
  Headers.serverHeader,
  HeaderDecoderSingle(parseString),
);

const via = HeaderFlyweight<List<String>>(
  Headers.viaHeader,
  HeaderDecoderMulti(parseStringList),
);

/// Request Headers
const from = HeaderFlyweight<FromHeader>(
  Headers.fromHeader,
  HeaderDecoderMulti(FromHeader.parse),
);

const host = HeaderFlyweight<Uri>(
  Headers.hostHeader,
  HeaderDecoderSingle(parseUri),
);

const acceptEncoding = HeaderFlyweight<AcceptEncodingHeader>(
  Headers.acceptEncodingHeader,
  HeaderDecoderMulti(AcceptEncodingHeader.parse),
);

const acceptLanguage = HeaderFlyweight<AcceptLanguageHeader>(
  Headers.acceptLanguageHeader,
  HeaderDecoderMulti(AcceptLanguageHeader.parse),
);

const accessControlRequestHeaders = HeaderFlyweight<List<String>>(
  Headers.accessControlRequestHeadersHeader,
  HeaderDecoderMulti(parseStringList),
);

const accessControlRequestMethod = HeaderFlyweight<RequestMethod>(
  Headers.accessControlRequestMethodHeader,
  HeaderDecoderSingle(RequestMethod.parse),
);

const age = HeaderFlyweight<int>(
  Headers.ageHeader,
  HeaderDecoderSingle(parsePositiveInt),
);

const authorization = HeaderFlyweight<AuthorizationHeader>(
  Headers.authorizationHeader,
  HeaderDecoderSingle(AuthorizationHeader.parse),
);

const connection = HeaderFlyweight<ConnectionHeader>(
  Headers.connectionHeader,
  HeaderDecoderMulti(ConnectionHeader.parse),
);

const contentLength = HeaderFlyweight<int>(
  Headers.contentLengthHeader,
  HeaderDecoderSingle(parseInt),
);

const expect = HeaderFlyweight<ExpectHeader>(
  Headers.expectHeader,
  HeaderDecoderSingle(ExpectHeader.parse),
);

const ifMatch = HeaderFlyweight<IfMatchHeader>(
  Headers.ifMatchHeader,
  HeaderDecoderMulti(IfMatchHeader.parse),
);

const ifNoneMatch = HeaderFlyweight<IfNoneMatchHeader>(
  Headers.ifNoneMatchHeader,
  HeaderDecoderMulti(IfNoneMatchHeader.parse),
);

const ifRange = HeaderFlyweight<IfRangeHeader>(
  Headers.ifRangeHeader,
  HeaderDecoderSingle(IfRangeHeader.parse),
);

const maxForwards = HeaderFlyweight<int>(
  Headers.maxForwardsHeader,
  HeaderDecoderSingle(parsePositiveInt),
);

const proxyAuthorization = HeaderFlyweight<AuthorizationHeader>(
  Headers.proxyAuthorizationHeader,
  HeaderDecoderSingle(AuthorizationHeader.parse),
);

const range = HeaderFlyweight<RangeHeader>(
  Headers.rangeHeader,
  HeaderDecoderSingle(RangeHeader.parse),
);

const referer = HeaderFlyweight<Uri>(
  Headers.refererHeader,
  HeaderDecoderSingle(parseUri),
);

const userAgent = HeaderFlyweight<String>(
  Headers.userAgentHeader,
  HeaderDecoderSingle(parseString),
);

const te = HeaderFlyweight<TEHeader>(
  Headers.teHeader,
  HeaderDecoderMulti(TEHeader.parse),
);

const upgrade = HeaderFlyweight<UpgradeHeader>(
  Headers.upgradeHeader,
  HeaderDecoderMulti(UpgradeHeader.parse),
);

/// Response Headers

const location = HeaderFlyweight<Uri>(
  Headers.locationHeader,
  HeaderDecoderSingle(parseUri),
);

const xPoweredBy = HeaderFlyweight<String>(
  Headers.xPoweredByHeader,
  HeaderDecoderSingle(parseString),
);

const accessControlAllowOrigin =
    HeaderFlyweight<AccessControlAllowOriginHeader>(
  Headers.accessControlAllowOriginHeader,
  HeaderDecoderSingle(AccessControlAllowOriginHeader.parse),
);

const accessControlExposeHeaders =
    HeaderFlyweight<AccessControlExposeHeadersHeader>(
  Headers.accessControlExposeHeadersHeader,
  HeaderDecoderMulti(AccessControlExposeHeadersHeader.parse),
);

const accessControlMaxAge = HeaderFlyweight<int>(
  Headers.accessControlMaxAgeHeader,
  HeaderDecoderSingle(parseInt),
);

const allow = HeaderFlyweight<List<RequestMethod>>(
  Headers.allowHeader,
  HeaderDecoderMulti(parseMethodList),
);

const cacheControl = HeaderFlyweight<CacheControlHeader>(
  Headers.cacheControlHeader,
  HeaderDecoderMulti(CacheControlHeader.parse),
);

const contentEncoding = HeaderFlyweight<ContentEncodingHeader>(
  Headers.contentEncodingHeader,
  HeaderDecoderMulti(ContentEncodingHeader.parse),
);

const contentLanguage = HeaderFlyweight<ContentLanguageHeader>(
  Headers.contentLanguageHeader,
  HeaderDecoderMulti(ContentLanguageHeader.parse),
);

const contentLocation = HeaderFlyweight<Uri>(
  Headers.contentLocationHeader,
  HeaderDecoderSingle(parseUri),
);

const contentRange = HeaderFlyweight<ContentRangeHeader>(
  Headers.contentRangeHeader,
  HeaderDecoderSingle(ContentRangeHeader.parse),
);

const etag = HeaderFlyweight<ETagHeader>(
  Headers.etagHeader,
  HeaderDecoderSingle(ETagHeader.parse),
);

const proxyAuthenticate = HeaderFlyweight<AuthenticationHeader>(
  Headers.proxyAuthenticateHeader,
  HeaderDecoderSingle(AuthenticationHeader.parse),
);

const retryAfter = HeaderFlyweight<RetryAfterHeader>(
  Headers.retryAfterHeader,
  HeaderDecoderSingle(RetryAfterHeader.parse),
);

const trailer = HeaderFlyweight<List<String>>(
  Headers.trailerHeader,
  HeaderDecoderMulti(parseStringList),
);

const vary = HeaderFlyweight<VaryHeader>(
  Headers.varyHeader,
  HeaderDecoderMulti(VaryHeader.parse),
);

const wwwAuthenticate = HeaderFlyweight<AuthenticationHeader>(
  Headers.wwwAuthenticateHeader,
  HeaderDecoderSingle(AuthenticationHeader.parse),
);

const contentDisposition = HeaderFlyweight<ContentDispositionHeader>(
  Headers.contentDispositionHeader,
  HeaderDecoderSingle(ContentDispositionHeader.parse),
);

/// Common Headers (Used in Both Requests and Responses)

const accept = HeaderFlyweight<AcceptHeader>(
  Headers.acceptHeader,
  HeaderDecoderMulti(AcceptHeader.parse),
);

const acceptRanges = HeaderFlyweight<AcceptRangesHeader>(
  Headers.acceptRangesHeader,
  HeaderDecoderSingle(AcceptRangesHeader.parse),
);

const transferEncoding = HeaderFlyweight<TransferEncodingHeader>(
  Headers.transferEncodingHeader,
  HeaderDecoderMulti(TransferEncodingHeader.parse),
);

const cookie = HeaderFlyweight<CookieHeader>(
  Headers.cookieHeader,
  HeaderDecoderSingle(CookieHeader.parse),
);

const setCookie = HeaderFlyweight<SetCookieHeader>(
  Headers.setCookieHeader,
  HeaderDecoderSingle(SetCookieHeader.parse),
);

/// Security and Modern Headers

const strictTransportSecurity = HeaderFlyweight<StrictTransportSecurityHeader>(
  Headers.strictTransportSecurityHeader,
  HeaderDecoderSingle(StrictTransportSecurityHeader.parse),
);

const contentSecurityPolicy = HeaderFlyweight<ContentSecurityPolicyHeader>(
  Headers.contentSecurityPolicyHeader,
  HeaderDecoderSingle(ContentSecurityPolicyHeader.parse),
);

const referrerPolicy = HeaderFlyweight<ReferrerPolicyHeader>(
  Headers.referrerPolicyHeader,
  HeaderDecoderSingle(ReferrerPolicyHeader.parse),
);

const permissionsPolicy = HeaderFlyweight<PermissionsPolicyHeader>(
  Headers.permissionsPolicyHeader,
  HeaderDecoderSingle(PermissionsPolicyHeader.parse),
);

const accessControlAllowCredentials = HeaderFlyweight<bool>(
  Headers.accessControlAllowCredentialsHeader,
  HeaderDecoderSingle(parsePositiveBool),
);

const accessControlAllowMethods =
    HeaderFlyweight<AccessControlAllowMethodsHeader>(
  Headers.accessControlAllowMethodsHeader,
  HeaderDecoderMulti(AccessControlAllowMethodsHeader.parse),
);

const accessControlAllowHeaders =
    HeaderFlyweight<AccessControlAllowHeadersHeader>(
  Headers.accessControlAllowHeadersHeader,
  HeaderDecoderMulti(AccessControlAllowHeadersHeader.parse),
);

const clearSiteData = HeaderFlyweight<ClearSiteDataHeader>(
  Headers.clearSiteDataHeader,
  HeaderDecoderMulti(ClearSiteDataHeader.parse),
);

const secFetchDest = HeaderFlyweight<SecFetchDestHeader>(
  Headers.secFetchDestHeader,
  HeaderDecoderSingle(SecFetchDestHeader.parse),
);

const secFetchMode = HeaderFlyweight<SecFetchModeHeader>(
  Headers.secFetchModeHeader,
  HeaderDecoderSingle(SecFetchModeHeader.parse),
);

const secFetchSite = HeaderFlyweight<SecFetchSiteHeader>(
  Headers.secFetchSiteHeader,
  HeaderDecoderSingle(SecFetchSiteHeader.parse),
);

const crossOriginResourcePolicy =
    HeaderFlyweight<CrossOriginResourcePolicyHeader>(
  Headers.crossOriginResourcePolicyHeader,
  HeaderDecoderSingle(CrossOriginResourcePolicyHeader.parse),
);

const crossOriginEmbedderPolicy =
    HeaderFlyweight<CrossOriginEmbedderPolicyHeader>(
  Headers.crossOriginEmbedderPolicyHeader,
  HeaderDecoderSingle(CrossOriginEmbedderPolicyHeader.parse),
);

const crossOriginOpenerPolicy = HeaderFlyweight<CrossOriginOpenerPolicyHeader>(
  Headers.crossOriginOpenerPolicyHeader,
  HeaderDecoderSingle(CrossOriginOpenerPolicyHeader.parse),
);
