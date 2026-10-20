import 'dart:collection';

import '../body/body.dart';
import '../router/method.dart';
import 'headers.dart';
import 'typed/typed_headers.dart';

extension HeadersEx on HeaderValues {
  DateTime? get date => this(Headers.date);
  DateTime? get expires => this(Headers.expires);
  DateTime? get lastModified => this(Headers.lastModified);
  DateTime? get ifModifiedSince => this(Headers.ifModifiedSince);
  DateTime? get ifUnmodifiedSince => this(Headers.ifUnmodifiedSince);
  Uri? get origin => this(Headers.origin);
  String? get server => this(Headers.server);
  List<String>? get via => this(Headers.via);
  FromHeader? get from => this(Headers.from);
  HostHeader? get host => this(Headers.host);
  AcceptEncodingHeader? get acceptEncoding => this(Headers.acceptEncoding);
  AcceptLanguageHeader? get acceptLanguage => this(Headers.acceptLanguage);
  List<String>? get accessControlRequestHeaders =>
      this(Headers.accessControlRequestHeaders);
  Method? get accessControlRequestMethod =>
      this(Headers.accessControlRequestMethod);
  int? get age => this(Headers.age);
  AuthorizationHeader? get authorization => this(Headers.authorization);
  ConnectionHeader? get connection => this(Headers.connection);
  int? get contentLength => this(Headers.contentLength);

  /// The parsed Content-Type header.
  ///
  /// Set Content-Type through the body, such as with the `mimeType` argument
  /// of [Body.fromString]. On a request, read [Body.bodyType] instead. It
  /// changes with `copyWith(body: ...)`, and this header does not.
  ContentTypeHeader? get contentType => this(Headers.contentType);

  ExpectHeader? get expect => this(Headers.expect);
  IfMatchHeader? get ifMatch => this(Headers.ifMatch);
  IfNoneMatchHeader? get ifNoneMatch => this(Headers.ifNoneMatch);
  IfRangeHeader? get ifRange => this(Headers.ifRange);
  int? get maxForwards => this(Headers.maxForwards);
  AuthorizationHeader? get proxyAuthorization =>
      this(Headers.proxyAuthorization);
  RangeHeader? get range => this(Headers.range);
  Uri? get referer => this(Headers.referer);
  String? get userAgent => this(Headers.userAgent);
  TEHeader? get te => this(Headers.te);
  UpgradeHeader? get upgrade => this(Headers.upgrade);
  Uri? get location => this(Headers.location);
  String? get xPoweredBy => this(Headers.xPoweredBy);
  AccessControlAllowOriginHeader? get accessControlAllowOrigin =>
      this(Headers.accessControlAllowOrigin);
  AccessControlExposeHeadersHeader? get accessControlExposeHeaders =>
      this(Headers.accessControlExposeHeaders);
  int? get accessControlMaxAge => this(Headers.accessControlMaxAge);
  Set<Method>? get allow => this(Headers.allow);
  CacheControlHeader? get cacheControl => this(Headers.cacheControl);
  ContentEncodingHeader? get contentEncoding => this(Headers.contentEncoding);
  ContentLanguageHeader? get contentLanguage => this(Headers.contentLanguage);
  Uri? get contentLocation => this(Headers.contentLocation);
  ContentRangeHeader? get contentRange => this(Headers.contentRange);
  ETagHeader? get etag => this(Headers.etag);
  AuthenticationHeader? get proxyAuthenticate =>
      this(Headers.proxyAuthenticate);
  RetryAfterHeader? get retryAfter => this(Headers.retryAfter);
  List<String>? get trailer => this(Headers.trailer);
  VaryHeader? get vary => this(Headers.vary);
  AuthenticationHeader? get wwwAuthenticate => this(Headers.wwwAuthenticate);
  ContentDispositionHeader? get contentDisposition =>
      this(Headers.contentDisposition);
  AcceptHeader? get accept => this(Headers.accept);
  AcceptRangesHeader? get acceptRanges => this(Headers.acceptRanges);
  TransferEncodingHeader? get transferEncoding =>
      this(Headers.transferEncoding);
  CookieHeader? get cookie => this(Headers.cookie);
  SetCookieHeader? get setCookie => this(Headers.setCookie);
  StrictTransportSecurityHeader? get strictTransportSecurity =>
      this(Headers.strictTransportSecurity);
  ContentSecurityPolicyHeader? get contentSecurityPolicy =>
      this(Headers.contentSecurityPolicy);
  ReferrerPolicyHeader? get referrerPolicy => this(Headers.referrerPolicy);
  PermissionsPolicyHeader? get permissionsPolicy =>
      this(Headers.permissionsPolicy);
  bool? get accessControlAllowCredentials =>
      this(Headers.accessControlAllowCredentials);
  AccessControlAllowMethodsHeader? get accessControlAllowMethods =>
      this(Headers.accessControlAllowMethods);
  AccessControlAllowHeadersHeader? get accessControlAllowHeaders =>
      this(Headers.accessControlAllowHeaders);
  ClearSiteDataHeader? get clearSiteData => this(Headers.clearSiteData);
  SecFetchDestHeader? get secFetchDest => this(Headers.secFetchDest);
  SecFetchModeHeader? get secFetchMode => this(Headers.secFetchMode);
  SecFetchSiteHeader? get secFetchSite => this(Headers.secFetchSite);
  CrossOriginResourcePolicyHeader? get crossOriginResourcePolicy =>
      this(Headers.crossOriginResourcePolicy);
  CrossOriginEmbedderPolicyHeader? get crossOriginEmbedderPolicy =>
      this(Headers.crossOriginEmbedderPolicy);
  CrossOriginOpenerPolicyHeader? get crossOriginOpenerPolicy =>
      this(Headers.crossOriginOpenerPolicy);
  ForwardedHeader? get forwarded => this(Headers.forwarded);
  XForwardedForHeader? get xForwardedFor => this(Headers.xForwardedFor);
}

extension MutableHeadersEx on MutableHeaders {
  set date(DateTime? value) => assign(Headers.date, value);
  set expires(DateTime? value) => assign(Headers.expires, value);
  set lastModified(DateTime? value) => assign(Headers.lastModified, value);
  set ifModifiedSince(DateTime? value) =>
      assign(Headers.ifModifiedSince, value);
  set ifUnmodifiedSince(DateTime? value) =>
      assign(Headers.ifUnmodifiedSince, value);
  set origin(Uri? value) => assign(Headers.origin, value);
  set server(String? value) => assign(Headers.server, value);
  set via(List<String>? value) => assign(Headers.via, value);
  set from(FromHeader? value) => assign(Headers.from, value);
  set host(HostHeader? value) => assign(Headers.host, value);
  set acceptEncoding(AcceptEncodingHeader? value) =>
      assign(Headers.acceptEncoding, value);
  set acceptLanguage(AcceptLanguageHeader? value) =>
      assign(Headers.acceptLanguage, value);
  set accessControlRequestHeaders(List<String>? value) =>
      assign(Headers.accessControlRequestHeaders, value);
  set accessControlRequestMethod(Method? value) =>
      assign(Headers.accessControlRequestMethod, value);
  set age(int? value) => assign(Headers.age, value);
  set authorization(AuthorizationHeader? value) =>
      assign(Headers.authorization, value);
  set connection(ConnectionHeader? value) => assign(Headers.connection, value);
  set contentLength(int? value) => assign(Headers.contentLength, value);
  set expect(ExpectHeader? value) => assign(Headers.expect, value);
  set ifMatch(IfMatchHeader? value) => assign(Headers.ifMatch, value);
  set ifNoneMatch(IfNoneMatchHeader? value) =>
      assign(Headers.ifNoneMatch, value);
  set ifRange(IfRangeHeader? value) => assign(Headers.ifRange, value);
  set maxForwards(int? value) => assign(Headers.maxForwards, value);
  set proxyAuthorization(AuthorizationHeader? value) =>
      assign(Headers.proxyAuthorization, value);
  set range(RangeHeader? value) => assign(Headers.range, value);
  set referer(Uri? value) => assign(Headers.referer, value);
  set userAgent(String? value) => assign(Headers.userAgent, value);
  set te(TEHeader? value) => assign(Headers.te, value);
  set upgrade(UpgradeHeader? value) => assign(Headers.upgrade, value);
  set location(Uri? value) => assign(Headers.location, value);
  set xPoweredBy(String? value) => assign(Headers.xPoweredBy, value);
  set accessControlAllowOrigin(AccessControlAllowOriginHeader? value) =>
      assign(Headers.accessControlAllowOrigin, value);
  set accessControlExposeHeaders(AccessControlExposeHeadersHeader? value) =>
      assign(Headers.accessControlExposeHeaders, value);
  set accessControlMaxAge(int? value) =>
      assign(Headers.accessControlMaxAge, value);
  set allow(Set<Method>? value) => assign(
    Headers.allow,
    value != null ? SplayTreeSet.of(value, Enum.compareByIndex) : null,
  );
  set cacheControl(CacheControlHeader? value) =>
      assign(Headers.cacheControl, value);
  set contentEncoding(ContentEncodingHeader? value) =>
      assign(Headers.contentEncoding, value);
  set contentLanguage(ContentLanguageHeader? value) =>
      assign(Headers.contentLanguage, value);
  set contentLocation(Uri? value) => assign(Headers.contentLocation, value);
  set contentRange(ContentRangeHeader? value) =>
      assign(Headers.contentRange, value);
  set etag(ETagHeader? value) => assign(Headers.etag, value);
  set proxyAuthenticate(AuthenticationHeader? value) =>
      assign(Headers.proxyAuthenticate, value);
  set retryAfter(RetryAfterHeader? value) => assign(Headers.retryAfter, value);
  set trailer(List<String>? value) => assign(Headers.trailer, value);
  set vary(VaryHeader? value) => assign(Headers.vary, value);
  set wwwAuthenticate(AuthenticationHeader? value) =>
      assign(Headers.wwwAuthenticate, value);
  set contentDisposition(ContentDispositionHeader? value) =>
      assign(Headers.contentDisposition, value);
  set accept(AcceptHeader? value) => assign(Headers.accept, value);
  set acceptRanges(AcceptRangesHeader? value) =>
      assign(Headers.acceptRanges, value);
  set transferEncoding(TransferEncodingHeader? value) =>
      assign(Headers.transferEncoding, value);
  set cookie(CookieHeader? value) => assign(Headers.cookie, value);
  set setCookie(SetCookieHeader? value) => assign(Headers.setCookie, value);
  set strictTransportSecurity(StrictTransportSecurityHeader? value) =>
      assign(Headers.strictTransportSecurity, value);
  set contentSecurityPolicy(ContentSecurityPolicyHeader? value) =>
      assign(Headers.contentSecurityPolicy, value);
  set referrerPolicy(ReferrerPolicyHeader? value) =>
      assign(Headers.referrerPolicy, value);
  set permissionsPolicy(PermissionsPolicyHeader? value) =>
      assign(Headers.permissionsPolicy, value);
  set accessControlAllowCredentials(bool? value) =>
      assign(Headers.accessControlAllowCredentials, value);
  set accessControlAllowMethods(AccessControlAllowMethodsHeader? value) =>
      assign(Headers.accessControlAllowMethods, value);
  set accessControlAllowHeaders(AccessControlAllowHeadersHeader? value) =>
      assign(Headers.accessControlAllowHeaders, value);
  set clearSiteData(ClearSiteDataHeader? value) =>
      assign(Headers.clearSiteData, value);
  set secFetchDest(SecFetchDestHeader? value) =>
      assign(Headers.secFetchDest, value);
  set secFetchMode(SecFetchModeHeader? value) =>
      assign(Headers.secFetchMode, value);
  set secFetchSite(SecFetchSiteHeader? value) =>
      assign(Headers.secFetchSite, value);
  set crossOriginResourcePolicy(CrossOriginResourcePolicyHeader? value) =>
      assign(Headers.crossOriginResourcePolicy, value);
  set crossOriginEmbedderPolicy(CrossOriginEmbedderPolicyHeader? value) =>
      assign(Headers.crossOriginEmbedderPolicy, value);
  set crossOriginOpenerPolicy(CrossOriginOpenerPolicyHeader? value) =>
      assign(Headers.crossOriginOpenerPolicy, value);
  set forwarded(ForwardedHeader? value) => assign(Headers.forwarded, value);
  set xForwardedFor(XForwardedForHeader? value) =>
      assign(Headers.xForwardedFor, value);

  // We have to repeat these read props, since dart cannot have getter and setter defined on two different
  // classes as extensions
  DateTime? get date => this(Headers.date);
  DateTime? get expires => this(Headers.expires);
  DateTime? get lastModified => this(Headers.lastModified);
  DateTime? get ifModifiedSince => this(Headers.ifModifiedSince);
  DateTime? get ifUnmodifiedSince => this(Headers.ifUnmodifiedSince);
  Uri? get origin => this(Headers.origin);
  String? get server => this(Headers.server);
  List<String>? get via => this(Headers.via);
  FromHeader? get from => this(Headers.from);
  HostHeader? get host => this(Headers.host);
  AcceptEncodingHeader? get acceptEncoding => this(Headers.acceptEncoding);
  AcceptLanguageHeader? get acceptLanguage => this(Headers.acceptLanguage);
  List<String>? get accessControlRequestHeaders =>
      this(Headers.accessControlRequestHeaders);
  Method? get accessControlRequestMethod =>
      this(Headers.accessControlRequestMethod);
  int? get age => this(Headers.age);
  AuthorizationHeader? get authorization => this(Headers.authorization);
  ConnectionHeader? get connection => this(Headers.connection);
  int? get contentLength => this(Headers.contentLength);

  /// The parsed Content-Type header.
  ///
  /// Read-only. Set Content-Type through the body, such as with the
  /// `mimeType` argument of [Body.fromString]. On a request, read
  /// [Body.bodyType] instead. It changes with `copyWith(body: ...)`, and this
  /// header does not.
  ContentTypeHeader? get contentType => this(Headers.contentType);

  ExpectHeader? get expect => this(Headers.expect);
  IfMatchHeader? get ifMatch => this(Headers.ifMatch);
  IfNoneMatchHeader? get ifNoneMatch => this(Headers.ifNoneMatch);
  IfRangeHeader? get ifRange => this(Headers.ifRange);
  int? get maxForwards => this(Headers.maxForwards);
  AuthorizationHeader? get proxyAuthorization =>
      this(Headers.proxyAuthorization);
  RangeHeader? get range => this(Headers.range);
  Uri? get referer => this(Headers.referer);
  String? get userAgent => this(Headers.userAgent);
  TEHeader? get te => this(Headers.te);
  UpgradeHeader? get upgrade => this(Headers.upgrade);
  Uri? get location => this(Headers.location);
  String? get xPoweredBy => this(Headers.xPoweredBy);
  AccessControlAllowOriginHeader? get accessControlAllowOrigin =>
      this(Headers.accessControlAllowOrigin);
  AccessControlExposeHeadersHeader? get accessControlExposeHeaders =>
      this(Headers.accessControlExposeHeaders);
  int? get accessControlMaxAge => this(Headers.accessControlMaxAge);
  Set<Method>? get allow => this(Headers.allow);
  CacheControlHeader? get cacheControl => this(Headers.cacheControl);
  ContentEncodingHeader? get contentEncoding => this(Headers.contentEncoding);
  ContentLanguageHeader? get contentLanguage => this(Headers.contentLanguage);
  Uri? get contentLocation => this(Headers.contentLocation);
  ContentRangeHeader? get contentRange => this(Headers.contentRange);
  ETagHeader? get etag => this(Headers.etag);
  AuthenticationHeader? get proxyAuthenticate =>
      this(Headers.proxyAuthenticate);
  RetryAfterHeader? get retryAfter => this(Headers.retryAfter);
  List<String>? get trailer => this(Headers.trailer);
  VaryHeader? get vary => this(Headers.vary);
  AuthenticationHeader? get wwwAuthenticate => this(Headers.wwwAuthenticate);
  ContentDispositionHeader? get contentDisposition =>
      this(Headers.contentDisposition);
  AcceptHeader? get accept => this(Headers.accept);
  AcceptRangesHeader? get acceptRanges => this(Headers.acceptRanges);
  TransferEncodingHeader? get transferEncoding =>
      this(Headers.transferEncoding);
  CookieHeader? get cookie => this(Headers.cookie);
  SetCookieHeader? get setCookie => this(Headers.setCookie);
  StrictTransportSecurityHeader? get strictTransportSecurity =>
      this(Headers.strictTransportSecurity);
  ContentSecurityPolicyHeader? get contentSecurityPolicy =>
      this(Headers.contentSecurityPolicy);
  ReferrerPolicyHeader? get referrerPolicy => this(Headers.referrerPolicy);
  PermissionsPolicyHeader? get permissionsPolicy =>
      this(Headers.permissionsPolicy);
  bool? get accessControlAllowCredentials =>
      this(Headers.accessControlAllowCredentials);
  AccessControlAllowMethodsHeader? get accessControlAllowMethods =>
      this(Headers.accessControlAllowMethods);
  AccessControlAllowHeadersHeader? get accessControlAllowHeaders =>
      this(Headers.accessControlAllowHeaders);
  ClearSiteDataHeader? get clearSiteData => this(Headers.clearSiteData);
  SecFetchDestHeader? get secFetchDest => this(Headers.secFetchDest);
  SecFetchModeHeader? get secFetchMode => this(Headers.secFetchMode);
  SecFetchSiteHeader? get secFetchSite => this(Headers.secFetchSite);
  CrossOriginResourcePolicyHeader? get crossOriginResourcePolicy =>
      this(Headers.crossOriginResourcePolicy);
  CrossOriginEmbedderPolicyHeader? get crossOriginEmbedderPolicy =>
      this(Headers.crossOriginEmbedderPolicy);
  CrossOriginOpenerPolicyHeader? get crossOriginOpenerPolicy =>
      this(Headers.crossOriginOpenerPolicy);
  ForwardedHeader? get forwarded => this(Headers.forwarded);
  XForwardedForHeader? get xForwardedFor => this(Headers.xForwardedFor);
}
