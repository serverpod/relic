import '../method/request_method.dart';
import 'headers.dart';
import 'typed/typed_headers.dart';

extension HeadersEx on Headers {
  DateTime? get date => Headers.date[this]();
  DateTime? get expires => Headers.expires[this]();
  DateTime? get lastModified => Headers.lastModified[this]();
  DateTime? get ifModifiedSince => Headers.ifModifiedSince[this]();
  DateTime? get ifUnmodifiedSince => Headers.ifUnmodifiedSince[this]();
  Uri? get origin => Headers.origin[this]();
  String? get server => Headers.server[this]();
  List<String>? get via => Headers.via[this]();
  FromHeader? get from => Headers.from[this]();
  HostHeader? get host => Headers.host[this]();
  AcceptEncodingHeader? get acceptEncoding => Headers.acceptEncoding[this]();
  AcceptLanguageHeader? get acceptLanguage => Headers.acceptLanguage[this]();
  List<String>? get accessControlRequestHeaders =>
      Headers.accessControlRequestHeaders[this]();
  RequestMethod? get accessControlRequestMethod =>
      Headers.accessControlRequestMethod[this]();
  int? get age => Headers.age[this]();
  AuthorizationHeader? get authorization => Headers.authorization[this]();
  ConnectionHeader? get connection => Headers.connection[this]();
  int? get contentLength => Headers.contentLength[this]();
  ExpectHeader? get expect => Headers.expect[this]();
  IfMatchHeader? get ifMatch => Headers.ifMatch[this]();
  IfNoneMatchHeader? get ifNoneMatch => Headers.ifNoneMatch[this]();
  IfRangeHeader? get ifRange => Headers.ifRange[this]();
  int? get maxForwards => Headers.maxForwards[this]();
  AuthorizationHeader? get proxyAuthorization =>
      Headers.proxyAuthorization[this]();
  RangeHeader? get range => Headers.range[this]();
  Uri? get referer => Headers.referer[this]();
  String? get userAgent => Headers.userAgent[this]();
  TEHeader? get te => Headers.te[this]();
  UpgradeHeader? get upgrade => Headers.upgrade[this]();
  Uri? get location => Headers.location[this]();
  String? get xPoweredBy => Headers.xPoweredBy[this]();
  AccessControlAllowOriginHeader? get accessControlAllowOrigin =>
      Headers.accessControlAllowOrigin[this]();
  AccessControlExposeHeadersHeader? get accessControlExposeHeaders =>
      Headers.accessControlExposeHeaders[this]();
  int? get accessControlMaxAge => Headers.accessControlMaxAge[this]();
  List<RequestMethod>? get allow => Headers.allow[this]();
  CacheControlHeader? get cacheControl => Headers.cacheControl[this]();
  ContentEncodingHeader? get contentEncoding => Headers.contentEncoding[this]();
  ContentLanguageHeader? get contentLanguage => Headers.contentLanguage[this]();
  Uri? get contentLocation => Headers.contentLocation[this]();
  ContentRangeHeader? get contentRange => Headers.contentRange[this]();
  ETagHeader? get etag => Headers.etag[this]();
  AuthenticationHeader? get proxyAuthenticate =>
      Headers.proxyAuthenticate[this]();
  RetryAfterHeader? get retryAfter => Headers.retryAfter[this]();
  List<String>? get trailer => Headers.trailer[this]();
  VaryHeader? get vary => Headers.vary[this]();
  AuthenticationHeader? get wwwAuthenticate => Headers.wwwAuthenticate[this]();
  ContentDispositionHeader? get contentDisposition =>
      Headers.contentDisposition[this]();
  AcceptHeader? get accept => Headers.accept[this]();
  AcceptRangesHeader? get acceptRanges => Headers.acceptRanges[this]();
  TransferEncodingHeader? get transferEncoding =>
      Headers.transferEncoding[this]();
  CookieHeader? get cookie => Headers.cookie[this]();
  SetCookieHeader? get setCookie => Headers.setCookie[this]();
  StrictTransportSecurityHeader? get strictTransportSecurity =>
      Headers.strictTransportSecurity[this]();
  ContentSecurityPolicyHeader? get contentSecurityPolicy =>
      Headers.contentSecurityPolicy[this]();
  ReferrerPolicyHeader? get referrerPolicy => Headers.referrerPolicy[this]();
  PermissionsPolicyHeader? get permissionsPolicy =>
      Headers.permissionsPolicy[this]();
  bool? get accessControlAllowCredentials =>
      Headers.accessControlAllowCredentials[this]();
  AccessControlAllowMethodsHeader? get accessControlAllowMethods =>
      Headers.accessControlAllowMethods[this]();
  AccessControlAllowHeadersHeader? get accessControlAllowHeaders =>
      Headers.accessControlAllowHeaders[this]();
  ClearSiteDataHeader? get clearSiteData => Headers.clearSiteData[this]();
  SecFetchDestHeader? get secFetchDest => Headers.secFetchDest[this]();
  SecFetchModeHeader? get secFetchMode => Headers.secFetchMode[this]();
  SecFetchSiteHeader? get secFetchSite => Headers.secFetchSite[this]();
  CrossOriginResourcePolicyHeader? get crossOriginResourcePolicy =>
      Headers.crossOriginResourcePolicy[this]();
  CrossOriginEmbedderPolicyHeader? get crossOriginEmbedderPolicy =>
      Headers.crossOriginEmbedderPolicy[this]();
  CrossOriginOpenerPolicyHeader? get crossOriginOpenerPolicy =>
      Headers.crossOriginOpenerPolicy[this]();
  ForwardedHeader? get forwarded => Headers.forwarded[this]();
  XForwardedForHeader? get xForwardedFor => Headers.xForwardedFor[this]();
}

extension MutableHeadersEx on MutableHeaders {
  set date(final DateTime? value) => Headers.date[this].set(value);
  set expires(final DateTime? value) => Headers.expires[this].set(value);
  set lastModified(final DateTime? value) =>
      Headers.lastModified[this].set(value);
  set ifModifiedSince(final DateTime? value) =>
      Headers.ifModifiedSince[this].set(value);
  set ifUnmodifiedSince(final DateTime? value) =>
      Headers.ifUnmodifiedSince[this].set(value);
  set origin(final Uri? value) => Headers.origin[this].set(value);
  set server(final String? value) => Headers.server[this].set(value);
  set via(final List<String>? value) => Headers.via[this].set(value);
  set from(final FromHeader? value) => Headers.from[this].set(value);
  set host(final HostHeader? value) => Headers.host[this].set(value);
  set acceptEncoding(final AcceptEncodingHeader? value) =>
      Headers.acceptEncoding[this].set(value);
  set acceptLanguage(final AcceptLanguageHeader? value) =>
      Headers.acceptLanguage[this].set(value);
  set accessControlRequestHeaders(final List<String>? value) =>
      Headers.accessControlRequestHeaders[this].set(value);
  set accessControlRequestMethod(final RequestMethod? value) =>
      Headers.accessControlRequestMethod[this].set(value);
  set age(final int? value) => Headers.age[this].set(value);
  set authorization(final AuthorizationHeader? value) =>
      Headers.authorization[this].set(value);
  set connection(final ConnectionHeader? value) =>
      Headers.connection[this].set(value);
  set contentLength(final int? value) => Headers.contentLength[this].set(value);
  set expect(final ExpectHeader? value) => Headers.expect[this].set(value);
  set ifMatch(final IfMatchHeader? value) => Headers.ifMatch[this].set(value);
  set ifNoneMatch(final IfNoneMatchHeader? value) =>
      Headers.ifNoneMatch[this].set(value);
  set ifRange(final IfRangeHeader? value) => Headers.ifRange[this].set(value);
  set maxForwards(final int? value) => Headers.maxForwards[this].set(value);
  set proxyAuthorization(final AuthorizationHeader? value) =>
      Headers.proxyAuthorization[this].set(value);
  set range(final RangeHeader? value) => Headers.range[this].set(value);
  set referer(final Uri? value) => Headers.referer[this].set(value);
  set userAgent(final String? value) => Headers.userAgent[this].set(value);
  set te(final TEHeader? value) => Headers.te[this].set(value);
  set upgrade(final UpgradeHeader? value) => Headers.upgrade[this].set(value);
  set location(final Uri? value) => Headers.location[this].set(value);
  set xPoweredBy(final String? value) => Headers.xPoweredBy[this].set(value);
  set accessControlAllowOrigin(final AccessControlAllowOriginHeader? value) =>
      Headers.accessControlAllowOrigin[this].set(value);
  set accessControlExposeHeaders(
          final AccessControlExposeHeadersHeader? value) =>
      Headers.accessControlExposeHeaders[this].set(value);
  set accessControlMaxAge(final int? value) =>
      Headers.accessControlMaxAge[this].set(value);
  set allow(final List<RequestMethod>? value) => Headers.allow[this].set(value);
  set cacheControl(final CacheControlHeader? value) =>
      Headers.cacheControl[this].set(value);
  set contentEncoding(final ContentEncodingHeader? value) =>
      Headers.contentEncoding[this].set(value);
  set contentLanguage(final ContentLanguageHeader? value) =>
      Headers.contentLanguage[this].set(value);
  set contentLocation(final Uri? value) =>
      Headers.contentLocation[this].set(value);
  set contentRange(final ContentRangeHeader? value) =>
      Headers.contentRange[this].set(value);
  set etag(final ETagHeader? value) => Headers.etag[this].set(value);
  set proxyAuthenticate(final AuthenticationHeader? value) =>
      Headers.proxyAuthenticate[this].set(value);
  set retryAfter(final RetryAfterHeader? value) =>
      Headers.retryAfter[this].set(value);
  set trailer(final List<String>? value) => Headers.trailer[this].set(value);
  set vary(final VaryHeader? value) => Headers.vary[this].set(value);
  set wwwAuthenticate(final AuthenticationHeader? value) =>
      Headers.wwwAuthenticate[this].set(value);
  set contentDisposition(final ContentDispositionHeader? value) =>
      Headers.contentDisposition[this].set(value);
  set accept(final AcceptHeader? value) => Headers.accept[this].set(value);
  set acceptRanges(final AcceptRangesHeader? value) =>
      Headers.acceptRanges[this].set(value);
  set transferEncoding(final TransferEncodingHeader? value) =>
      Headers.transferEncoding[this].set(value);
  set cookie(final CookieHeader? value) => Headers.cookie[this].set(value);
  set setCookie(final SetCookieHeader? value) =>
      Headers.setCookie[this].set(value);
  set strictTransportSecurity(final StrictTransportSecurityHeader? value) =>
      Headers.strictTransportSecurity[this].set(value);
  set contentSecurityPolicy(final ContentSecurityPolicyHeader? value) =>
      Headers.contentSecurityPolicy[this].set(value);
  set referrerPolicy(final ReferrerPolicyHeader? value) =>
      Headers.referrerPolicy[this].set(value);
  set permissionsPolicy(final PermissionsPolicyHeader? value) =>
      Headers.permissionsPolicy[this].set(value);
  set accessControlAllowCredentials(final bool? value) =>
      Headers.accessControlAllowCredentials[this].set(value);
  set accessControlAllowMethods(final AccessControlAllowMethodsHeader? value) =>
      Headers.accessControlAllowMethods[this].set(value);
  set accessControlAllowHeaders(final AccessControlAllowHeadersHeader? value) =>
      Headers.accessControlAllowHeaders[this].set(value);
  set clearSiteData(final ClearSiteDataHeader? value) =>
      Headers.clearSiteData[this].set(value);
  set secFetchDest(final SecFetchDestHeader? value) =>
      Headers.secFetchDest[this].set(value);
  set secFetchMode(final SecFetchModeHeader? value) =>
      Headers.secFetchMode[this].set(value);
  set secFetchSite(final SecFetchSiteHeader? value) =>
      Headers.secFetchSite[this].set(value);
  set crossOriginResourcePolicy(final CrossOriginResourcePolicyHeader? value) =>
      Headers.crossOriginResourcePolicy[this].set(value);
  set crossOriginEmbedderPolicy(final CrossOriginEmbedderPolicyHeader? value) =>
      Headers.crossOriginEmbedderPolicy[this].set(value);
  set crossOriginOpenerPolicy(final CrossOriginOpenerPolicyHeader? value) =>
      Headers.crossOriginOpenerPolicy[this].set(value);
  set forwarded(final ForwardedHeader? value) =>
      Headers.forwarded[this].set(value);
  set xForwardedFor(final XForwardedForHeader? value) =>
      Headers.xForwardedFor[this].set(value);

  // We have to repeat these read props, since dart cannot have getter and setter defined on two different
  // classes as extensions
  DateTime? get date => Headers.date[this]();
  DateTime? get expires => Headers.expires[this]();
  DateTime? get lastModified => Headers.lastModified[this]();
  DateTime? get ifModifiedSince => Headers.ifModifiedSince[this]();
  DateTime? get ifUnmodifiedSince => Headers.ifUnmodifiedSince[this]();
  Uri? get origin => Headers.origin[this]();
  String? get server => Headers.server[this]();
  List<String>? get via => Headers.via[this]();
  FromHeader? get from => Headers.from[this]();
  HostHeader? get host => Headers.host[this]();
  AcceptEncodingHeader? get acceptEncoding => Headers.acceptEncoding[this]();
  AcceptLanguageHeader? get acceptLanguage => Headers.acceptLanguage[this]();
  List<String>? get accessControlRequestHeaders =>
      Headers.accessControlRequestHeaders[this]();
  RequestMethod? get accessControlRequestMethod =>
      Headers.accessControlRequestMethod[this]();
  int? get age => Headers.age[this]();
  AuthorizationHeader? get authorization => Headers.authorization[this]();
  ConnectionHeader? get connection => Headers.connection[this]();
  int? get contentLength => Headers.contentLength[this]();
  ExpectHeader? get expect => Headers.expect[this]();
  IfMatchHeader? get ifMatch => Headers.ifMatch[this]();
  IfNoneMatchHeader? get ifNoneMatch => Headers.ifNoneMatch[this]();
  IfRangeHeader? get ifRange => Headers.ifRange[this]();
  int? get maxForwards => Headers.maxForwards[this]();
  AuthorizationHeader? get proxyAuthorization =>
      Headers.proxyAuthorization[this]();
  RangeHeader? get range => Headers.range[this]();
  Uri? get referer => Headers.referer[this]();
  String? get userAgent => Headers.userAgent[this]();
  TEHeader? get te => Headers.te[this]();
  UpgradeHeader? get upgrade => Headers.upgrade[this]();
  Uri? get location => Headers.location[this]();
  String? get xPoweredBy => Headers.xPoweredBy[this]();
  AccessControlAllowOriginHeader? get accessControlAllowOrigin =>
      Headers.accessControlAllowOrigin[this]();
  AccessControlExposeHeadersHeader? get accessControlExposeHeaders =>
      Headers.accessControlExposeHeaders[this]();
  int? get accessControlMaxAge => Headers.accessControlMaxAge[this]();
  List<RequestMethod>? get allow => Headers.allow[this]();
  CacheControlHeader? get cacheControl => Headers.cacheControl[this]();
  ContentEncodingHeader? get contentEncoding => Headers.contentEncoding[this]();
  ContentLanguageHeader? get contentLanguage => Headers.contentLanguage[this]();
  Uri? get contentLocation => Headers.contentLocation[this]();
  ContentRangeHeader? get contentRange => Headers.contentRange[this]();
  ETagHeader? get etag => Headers.etag[this]();
  AuthenticationHeader? get proxyAuthenticate =>
      Headers.proxyAuthenticate[this]();
  RetryAfterHeader? get retryAfter => Headers.retryAfter[this]();
  List<String>? get trailer => Headers.trailer[this]();
  VaryHeader? get vary => Headers.vary[this]();
  AuthenticationHeader? get wwwAuthenticate => Headers.wwwAuthenticate[this]();
  ContentDispositionHeader? get contentDisposition =>
      Headers.contentDisposition[this]();
  AcceptHeader? get accept => Headers.accept[this]();
  AcceptRangesHeader? get acceptRanges => Headers.acceptRanges[this]();
  TransferEncodingHeader? get transferEncoding =>
      Headers.transferEncoding[this]();
  CookieHeader? get cookie => Headers.cookie[this]();
  SetCookieHeader? get setCookie => Headers.setCookie[this]();
  StrictTransportSecurityHeader? get strictTransportSecurity =>
      Headers.strictTransportSecurity[this]();
  ContentSecurityPolicyHeader? get contentSecurityPolicy =>
      Headers.contentSecurityPolicy[this]();
  ReferrerPolicyHeader? get referrerPolicy => Headers.referrerPolicy[this]();
  PermissionsPolicyHeader? get permissionsPolicy =>
      Headers.permissionsPolicy[this]();
  bool? get accessControlAllowCredentials =>
      Headers.accessControlAllowCredentials[this]();
  AccessControlAllowMethodsHeader? get accessControlAllowMethods =>
      Headers.accessControlAllowMethods[this]();
  AccessControlAllowHeadersHeader? get accessControlAllowHeaders =>
      Headers.accessControlAllowHeaders[this]();
  ClearSiteDataHeader? get clearSiteData => Headers.clearSiteData[this]();
  SecFetchDestHeader? get secFetchDest => Headers.secFetchDest[this]();
  SecFetchModeHeader? get secFetchMode => Headers.secFetchMode[this]();
  SecFetchSiteHeader? get secFetchSite => Headers.secFetchSite[this]();
  CrossOriginResourcePolicyHeader? get crossOriginResourcePolicy =>
      Headers.crossOriginResourcePolicy[this]();
  CrossOriginEmbedderPolicyHeader? get crossOriginEmbedderPolicy =>
      Headers.crossOriginEmbedderPolicy[this]();
  CrossOriginOpenerPolicyHeader? get crossOriginOpenerPolicy =>
      Headers.crossOriginOpenerPolicy[this]();
  ForwardedHeader? get forwarded => Headers.forwarded[this]();
  XForwardedForHeader? get xForwardedFor => Headers.xForwardedFor[this]();
}
