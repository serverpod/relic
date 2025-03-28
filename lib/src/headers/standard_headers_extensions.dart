import 'package:relic/src/method/request_method.dart';
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
  Uri? get host => Headers.host[this]();
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
}

extension MutableHeadersEx on MutableHeaders {
  set date(DateTime? value) => Headers.date[this].set(value);
  set expires(DateTime? value) => Headers.expires[this].set(value);
  set lastModified(DateTime? value) => Headers.lastModified[this].set(value);
  set ifModifiedSince(DateTime? value) =>
      Headers.ifModifiedSince[this].set(value);
  set ifUnmodifiedSince(DateTime? value) =>
      Headers.ifUnmodifiedSince[this].set(value);
  set origin(Uri? value) => Headers.origin[this].set(value);
  set server(String? value) => Headers.server[this].set(value);
  set via(List<String>? value) => Headers.via[this].set(value);
  set from(FromHeader? value) => Headers.from[this].set(value);
  set host(Uri? value) => Headers.host[this].set(value);
  set acceptEncoding(AcceptEncodingHeader? value) =>
      Headers.acceptEncoding[this].set(value);
  set acceptLanguage(AcceptLanguageHeader? value) =>
      Headers.acceptLanguage[this].set(value);
  set accessControlRequestHeaders(List<String>? value) =>
      Headers.accessControlRequestHeaders[this].set(value);
  set accessControlRequestMethod(RequestMethod? value) =>
      Headers.accessControlRequestMethod[this].set(value);
  set age(int? value) => Headers.age[this].set(value);
  set authorization(AuthorizationHeader? value) =>
      Headers.authorization[this].set(value);
  set connection(ConnectionHeader? value) =>
      Headers.connection[this].set(value);
  set contentLength(int? value) => Headers.contentLength[this].set(value);
  set expect(ExpectHeader? value) => Headers.expect[this].set(value);
  set ifMatch(IfMatchHeader? value) => Headers.ifMatch[this].set(value);
  set ifNoneMatch(IfNoneMatchHeader? value) =>
      Headers.ifNoneMatch[this].set(value);
  set ifRange(IfRangeHeader? value) => Headers.ifRange[this].set(value);
  set maxForwards(int? value) => Headers.maxForwards[this].set(value);
  set proxyAuthorization(AuthorizationHeader? value) =>
      Headers.proxyAuthorization[this].set(value);
  set range(RangeHeader? value) => Headers.range[this].set(value);
  set referer(Uri? value) => Headers.referer[this].set(value);
  set userAgent(String? value) => Headers.userAgent[this].set(value);
  set te(TEHeader? value) => Headers.te[this].set(value);
  set upgrade(UpgradeHeader? value) => Headers.upgrade[this].set(value);
  set location(Uri? value) => Headers.location[this].set(value);
  set xPoweredBy(String? value) => Headers.xPoweredBy[this].set(value);
  set accessControlAllowOrigin(AccessControlAllowOriginHeader? value) =>
      Headers.accessControlAllowOrigin[this].set(value);
  set accessControlExposeHeaders(AccessControlExposeHeadersHeader? value) =>
      Headers.accessControlExposeHeaders[this].set(value);
  set accessControlMaxAge(int? value) =>
      Headers.accessControlMaxAge[this].set(value);
  set allow(List<RequestMethod>? value) => Headers.allow[this].set(value);
  set cacheControl(CacheControlHeader? value) =>
      Headers.cacheControl[this].set(value);
  set contentEncoding(ContentEncodingHeader? value) =>
      Headers.contentEncoding[this].set(value);
  set contentLanguage(ContentLanguageHeader? value) =>
      Headers.contentLanguage[this].set(value);
  set contentLocation(Uri? value) => Headers.contentLocation[this].set(value);
  set contentRange(ContentRangeHeader? value) =>
      Headers.contentRange[this].set(value);
  set etag(ETagHeader? value) => Headers.etag[this].set(value);
  set proxyAuthenticate(AuthenticationHeader? value) =>
      Headers.proxyAuthenticate[this].set(value);
  set retryAfter(RetryAfterHeader? value) =>
      Headers.retryAfter[this].set(value);
  set trailer(List<String>? value) => Headers.trailer[this].set(value);
  set vary(VaryHeader? value) => Headers.vary[this].set(value);
  set wwwAuthenticate(AuthenticationHeader? value) =>
      Headers.wwwAuthenticate[this].set(value);
  set contentDisposition(ContentDispositionHeader? value) =>
      Headers.contentDisposition[this].set(value);
  set accept(AcceptHeader? value) => Headers.accept[this].set(value);
  set acceptRanges(AcceptRangesHeader? value) =>
      Headers.acceptRanges[this].set(value);
  set transferEncoding(TransferEncodingHeader? value) =>
      Headers.transferEncoding[this].set(value);
  set cookie(CookieHeader? value) => Headers.cookie[this].set(value);
  set setCookie(SetCookieHeader? value) => Headers.setCookie[this].set(value);
  set strictTransportSecurity(StrictTransportSecurityHeader? value) =>
      Headers.strictTransportSecurity[this].set(value);
  set contentSecurityPolicy(ContentSecurityPolicyHeader? value) =>
      Headers.contentSecurityPolicy[this].set(value);
  set referrerPolicy(ReferrerPolicyHeader? value) =>
      Headers.referrerPolicy[this].set(value);
  set permissionsPolicy(PermissionsPolicyHeader? value) =>
      Headers.permissionsPolicy[this].set(value);
  set accessControlAllowCredentials(bool? value) =>
      Headers.accessControlAllowCredentials[this].set(value);
  set accessControlAllowMethods(AccessControlAllowMethodsHeader? value) =>
      Headers.accessControlAllowMethods[this].set(value);
  set accessControlAllowHeaders(AccessControlAllowHeadersHeader? value) =>
      Headers.accessControlAllowHeaders[this].set(value);
  set clearSiteData(ClearSiteDataHeader? value) =>
      Headers.clearSiteData[this].set(value);
  set secFetchDest(SecFetchDestHeader? value) =>
      Headers.secFetchDest[this].set(value);
  set secFetchMode(SecFetchModeHeader? value) =>
      Headers.secFetchMode[this].set(value);
  set secFetchSite(SecFetchSiteHeader? value) =>
      Headers.secFetchSite[this].set(value);
  set crossOriginResourcePolicy(CrossOriginResourcePolicyHeader? value) =>
      Headers.crossOriginResourcePolicy[this].set(value);
  set crossOriginEmbedderPolicy(CrossOriginEmbedderPolicyHeader? value) =>
      Headers.crossOriginEmbedderPolicy[this].set(value);
  set crossOriginOpenerPolicy(CrossOriginOpenerPolicyHeader? value) =>
      Headers.crossOriginOpenerPolicy[this].set(value);

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
  Uri? get host => Headers.host[this]();
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
}
